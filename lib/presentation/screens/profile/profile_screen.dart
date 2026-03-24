import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/pet_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final petRepo = context.watch<PetRepository>();
    final bookingRepo = context.watch<BookingRepository>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppConstants.routeEditProfile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Avatar + Name ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      auth.userName.isNotEmpty
                          ? auth.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  auth.userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+91 ${auth.userPhone}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Stats ──────────────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: 'Pets',
                value: '${petRepo.pets.length}',
                icon: Icons.pets_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Bookings',
                value: '${bookingRepo.bookings.length}',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Completed',
                value:
                    '${bookingRepo.pastBookings.where((b) => b.status.name == 'completed').length}',
                icon: Icons.check_circle_rounded,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── My Pets ────────────────────────────────────────────────────
          _SectionCard(
            title: 'My Pets',
            children: [
              if (petRepo.pets.isEmpty)
                _MenuItem(
                  icon: Icons.add_circle_outline,
                  label: 'Add your first pet',
                  onTap: () => context.push(AppConstants.routeAddPet),
                  iconColor: AppTheme.primary,
                )
              else
                ...petRepo.pets.map(
                  (pet) => _MenuItem(
                    icon: Icons.pets_rounded,
                    label: '${pet.emoji}  ${pet.name} · ${pet.breed}',
                    onTap: () => context.push(
                        '${AppConstants.routePetDetail}/${pet.id}'),
                  ),
                ),
              _MenuItem(
                icon: Icons.add_circle_outline,
                label: 'Add another pet',
                onTap: () => context.push(AppConstants.routeAddPet),
                iconColor: AppTheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Account ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Account',
            children: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () => context.push(AppConstants.routeEditProfile),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Logout ─────────────────────────────────────────────────────
          _SectionCard(
            children: [
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log Out?'),
                      content: const Text(
                          'Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Log Out',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthRepository>().logout();
                    context.go(AppConstants.routeLogin);
                  }
                },
                iconColor: AppTheme.error,
                labelColor: AppTheme.error,
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('PetSaathi v1.0.0',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textHint)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                )),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _SectionCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(title!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  )),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
