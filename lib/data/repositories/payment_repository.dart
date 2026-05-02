import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

// ─── Wallet Info ──────────────────────────────────────────────────────────────
class WalletInfo {
  final double balance;
  final String currency;

  const WalletInfo({required this.balance, required this.currency});

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: _parseDouble(json['balance']) ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ─── Create Payment Result ────────────────────────────────────────────────────
class CreatePaymentResult {
  final bool isSuccess;
  final bool walletOnly;   // true = wallet fully covered, no Razorpay needed
  final bool isCod;        // true = Cash on Delivery, skip Razorpay entirely
  final String? razorpayKey;
  final String? razorpayOrderId;
  final int? bookingId;
  final double? remainingAmount;
  final double? walletUsed;
  final String? message;
  final String? error;

  const CreatePaymentResult._({
    required this.isSuccess,
    required this.walletOnly,
    required this.isCod,
    this.razorpayKey,
    this.razorpayOrderId,
    this.bookingId,
    this.remainingAmount,
    this.walletUsed,
    this.message,
    this.error,
  });

  factory CreatePaymentResult.success({
    required bool walletOnly,
    bool isCod = false,
    String? razorpayKey,
    String? razorpayOrderId,
    int? bookingId,
    double? remainingAmount,
    double? walletUsed,
    String? message,
  }) =>
      CreatePaymentResult._(
        isSuccess: true,
        walletOnly: walletOnly,
        isCod: isCod,
        razorpayKey: razorpayKey,
        razorpayOrderId: razorpayOrderId,
        bookingId: bookingId,
        remainingAmount: remainingAmount,
        walletUsed: walletUsed,
        message: message,
      );

  factory CreatePaymentResult.error(String msg) => CreatePaymentResult._(
    isSuccess: false,
    walletOnly: false,
    isCod: false,
    error: msg,
  );
}

// ─── Verify Payment Result ────────────────────────────────────────────────────
class VerifyPaymentResult {
  final bool isSuccess;
  final String? message;
  final String? error;

  const VerifyPaymentResult._({
    required this.isSuccess,
    this.message,
    this.error,
  });

  factory VerifyPaymentResult.success(String msg) =>
      VerifyPaymentResult._(isSuccess: true, message: msg);
  factory VerifyPaymentResult.error(String msg) =>
      VerifyPaymentResult._(isSuccess: false, error: msg);
}

// ─── Payment Repository ───────────────────────────────────────────────────────
class PaymentRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  WalletInfo? _wallet;
  bool _isLoadingWallet = false;

  PaymentRepository(this._prefs);

  WalletInfo? get wallet => _wallet;
  bool get isLoadingWallet => _isLoadingWallet;

  String get _token => _prefs.getString(AppConstants.keyAuthToken) ?? '';

  // ─── Fetch Wallet Summary ─────────────────────────────────────────────────
  // GET /wallet-summary
  Future<WalletInfo?> fetchWalletSummary() async {
    if (_token.isEmpty) return null;

    _isLoadingWallet = true;
    notifyListeners();

    final response = await ApiService.get('/wallet-summary', token: _token);

    _isLoadingWallet = false;

    if (response.success && response.data != null) {
      final data = response.data!['data'];
      if (data != null && data['wallet'] != null) {
        _wallet = WalletInfo.fromJson(data['wallet'] as Map<String, dynamic>);
        notifyListeners();
        return _wallet;
      }
    }

    notifyListeners();
    return null;
  }

  // ─── Create Payment ───────────────────────────────────────────────────────
  // POST /bookings/payment
  // payment_method: 'wallet' | 'online' | 'cod'
  //
  // COD is handled client-side only — booking is already created on the server.
  // Provider collects cash on arrival; no Razorpay order is created.
  Future<CreatePaymentResult> createPayment({
    required int bookingId,
    required String paymentMethod, // 'wallet' | 'online' | 'cod'
  }) async {
    // ── COD: skip payment API, resolve immediately ────────────────────────────
    if (paymentMethod == 'cod') {
      return CreatePaymentResult.success(
        walletOnly: false,
        isCod: true,
        bookingId: bookingId,
        message: 'Pay at your doorstep when the provider arrives.',
      );
    }

    if (_token.isEmpty) return CreatePaymentResult.error('Not authenticated');

    final response = await ApiService.post(
      '/bookings/payment',
      {
        'booking_id': bookingId,
        'payment_method': paymentMethod,
      },
      token: _token,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      final walletOnly = data['wallet_only'] == true;

      if (walletOnly) {
        return CreatePaymentResult.success(
          walletOnly: true,
          walletUsed: _parseDouble(data['wallet_used']),
          message: data['message'] as String?,
        );
      } else {
        return CreatePaymentResult.success(
          walletOnly: false,
          razorpayKey: data['key'] as String?,
          razorpayOrderId: data['order_id'] as String?,
          bookingId: _parseInt(data['booking_id']),
          remainingAmount: _parseDouble(data['remaining_amount']),
          walletUsed: _parseDouble(data['wallet_used']),
          message: data['message'] as String?,
        );
      }
    }

    return CreatePaymentResult.error(response.errorMessage);
  }

  // ─── Verify Razorpay Payment ──────────────────────────────────────────────
  // POST /bookings/verify-payment
  Future<VerifyPaymentResult> verifyPayment({
    required int bookingId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    if (_token.isEmpty) return VerifyPaymentResult.error('Not authenticated');

    final response = await ApiService.post(
      '/bookings/verify-payment',
      {
        'booking_id': bookingId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_signature': razorpaySignature,
      },
      token: _token,
    );

    if (response.success) {
      return VerifyPaymentResult.success(
          response.message.isNotEmpty ? response.message : 'Payment successful');
    }

    return VerifyPaymentResult.error(response.errorMessage);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
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