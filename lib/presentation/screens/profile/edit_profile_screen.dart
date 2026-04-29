import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/customer_profile_model.dart';
import '../../widgets/common/common_widgets.dart';

// NOTE: Add to pubspec.yaml:
//   image_picker: ^1.1.2

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNoController;
  late TextEditingController _ifscController;
  late TextEditingController _upiController;

  final _formKey = GlobalKey<FormState>();

  // ── State ────────────────────────────────────────────────────────────────────
  File? _pickedImage;           // new image selected by user
  bool _isLoading = false;
  bool _isFetchingProfile = true;
  String? _existingImageUrl;   // URL from server (already saved image)

  // Tab controller for Basic / Bank sections
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() => _currentTab = _tabController.index));

    _nameController    = TextEditingController();
    _emailController   = TextEditingController();
    _mobileController  = TextEditingController();
    _addressController = TextEditingController();
    _bankNameController  = TextEditingController();
    _accountNoController = TextEditingController();
    _ifscController    = TextEditingController();
    _upiController     = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _accountNoController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  // ─── Load existing profile ────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final auth = context.read<AuthRepository>();

    // Use cached profile if available, else fetch from API
    CustomerProfile? profile = auth.profile;
    if (profile == null) {
      final result = await auth.fetchProfile();
      if (result.isSuccess) profile = result.profile;
    }

    if (profile != null) {
      _nameController.text    = profile.name;
      _emailController.text   = profile.email ?? '';
      _mobileController.text  = profile.mobile;
      _addressController.text = profile.address ?? '';
      _existingImageUrl = profile.profileImageUrl ?? profile.profileImage;

      final bank = profile.primaryBank;
      if (bank != null) {
        _bankNameController.text   = bank.bankName ?? '';
        _accountNoController.text  = bank.accountNo ?? '';
        _ifscController.text       = bank.ifscCode ?? '';
        _upiController.text        = bank.upiId ?? '';
      }
    } else {
      // Fallback to SharedPreferences values
      _nameController.text   = auth.userName;
      _mobileController.text = auth.userPhone;
    }

    setState(() => _isFetchingProfile = false);
  }

  // ─── Pick image from gallery ──────────────────────────────────────────────
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
              title: const Text('Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFrom(ImageSource.camera);
              },
            ),
            if (_pickedImage != null || _existingImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error),
                title: const Text('Remove Photo',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _pickedImage = null;
                    _existingImageUrl = null;
                  });
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      // Switch to Basic tab if name is invalid
      if (_nameController.text.trim().isEmpty && _currentTab != 0) {
        _tabController.animateTo(0);
      }
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthRepository>();
    final result = await auth.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      mobile: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      profileImage: _pickedImage,
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      accountNo: _accountNoController.text.trim().isEmpty
          ? null
          : _accountNoController.text.trim(),
      ifscCode: _ifscController.text.trim().isEmpty
          ? null
          : _ifscController.text.trim().toUpperCase(),
      upiId: _upiController.text.trim().isEmpty
          ? null
          : _upiController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Profile updated successfully!'),
        ]),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Update failed. Please try again.'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isFetchingProfile)
            TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              )
                  : const Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline_rounded, size: 18), text: 'Personal'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 18), text: 'Bank Details'),
          ],
        ),
      ),
      body: _isFetchingProfile
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 14),
            Text('Loading profile...',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalTab(),
            _buildBankTab(),
          ],
        ),
      ),
      bottomNavigationBar: _isFetchingProfile
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: 'Save Changes',
            onPressed: _save,
            isLoading: _isLoading,
            icon: Icons.check_rounded,
          ),
        ),
      ),
    );
  }

  // ─── Personal Tab ─────────────────────────────────────────────────────────
  Widget _buildPersonalTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // ── Avatar ────────────────────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    color: AppTheme.primarySurface,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _buildAvatarContent()),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Tap to change photo',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),

        const SizedBox(height: 28),

        // ── Full Name ─────────────────────────────────────────────────────────
        _fieldLabel('Full Name *'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g., Rahul Sharma',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
          validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),

        const SizedBox(height: 18),

        // ── Email ─────────────────────────────────────────────────────────────
        _fieldLabel('Email Address'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null; // optional
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
            return null;
          },
        ),

        const SizedBox(height: 18),

        // ── Mobile ────────────────────────────────────────────────────────────
        _fieldLabel('Mobile Number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            hintText: '98765 43210',
            prefixIcon: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Text(
                '+91',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontSize: 15),
              ),
            ),
            prefixIconConstraints:
            BoxConstraints(minWidth: 60, minHeight: 54),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null; // optional
            if (v.length != 10) return 'Enter a valid 10-digit number';
            return null;
          },
        ),

        const SizedBox(height: 18),

        // ── Address ───────────────────────────────────────────────────────────
        _fieldLabel('Address'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g., 12, MG Road, Ahmedabad, Gujarat',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Bank Details Tab ─────────────────────────────────────────────────────
  Widget _buildBankTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Info banner
        const InfoBanner(
          message:
          'Bank details are used for refunds and payouts. All data is securely stored.',
        ),
        const SizedBox(height: 24),

        // ── Bank Name ─────────────────────────────────────────────────────────
        _fieldLabel('Bank Name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bankNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g., State Bank of India',
            prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
          ),
        ),

        const SizedBox(height: 18),

        // ── Account Number ────────────────────────────────────────────────────
        _fieldLabel('Account Number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _accountNoController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Enter account number',
            prefixIcon: Icon(Icons.credit_card_outlined, size: 20),
          ),
        ),

        const SizedBox(height: 18),

        // ── IFSC Code ─────────────────────────────────────────────────────────
        _fieldLabel('IFSC Code'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ifscController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 11,
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'e.g., SBIN0001234',
            prefixIcon: Icon(Icons.code_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final regex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
            if (!regex.hasMatch(v.trim().toUpperCase())) {
              return 'Enter a valid IFSC code (e.g., SBIN0001234)';
            }
            return null;
          },
        ),

        const SizedBox(height: 18),

        // ── Divider ───────────────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or pay via UPI',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 18),

        // ── UPI ID ────────────────────────────────────────────────────────────
        _fieldLabel('UPI ID'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _upiController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'e.g., yourname@upi',
            prefixIcon: Icon(Icons.payment_outlined, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!v.contains('@')) return 'Enter a valid UPI ID (e.g., name@upi)';
            return null;
          },
        ),

        const SizedBox(height: 32),

        // Verification note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Please ensure bank details are accurate. Incorrect details may result in failed payouts.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Avatar Content ───────────────────────────────────────────────────────
  Widget _buildAvatarContent() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover,
          width: 96, height: 96);
    }
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
        errorBuilder: (_, __, ___) => _initialsAvatar(),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    final auth = context.read<AuthRepository>();
    final name = auth.profile?.name ?? auth.userName;
    final parts = name.trim().split(' ');
    String initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return Container(
      width: 96,
      height: 96,
      color: AppTheme.primarySurface,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    ),
  );
}