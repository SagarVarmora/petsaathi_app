import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/common_widgets.dart';

// ─── Flow Types ───────────────────────────────────────────────────────────────
// 'login'    → existing user, /login/verify-otp
// 'register' → new user, /verify-otp

class OtpScreen extends StatefulWidget {
  final String phone;
  final String flow; // 'login' | 'register'

  const OtpScreen({
    super.key,
    required this.phone,
    this.flow = 'login',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _hasError = false;
  int _resendSeconds = 30;
  Timer? _timer;

  // ─── Pinput Themes ──────────────────────────────────────────────────────────
  PinTheme get _defaultPinTheme => PinTheme(
    width: 46,
    height: 54,
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.inputBorder, width: 1.5),
    ),
  );

  PinTheme get _focusedPinTheme => _defaultPinTheme.copyDecorationWith(
    border: Border.all(color: AppTheme.primary, width: 2),
  );

  PinTheme get _submittedPinTheme => _defaultPinTheme.copyDecorationWith(
    border: Border.all(color: AppTheme.primary, width: 1.5),
    color: AppTheme.primary.withOpacity(0.06),
  );

  PinTheme get _errorPinTheme => _defaultPinTheme.copyDecorationWith(
    border: Border.all(color: AppTheme.error, width: 1.5),
    color: AppTheme.error.withOpacity(0.06),
  );

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ─── Timer ──────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  // ─── Verify OTP ─────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    final otp = _pinController.text;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final auth = context.read<AuthRepository>();

    // Flow ke hisaab se API call
    final response = widget.flow == 'login'
        ? await auth.verifyLoginOtp(phone: widget.phone, otp: otp)
        : await auth.verifyRegisterOtp(phone: widget.phone, otp: otp);

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (response.success) {
      // Session save ho gaya, home pe redirect
      context.go(AppConstants.routeHome);
    } else {
      // Error — OTP clear karo
      setState(() => _hasError = true);
      _pinController.clear();
      _pinFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.errorMessage),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // ─── Resend OTP ──────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    final auth = context.read<AuthRepository>();

    setState(() => _hasError = false);

    if (widget.flow == 'login') {
      // Login resend
      final response = await auth.loginAndSendOtp(phone: widget.phone);
      if (mounted) {
        if (response.success) {
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent via WhatsApp!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } else {
      // Register resend — user wapas setup name screen pe jayega
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please try registering again.')),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
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
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildPinput(),
                const SizedBox(height: 28),
                _buildResendRow(),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Verify & Continue',
                  onPressed: _verify,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                // Test mode hint
                Center(
                  child: Text(
                    'Test number: 9664675200 → OTP: 123456',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI Sections ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('🐾', style: TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              children: [
                const TextSpan(text: 'Code sent to +91 '),
                TextSpan(
                  text: widget.phone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextSpan(
                  text: widget.flow == 'register'
                      ? '\n(via WhatsApp)'
                      : '\n(via WhatsApp)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinput() {
    return Center(
      child: Pinput(
        length: 6,
        controller: _pinController,
        focusNode: _pinFocusNode,
        defaultPinTheme: _defaultPinTheme,
        focusedPinTheme: _focusedPinTheme,
        submittedPinTheme:
        _hasError ? _errorPinTheme : _submittedPinTheme,
        errorPinTheme: _errorPinTheme,
        keyboardType: TextInputType.number,
        autofocus: true,
        onCompleted: (_) => _verify(),
        hapticFeedbackType: HapticFeedbackType.lightImpact,
        closeKeyboardWhenCompleted: true,
      ),
    );
  }

  Widget _buildResendRow() {
    return Center(
      child: _resendSeconds > 0
          ? RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
          children: [
            const TextSpan(text: "Didn't receive code? "),
            TextSpan(
              text: 'Resend in ${_resendSeconds}s',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )
          : GestureDetector(
        onTap: _resendOtp,
        child: const Text(
          "Didn't receive code? Resend",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}