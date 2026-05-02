import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/models/customer_profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    await context.read<AuthRepository>().fetchProfile();
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  // ─── Delete Account Dialog ─────────────────────────────────────────────────
  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppTheme.error, size: 44),
        title: const Text(
          'Delete Account?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will permanently delete your account, pets, and all bookings. This action cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = context.read<AuthRepository>();
      final response = await auth.deleteAccount();

      if (!mounted) return;

      if (response.success) {
        context.go(AppConstants.routeLogin);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.errorMessage),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final petRepo = context.watch<PetRepository>();
    final bookingRepo = context.watch<BookingRepository>();
    final walletRepo = context.watch<WalletRepository>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _refreshProfile,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppConstants.routeEditProfile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Avatar + Name ──────────────────────────────────────────────────
          _buildAvatarSection(auth, profile),

          const SizedBox(height: 24),

          // ── Stats ──────────────────────────────────────────────────────────
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

          const SizedBox(height: 16),

          // ── Wallet Balance Banner ──────────────────────────────────────────
          _buildWalletBanner(walletRepo, auth),

          const SizedBox(height: 16),

          // ── Contact Info ───────────────────────────────────────────────────
          if (profile != null) _buildContactCard(profile),

          const SizedBox(height: 16),

          // ── Bank Details (if set) ──────────────────────────────────────────
          if (profile?.primaryBank != null &&
              profile!.primaryBank!.hasDetails) ...[
            _buildBankCard(profile.primaryBank!),
            const SizedBox(height: 16),
          ],

          // ── My Pets ────────────────────────────────────────────────────────
          _SectionCard(
            title: 'MY PETS',
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

          // ── Account Settings ───────────────────────────────────────────────
          _SectionCard(
            title: 'ACCOUNT',
            children: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () => context.push(AppConstants.routeEditProfile),
              ),
              // ── Wallet ─────────────────────────────────────────────────────
              _WalletMenuItem(
                walletRepo: walletRepo,
                onTap: () => context.push(AppConstants.routeWallet),
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

          // ── Logout ─────────────────────────────────────────────────────────
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
                      content:
                      const Text('Are you sure you want to log out?'),
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

          const SizedBox(height: 12),

          // ── Delete Account ─────────────────────────────────────────────────
          _SectionCard(
            children: [
              _MenuItem(
                icon: Icons.delete_forever_rounded,
                label: 'Delete Account',
                sublabel: 'Permanently delete your account and data',
                onTap: _showDeleteDialog,
                iconColor: AppTheme.error,
                labelColor: AppTheme.error,
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('PetSaathi v1.0.0',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Wallet Balance Banner ──────────────────────────────────────────────────
  Widget _buildWalletBanner(WalletRepository walletRepo, AuthRepository auth) {
    return GestureDetector(
      onTap: () => context.push(AppConstants.routeWallet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, Color(0xFF5B7BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  walletRepo.isLoading && walletRepo.summary == null
                      ? const SizedBox(
                    width: 80,
                    height: 20,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    '₹${walletRepo.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white60,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Avatar Section ────────────────────────────────────────────────────────
  Widget _buildAvatarSection(AuthRepository auth, CustomerProfile? profile) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.push(AppConstants.routeEditProfile),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
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
              child: ClipOval(
                child: _buildProfileImage(auth, profile),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile?.name ?? auth.userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+91 ${profile?.mobile ?? auth.userPhone}',
            style:
            const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          if (profile?.email != null && profile!.email!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              profile.email!,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage(AuthRepository auth, CustomerProfile? profile) {
    final imgUrl = profile?.profileImageUrl ?? profile?.profileImage;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Image.network(imgUrl,
          fit: BoxFit.cover,
          width: 88,
          height: 88,
          errorBuilder: (_, __, ___) => _avatarFallback(auth, profile));
    }
    return _avatarFallback(auth, profile);
  }

  Widget _avatarFallback(AuthRepository auth, CustomerProfile? profile) {
    final name = profile?.name ?? auth.userName;
    final parts = name.trim().split(' ');
    String initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return Container(
      width: 88,
      height: 88,
      color: AppTheme.primarySurface,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            )),
      ),
    );
  }

  // ─── Contact Info Card ─────────────────────────────────────────────────────
  Widget _buildContactCard(CustomerProfile profile) {
    return _SectionCard(
      title: 'CONTACT INFO',
      children: [
        if (profile.email != null && profile.email!.isNotEmpty)
          _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email!),
        _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: '+91 ${profile.mobile}'),
        if (profile.address != null && profile.address!.isNotEmpty)
          _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: profile.address!),
      ],
    );
  }

  // ─── Bank Card ─────────────────────────────────────────────────────────────
  Widget _buildBankCard(BankAccount bank) {
    return _SectionCard(
      title: 'PAYMENT DETAILS',
      children: [
        if (bank.bankName != null && bank.bankName!.isNotEmpty)
          _InfoRow(
              icon: Icons.account_balance_outlined,
              label: 'Bank',
              value: bank.bankName!),
        if (bank.accountNo != null && bank.accountNo!.isNotEmpty)
          _InfoRow(
              icon: Icons.credit_card_outlined,
              label: 'Account',
              value: _maskAccount(bank.accountNo!)),
        if (bank.ifscCode != null && bank.ifscCode!.isNotEmpty)
          _InfoRow(
              icon: Icons.code_rounded, label: 'IFSC', value: bank.ifscCode!),
        if (bank.upiId != null && bank.upiId!.isNotEmpty)
          _InfoRow(
              icon: Icons.payment_outlined, label: 'UPI', value: bank.upiId!),
      ],
    );
  }

  String _maskAccount(String acc) {
    if (acc.length <= 4) return acc;
    return '${'•' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }
}

// ─── Wallet Menu Item (with live balance chip) ────────────────────────────────
class _WalletMenuItem extends StatelessWidget {
  final WalletRepository walletRepo;
  final VoidCallback onTap;

  const _WalletMenuItem({required this.walletRepo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'My Wallet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Balance chip
            if (walletRepo.isLoading && walletRepo.summary == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              )
            else
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${walletRepo.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
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

// ─── Section Card ─────────────────────────────────────────────────────────────
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(title!,
                  style: const TextStyle(
                    fontSize: 11,
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

// ─── Menu Item ────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.sublabel,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? AppTheme.textPrimary,
                      )),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
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