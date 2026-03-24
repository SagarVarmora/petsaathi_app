import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/common_widgets.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isLoading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  // ── Pinput Theme ────────────────────────────────────────────────────────────
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
    border: Border.all(color: Colors.redAccent, width: 1.5),
  );

  // ── Lifecycle ───────────────────────────────────────────────────────────────
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

  // ── Timer ───────────────────────────────────────────────────────────────────
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

  // ── OTP Verify ──────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    final otp = _pinController.text;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthRepository>();
    final ok = await auth.verifyOtp(widget.phone, otp);

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (ok) {
      context.pushReplacement(AppConstants.routeSetupName, extra: widget.phone);
    } else {
      _pinController.clear();
      _pinFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code. Please try again.')),
      );
    }
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────────
  void _resendOtp() {
    _startTimer();
    context.read<AuthRepository>().sendOtp(widget.phone);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent!')),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
                _buildDemoHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI Sections ─────────────────────────────────────────────────────────────

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
          Text(
            'We sent a code to +91 ${widget.phone}',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
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
        submittedPinTheme: _submittedPinTheme,
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

  Widget _buildDemoHint() {
    return Center(
      child: Text(
        'Demo Mode: Enter any 6-digit code',
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}