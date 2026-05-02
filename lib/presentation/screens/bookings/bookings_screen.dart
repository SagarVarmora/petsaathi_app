import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/booking_repository.dart';

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
    // Fetch fresh bookings when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingRepository>().fetchBookings();
    });
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
        actions: [
          if (repo.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => repo.fetchBookings(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Active (${repo.activeBookings.length})'),
            Tab(text: 'Past (${repo.pastBookings.length})'),
          ],
        ),
      ),
      body: repo.error != null && repo.bookings.isEmpty
          ? _ErrorState(
        message: repo.error!,
        onRetry: () => repo.fetchBookings(),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          // ── Active Tab ─────────────────────────────────────────────
          _BookingList(
            bookings: repo.activeBookings,
            isLoading: repo.isLoading,
            emptyEmoji: '📅',
            emptyTitle: 'No active bookings',
            emptySubtitle: 'Book a service for your pet today!',
            emptyButtonLabel: 'Explore Services',
            onEmptyButton: () => context.go(AppConstants.routeHome),
            showCancel: true,
          ),
          // ── Past Tab ───────────────────────────────────────────────
          _BookingList(
            bookings: repo.pastBookings,
            isLoading: repo.isLoading,
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

// ─────────────────────────────────────────────────────────────────────────────
// Booking List
// ─────────────────────────────────────────────────────────────────────────────
class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final bool isLoading;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyButtonLabel;
  final VoidCallback? onEmptyButton;
  final bool showCancel;

  const _BookingList({
    required this.bookings,
    required this.isLoading,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyButtonLabel,
    this.onEmptyButton,
    required this.showCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Show skeleton while loading with no cached data
    if (isLoading && bookings.isEmpty) {
      return _BookingSkeleton();
    }

    if (bookings.isEmpty) {
      return _EmptyState(
        emoji: emptyEmoji,
        title: emptyTitle,
        subtitle: emptySubtitle,
        buttonLabel: emptyButtonLabel,
        onButton: onEmptyButton,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => context.read<BookingRepository>().fetchBookings(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _BookingCard(
          booking: bookings[i],
          showCancel: showCancel,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Card
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool showCancel;

  const _BookingCard({required this.booking, required this.showCancel});

  // ── Status styling ──────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.upcoming:
        return const Color(0xFF2E7D52);
      case BookingStatus.running:
        return const Color(0xFF1565C0);
      case BookingStatus.completed:
        return const Color(0xFF43A047);
      case BookingStatus.cancelled:
        return const Color(0xFFE53935);
      case BookingStatus.pending:
      default:
        return const Color(0xFFF57C00);
    }
  }

  Color get _statusBgColor => _statusColor.withOpacity(0.1);

  IconData get _statusIcon {
    switch (booking.status) {
      case BookingStatus.upcoming:
        return Icons.upcoming_rounded;
      case BookingStatus.running:
        return Icons.play_circle_rounded;
      case BookingStatus.completed:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
      case BookingStatus.pending:
      default:
        return Icons.schedule_rounded;
    }
  }

  // ── Service emoji (best-guess from name) ────────────────────────────────────
  String get _serviceEmoji {
    final name = booking.serviceName.toLowerCase();
    if (name.contains('groom')) return '✂️';
    if (name.contains('walk')) return '🦮';
    if (name.contains('vet') || name.contains('health')) return '🩺';
    if (name.contains('train')) return '🎾';
    if (name.contains('sit') || name.contains('board')) return '🏠';
    if (name.contains('bath')) return '🚿';
    return '🐾';
  }

  // ── Payment status styling ──────────────────────────────────────────────────
  Color get _paymentColor {
    switch (booking.paymentStatus.toLowerCase()) {
      case 'completed':
        return const Color(0xFF43A047);
      case 'refunded':
        return const Color(0xFF1565C0);
      case 'pending':
      default:
        return const Color(0xFFF57C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = booking.amount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: booking.status == BookingStatus.running
              ? const Color(0xFF1565C0).withOpacity(0.3)
              : AppTheme.divider,
          width: booking.status == BookingStatus.running ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service emoji badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      _serviceEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Service name + provider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              booking.providerName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 12, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        booking.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Divider ──────────────────────────────────────────────────────────
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 12),

          // ── Info Row ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Booking ID
                _InfoChip(
                  icon: Icons.confirmation_number_outlined,
                  label: '#${booking.id}',
                ),
                const SizedBox(width: 10),

                // Date
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: booking.bookingDate,
                ),

                const Spacer(),

                // Amount
                if (hasAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${booking.amount.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Pay on Service',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF57C00),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Payment & Refund Status ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _StatusPill(
                  label: 'Payment: ${_capitalise(booking.paymentStatus)}',
                  color: _paymentColor,
                ),
                if (booking.refundStatus != 'No Refund') ...[
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: 'Refund: ${booking.refundStatus}',
                    color: booking.refundStatus == 'Refund Completed'
                        ? const Color(0xFF43A047)
                        : const Color(0xFF1565C0),
                  ),
                ],
              ],
            ),
          ),

          // ── OTP (for active bookings) ────────────────────────────────────────
          if (booking.otp != null && booking.isActive) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open_rounded,
                        color: Colors.amber.shade700, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Service OTP: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    Text(
                      '${booking.otp}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber.shade900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Cancel Button ────────────────────────────────────────────────────
          if (showCancel && booking.canCancel) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(
                        color: AppTheme.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Cancel confirmation dialog ──────────────────────────────────────────────
  Future<void> _confirmCancel(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking #${booking.id} — ${booking.serviceName}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason for cancellation',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., Change in plans...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppTheme.inputBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Booking'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('Yes, Cancel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final reason =
      reasonController.text.trim().isEmpty
          ? 'No reason provided'
          : reasonController.text.trim();

      final response = await context
          .read<BookingRepository>()
          .cancelBooking(booking.id, cancelReason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.success
                  ? 'Booking #${booking.id} cancelled successfully.'
                  : response.errorMessage,
            ),
            backgroundColor:
            response.success ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 46)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: onButton,
                  child: Text(buttonLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.wifi_off_rounded,
                    color: AppTheme.error, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load bookings',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Loader
// ─────────────────────────────────────────────────────────────────────────────

class _BookingSkeleton extends StatefulWidget {
  @override
  State<_BookingSkeleton> createState() => _BookingSkeletonState();
}

class _BookingSkeletonState extends State<_BookingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double r = 8}) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppTheme.divider,
        borderRadius: BorderRadius.circular(r),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _box(50, 50, r: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(double.infinity, 14),
                      const SizedBox(height: 8),
                      _box(120, 12),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _box(70, 26, r: 20),
              ],
            ),
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _anim,
              child: const Divider(height: 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _box(80, 12),
                const SizedBox(width: 10),
                _box(100, 12),
                const Spacer(),
                _box(60, 28, r: 10),
              ],
            ),
            const SizedBox(height: 10),
            _box(110, 10),
          ],
        ),
      ),
    );
  }
}