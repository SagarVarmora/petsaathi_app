import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../widgets/common/common_widgets.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BookingRepository>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Upcoming (${repo.upcomingBookings.length})'),
            Tab(text: 'Past (${repo.pastBookings.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Upcoming ───────────────────────────────────────────────────
          _BookingList(
            bookings: repo.upcomingBookings,
            emptyEmoji: '📅',
            emptyTitle: 'No upcoming bookings',
            emptySubtitle: 'Book a service for your pet today!',
            emptyButtonLabel: 'Book a Service',
            onEmptyButton: () => context.go(AppConstants.routeHome),
            showCancel: true,
          ),
          // ── Past ───────────────────────────────────────────────────────
          _BookingList(
            bookings: repo.pastBookings,
            emptyEmoji: '🕰️',
            emptyTitle: 'No past bookings',
            emptySubtitle: 'Your completed bookings will appear here.',
            showCancel: false,
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyButtonLabel;
  final VoidCallback? onEmptyButton;
  final bool showCancel;

  const _BookingList({
    required this.bookings,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyButtonLabel,
    this.onEmptyButton,
    required this.showCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return EmptyStateWidget(
        emoji: emptyEmoji,
        title: emptyTitle,
        subtitle: emptySubtitle,
        buttonLabel: emptyButtonLabel,
        onButton: onEmptyButton,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BookingCard(
        booking: bookings[i],
        showCancel: showCancel,
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool showCancel;

  const _BookingCard({required this.booking, required this.showCancel});

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.upcoming:
        return AppTheme.primary;
      case BookingStatus.ongoing:
        return Colors.blue;
      case BookingStatus.completed:
        return AppTheme.success;
      case BookingStatus.cancelled:
        return AppTheme.error;
    }
  }

  String get _serviceEmoji {
    final s = AppConstants.services.firstWhere(
      (s) => s['id'] == booking.serviceId,
      orElse: () => {'icon': '🐾'},
    );
    return s['icon'] ?? '🐾';
  }

  @override
  Widget build(BuildContext context) {
    final date = booking.scheduledAt;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${date.day} ${months[date.month - 1]} ${date.year}';
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${date.minute.toString().padLeft(2, '0')} $ampm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_serviceEmoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.serviceTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        )),
                    Text('For ${booking.petName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Details ────────────────────────────────────────────────────
          Row(
            children: [
              _Chip(icon: Icons.calendar_today_outlined, label: dateStr),
              const SizedBox(width: 10),
              _Chip(icon: Icons.access_time_rounded, label: timeStr),
              const Spacer(),
              Text('₹${booking.price}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  )),
            ],
          ),

          if (booking.companionName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text('Companion: ${booking.companionName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],

          if (showCancel &&
              booking.status == BookingStatus.upcoming) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancel Booking?'),
                      content: const Text(
                          'Are you sure you want to cancel this booking?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Yes, Cancel',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context
                        .read<BookingRepository>()
                        .cancelBooking(booking.id);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: const Text('Cancel Booking',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
