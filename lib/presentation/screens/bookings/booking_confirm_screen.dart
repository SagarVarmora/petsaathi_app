import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../widgets/common/common_widgets.dart';

class BookingConfirmScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  const BookingConfirmScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final booking = bookingData['booking'] as BookingModel?;
    final service = bookingData['service'] as Map<String, dynamic>? ?? {};
    final petName = bookingData['petName'] as String? ?? '';

    if (booking == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Go Home',
                onPressed: () => context.go(AppConstants.routeHome),
              ),
            ],
          ),
        ),
      );
    }

    final date = booking.scheduledAt;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${date.day} ${months[date.month - 1]} ${date.year}';
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr =
        '$hour:${date.minute.toString().padLeft(2, '0')} $ampm';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── Success Icon ──────────────────────────────────────────────
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
                    border:
                        Border.all(color: AppTheme.primary, width: 3),
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
                '${service['title'] ?? ''} has been booked for $petName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // ── Booking Details Card ──────────────────────────────────────
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
                        value: dateStr),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: timeStr),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.person_rounded,
                        label: 'Companion',
                        value: booking.companionName ?? 'Assigned soon'),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Amount',
                        value: '₹${booking.price}',
                        valueColor: AppTheme.primary),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Booking ID ────────────────────────────────────────────────
              Text(
                'Booking ID: ${booking.id.split('_').last}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
              ),

              const Spacer(),

              // ── Actions ───────────────────────────────────────────────────
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
