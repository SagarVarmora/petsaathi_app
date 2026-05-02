// ─── Booking Status ───────────────────────────────────────────────────────────
enum BookingStatus { pending, upcoming, running, completed, cancelled }

// ─── Booking Model (matches /customer/bookings list API response) ──────────────
class BookingModel {
  final int id;                // booking_id
  final String serviceName;   // service_name
  final String providerName;  // provider_name
  final String bookingDate;   // already formatted: "01 Dec 2025"
  final double amount;        // payment amount / final_amount
  final double totalAmount;
  final double discountedAmount;
  final String rawStatus;     // lowercase: pending/upcoming/running/completed/cancelled
  final String paymentStatus; // lowercase: pending/completed/refunded
  final String refundStatus;  // "No Refund" | "Pending" | "Initiated" | "Refund Completed"
  final int? otp;

  const BookingModel({
    required this.id,
    required this.serviceName,
    required this.providerName,
    required this.bookingDate,
    required this.amount,
    this.totalAmount = 0,
    this.discountedAmount = 0,
    required this.rawStatus,
    required this.paymentStatus,
    this.refundStatus = 'No Refund',
    this.otp,
  });

  // ── Derived ────────────────────────────────────────────────────────────────
  BookingStatus get status {
    switch (rawStatus.toLowerCase()) {
      case 'upcoming':  return BookingStatus.upcoming;
      case 'running':   return BookingStatus.running;
      case 'completed': return BookingStatus.completed;
      case 'cancelled': return BookingStatus.cancelled;
      default:          return BookingStatus.pending;
    }
  }

  String get statusLabel {
    switch (rawStatus.toLowerCase()) {
      case 'pending':   return 'Pending';
      case 'upcoming':  return 'Upcoming';
      case 'running':   return 'Ongoing';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default:
        return rawStatus.isNotEmpty
            ? rawStatus[0].toUpperCase() + rawStatus.substring(1)
            : 'Pending';
    }
  }

  // Only pending bookings can be cancelled (matches server logic)
  bool get canCancel => status == BookingStatus.pending;

  bool get isActive =>
      status == BookingStatus.pending ||
          status == BookingStatus.upcoming ||
          status == BookingStatus.running;

  // ── JSON ───────────────────────────────────────────────────────────────────
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: _parseInt(json['booking_id'] ?? json['id']) ?? 0,
      serviceName: json['service_name'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? '',
      bookingDate: json['booking_date'] as String? ?? '',
      amount: _parseDouble(json['amount'] ?? json['final_amount']) ?? 0.0,
      totalAmount: _parseDouble(json['total_amount']) ?? 0.0,
      discountedAmount:
      _parseDouble(json['discount_amount'] ?? json['discounted_amount']) ??
          0.0,
      rawStatus: (json['booking_status'] as String? ??
          json['status'] as String? ??
          'pending')
          .toLowerCase(),
      paymentStatus:
      (json['payment_status'] as String? ?? 'pending').toLowerCase(),
      refundStatus: json['refund_status'] as String? ?? 'No Refund',
      otp: _parseInt(json['otp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'booking_id': id,
    'service_name': serviceName,
    'provider_name': providerName,
    'booking_date': bookingDate,
    'amount': amount,
    'total_amount': totalAmount,
    'discount_amount': discountedAmount,
    'booking_status': rawStatus,
    'payment_status': paymentStatus,
    'refund_status': refundStatus,
    'otp': otp,
  };

  // ── Helpers ────────────────────────────────────────────────────────────────
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

// ─── Booking Create Result ─────────────────────────────────────────────────────
// Returned after POST /bookings
class BookingCreateResult {
  final bool isSuccess;
  final int? bookingId;
  final int? otp;
  final double? totalAmount;
  final double? discountedAmount;
  final double? finalAmount;
  final String? error;

  const BookingCreateResult._({
    required this.isSuccess,
    this.bookingId,
    this.otp,
    this.totalAmount,
    this.discountedAmount,
    this.finalAmount,
    this.error,
  });

  factory BookingCreateResult.success({
    required int bookingId,
    int? otp,
    double? totalAmount,
    double? discountedAmount,
    double? finalAmount,
  }) =>
      BookingCreateResult._(
        isSuccess: true,
        bookingId: bookingId,
        otp: otp,
        totalAmount: totalAmount,
        discountedAmount: discountedAmount,
        finalAmount: finalAmount,
      );

  factory BookingCreateResult.error(String msg) =>
      BookingCreateResult._(isSuccess: false, error: msg);
}