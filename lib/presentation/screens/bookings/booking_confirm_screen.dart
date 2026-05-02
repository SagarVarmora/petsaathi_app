import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';

class BookingConfirmScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  const BookingConfirmScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    // Data from BookingScreen after successful API call
    final bookingId = bookingData['bookingId'] as int? ?? 0;
    final otp = bookingData['otp'] as int?;
    final serviceName = bookingData['serviceName'] as String? ?? '';
    final serviceEmoji = bookingData['serviceEmoji'] as String? ?? '🐾';
    final petName = bookingData['petName'] as String? ?? '';
    final providerName = bookingData['providerName'] as String? ?? '';
    final bookingDate = bookingData['bookingDate'] as String? ?? ''; // YYYY-MM-DD
    final slotTime = bookingData['slotTime'] as String? ?? '';
    final totalAmount = (bookingData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final discountedAmount =
        (bookingData['discountedAmount'] as num?)?.toDouble() ?? 0.0;
    final finalAmount = (bookingData['finalAmount'] as num?)?.toDouble() ?? 0.0;

    // Format date
    String dateDisplay = bookingDate;
    try {
      if (bookingDate.contains('-')) {
        final parts = bookingDate.split('-');
        final months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        dateDisplay =
        '${parts[2]} ${months[int.parse(parts[1])]} ${parts[0]}';
      }
    } catch (_) {}

    // Format slot time: "10:00:00 - 10:45:00" → "10:00 AM - 10:45 AM"
    String timeDisplay = slotTime;
    try {
      if (slotTime.contains(' - ')) {
        final parts = slotTime.split(' - ');
        timeDisplay = '${_formatTime(parts[0])} - ${_formatTime(parts[1])}';
      } else if (slotTime.isNotEmpty) {
        timeDisplay = _formatTime(slotTime);
      }
    } catch (_) {}

    if (bookingId == 0) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Go Home',
                  onPressed: () => context.go(AppConstants.routeHome)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── Success Icon ────────────────────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded,
                        color: AppTheme.primary, size: 52),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$serviceName has been booked for $petName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 28),

              // ── Booking Details Card ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _DetailRow(
                        icon: Icons.pets_rounded,
                        label: 'Pet',
                        value: petName),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: dateDisplay),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: timeDisplay),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.person_rounded,
                        label: 'Provider',
                        value: providerName),
                    if (discountedAmount > 0) ...[
                      const Divider(height: 24),
                      _DetailRow(
                          icon: Icons.local_offer_rounded,
                          label: 'Discount',
                          value: '- ₹${discountedAmount.toInt()}',
                          valueColor: AppTheme.success),
                    ],
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Amount',
                        value: '₹${finalAmount.toInt()}',
                        valueColor: AppTheme.primary),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Booking ID + OTP ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Booking #$bookingId',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                  if (otp != null) ...[
                    const Text('  •  ',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textHint)),
                    Text(
                      'OTP: $otp',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),

              // OTP note
              if (otp != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.amber.shade700, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Share OTP $otp with the provider to start service',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // ── Actions ─────────────────────────────────────────────────────
              PrimaryButton(
                label: 'View My Bookings',
                onPressed: () => context.go(AppConstants.routeBookings),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => context.go(AppConstants.routeHome),
                  child: const Text('Back to Home',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(String raw) {
  // Accepts "10:00:00" or "10:00" and returns "10:00 AM"
  try {
    final parts = raw.trim().split(':');
    int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    final String ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    else if (hour > 12) hour -= 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $ampm';
  } catch (_) {
    return raw;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            )),
      ],
    );
  }
}