import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_model.dart';

class BookingRepository extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _key = 'bookings_list';

  List<BookingModel> _bookings = [];

  BookingRepository(this._prefs) {
    _loadBookings();
  }

  List<BookingModel> get bookings => List.unmodifiable(_bookings);

  List<BookingModel> get upcomingBookings => _bookings
      .where((b) => b.status == BookingStatus.upcoming)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<BookingModel> get pastBookings => _bookings
      .where((b) =>
          b.status == BookingStatus.completed ||
          b.status == BookingStatus.cancelled)
      .toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  void _loadBookings() {
    final raw = _prefs.getStringList(_key) ?? [];
    _bookings = raw
        .map((e) => BookingModel.fromJson(jsonDecode(e)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveBookings() async {
    final raw = _bookings.map((b) => jsonEncode(b.toJson())).toList();
    await _prefs.setStringList(_key, raw);
  }

  Future<BookingModel> createBooking({
    required String serviceId,
    required String serviceTitle,
    required String petId,
    required String petName,
    required DateTime scheduledAt,
    required int price,
    String? notes,
  }) async {
    final booking = BookingModel(
      id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      petId: petId,
      petName: petName,
      scheduledAt: scheduledAt,
      price: price,
      status: BookingStatus.upcoming,
      notes: notes,
      companionName: _randomCompanionName(),
    );
    _bookings.add(booking);
    await _saveBookings();
    notifyListeners();
    return booking;
  }

  Future<void> cancelBooking(String id) async {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _bookings[idx] = BookingModel(
        id: _bookings[idx].id,
        serviceId: _bookings[idx].serviceId,
        serviceTitle: _bookings[idx].serviceTitle,
        petId: _bookings[idx].petId,
        petName: _bookings[idx].petName,
        scheduledAt: _bookings[idx].scheduledAt,
        price: _bookings[idx].price,
        status: BookingStatus.cancelled,
        notes: _bookings[idx].notes,
        companionName: _bookings[idx].companionName,
      );
      await _saveBookings();
      notifyListeners();
    }
  }

  String _randomCompanionName() {
    final names = ['Priya', 'Rahul', 'Ananya', 'Vivek', 'Meera', 'Arjun'];
    names.shuffle();
    return names.first;
  }
}
