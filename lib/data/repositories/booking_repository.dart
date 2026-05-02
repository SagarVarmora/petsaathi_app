import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/booking_model.dart';

class BookingRepository extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _cacheKey = 'bookings_cache_v3';

  List<BookingModel> _bookings = [];
  bool _isLoading = false;
  String? _error;

  BookingRepository(this._prefs) {
    _loadFromCache();
  }

  // ── Public getters ──────────────────────────────────────────────────────────
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Pending / Upcoming / Running
  List<BookingModel> get activeBookings =>
      _bookings.where((b) => b.isActive).toList();

  /// Completed / Cancelled
  List<BookingModel> get pastBookings =>
      _bookings.where((b) => !b.isActive).toList();

  // ── Token helper ────────────────────────────────────────────────────────────
  String get _token => _prefs.getString(AppConstants.keyAuthToken) ?? '';

  // ─── FETCH bookings from API ───────────────────────────────────────────────
  // POST /customer/bookings
  Future<void> fetchBookings() async {
    if (_token.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await ApiService.post(
      '/customer/bookings',
      {},
      token: _token,
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      final rawList = response.data!['data'];
      if (rawList is List) {
        _bookings = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => BookingModel.fromJson(j))
            .toList();
        _saveToCache();
      }
    } else {
      _error = response.errorMessage;
    }

    notifyListeners();
  }

  // ─── CREATE booking via API ────────────────────────────────────────────────
  // POST /bookings
  Future<BookingCreateResult> createBooking({
    required int providerId,
    required int serviceId,
    required int petId,
    required String bookingDate,      // "YYYY-MM-DD"
    required String bookingAddress,
    int? bookingSlotId,
    String? bookingStartTime,
    String? bookingEndTime,
  }) async {
    if (_token.isEmpty) return BookingCreateResult.error('Not authenticated');

    final body = <String, dynamic>{
      'provider_id': providerId,
      'service_id': serviceId,
      'pet_id': petId,
      'booking_date': bookingDate,
      'booking_address': bookingAddress,
      if (bookingSlotId != null) 'booking_slot_id': bookingSlotId,
      if (bookingStartTime != null) 'booking_start_time': bookingStartTime,
      if (bookingEndTime != null) 'booking_end_time': bookingEndTime,
    };

    final response = await ApiService.post('/bookings', body, token: _token);

    if (response.success && response.data?['data'] != null) {
      final data = response.data!['data'] as Map<String, dynamic>;

      final result = BookingCreateResult.success(
        bookingId: _parseInt(data['booking_id']) ?? 0,
        otp: _parseInt(data['otp']),
        totalAmount: _parseDouble(data['total_amount']),
        discountedAmount: _parseDouble(data['discounted_amount']),
        finalAmount: _parseDouble(data['final_amount']),
      );

      // Refresh list in background
      fetchBookings();
      return result;
    }

    return BookingCreateResult.error(response.errorMessage);
  }

  // ─── CANCEL booking ────────────────────────────────────────────────────────
  // POST /booking/cancel
  Future<ApiResponse> cancelBooking(
      int bookingId, {
        required String cancelReason,
        String refundMethod = 'wallet', // 'wallet' | 'account'
      }) async {
    if (_token.isEmpty) {
      return ApiResponse(
          success: false,
          message: 'Not authenticated',
          data: null,
          statusCode: 0);
    }

    final response = await ApiService.post(
      '/booking/cancel',
      {
        'booking_id': bookingId,
        'cancel_reason': cancelReason,
        'refund_method': refundMethod,
      },
      token: _token,
    );

    if (response.success) {
      // Optimistically update local state
      final idx = _bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) {
        final old = _bookings[idx];
        _bookings[idx] = BookingModel(
          id: old.id,
          serviceName: old.serviceName,
          providerName: old.providerName,
          bookingDate: old.bookingDate,
          amount: old.amount,
          totalAmount: old.totalAmount,
          discountedAmount: old.discountedAmount,
          rawStatus: 'cancelled',
          paymentStatus: old.paymentStatus,
          refundStatus: 'Pending',
        );
        _saveToCache();
        notifyListeners();
      }
    }

    return response;
  }

  // ─── INITIATE PAYMENT ──────────────────────────────────────────────────────
  // POST /bookings/initiate-payment
  Future<ApiResponse> initiatePayment(int bookingId) async {
    if (_token.isEmpty) {
      return ApiResponse(
          success: false,
          message: 'Not authenticated',
          data: null,
          statusCode: 0);
    }
    return ApiService.post(
      '/bookings/initiate-payment',
      {'booking_id': bookingId},
      token: _token,
    );
  }

  // ─── Cache helpers ─────────────────────────────────────────────────────────
  void _loadFromCache() {
    try {
      final raw = _prefs.getStringList(_cacheKey) ?? [];
      _bookings = raw
          .map((e) =>
          BookingModel.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      if (_bookings.isNotEmpty) notifyListeners();
    } catch (_) {
      _bookings = [];
    }
  }

  void _saveToCache() {
    try {
      final raw = _bookings.map((b) => jsonEncode(b.toJson())).toList();
      _prefs.setStringList(_cacheKey, raw);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    _bookings = [];
    await _prefs.remove(_cacheKey);
    notifyListeners();
  }

  // ── Parse helpers ──────────────────────────────────────────────────────────
  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}