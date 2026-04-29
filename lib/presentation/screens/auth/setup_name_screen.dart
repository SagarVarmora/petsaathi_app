import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/common_widgets.dart';

class SetupNameScreen extends StatefulWidget {
  final String phone;
  const SetupNameScreen({super.key, required this.phone});

  @override
  State<SetupNameScreen> createState() => _SetupNameScreenState();
}

class _SetupNameScreenState extends State<SetupNameScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ─── Register API call ────────────────────────────────────────────────────
  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthRepository>();
    final response = await auth.registerAndSendOtp(
      phone: widget.phone,
      name: name,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (response.success) {
      // Registration success → OTP screen (register flow)
      context.pushReplacement(
        AppConstants.routeOtp,
        extra: {
          'phone': widget.phone,
          'flow': 'register',
        },
      );
    } else {
      // Error handle — mobile already exists?
      final errMsg = response.errorMessage;
      if (errMsg.toLowerCase().contains('mobile') &&
          errMsg.toLowerCase().contains('taken')) {
        // Already registered → login flow pe redirect karo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This number is already registered. Logging you in...'),
            backgroundColor: AppTheme.primary,
          ),
        );
        final loginResp =
        await auth.loginAndSendOtp(phone: widget.phone);
        if (!mounted) return;
        if (loginResp.success) {
          context.pushReplacement(
            AppConstants.routeOtp,
            extra: {
              'phone': widget.phone,
              'flow': 'login',
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loginResp.errorMessage),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child:
                          Text('👋', style: TextStyle(fontSize: 36)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create your account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New account for +91 ${widget.phone}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Name ──────────────────────────────────────────────────
                const Text(
                  'Your Full Name *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Rahul Sharma',
                    prefixIcon:
                    Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  onSubmitted: (_) => _continue(),
                ),

                const SizedBox(height: 20),

                // ── Email (optional) ──────────────────────────────────────
                const Text(
                  'Email (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'your@email.com',
                    prefixIcon:
                    Icon(Icons.email_outlined, size: 20),
                  ),
                ),

                const SizedBox(height: 8),
                const InfoBanner(
                  message:
                  'OTP will be sent to your WhatsApp number to verify your account.',
                ),

                const SizedBox(height: 32),

                PrimaryButton(
                  label: 'Create Account & Get OTP',
                  onPressed: _continue,
                  isLoading: _isLoading,
                  icon: Icons.arrow_forward_rounded,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}