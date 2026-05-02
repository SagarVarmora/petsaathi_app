import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/payment_repository.dart';

// pubspec.yaml: razorpay_flutter: ^1.3.6

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const PaymentScreen({super.key, required this.bookingData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  String _selectedMethod = 'online';
  bool _isProcessing = false;
  bool _isVerifying = false;

  int? _bookingId;
  String? _razorpayOrderId;

  // ── Data helpers ───────────────────────────────────────────────────────────
  int get _bookingIdFromData => (widget.bookingData['bookingId'] as int?) ?? 0;
  double get _finalAmount => (widget.bookingData['finalAmount'] as num?)?.toDouble() ?? 0.0;
  double get _totalAmount => (widget.bookingData['totalAmount'] as num?)?.toDouble() ?? 0.0;
  double get _discountedAmount => (widget.bookingData['discountedAmount'] as num?)?.toDouble() ?? 0.0;
  String get _serviceName => widget.bookingData['serviceName'] as String? ?? '';
  String get _serviceEmoji => widget.bookingData['serviceEmoji'] as String? ?? '🐾';
  String get _petName => widget.bookingData['petName'] as String? ?? '';
  String get _providerName => widget.bookingData['providerName'] as String? ?? '';
  String get _bookingDate => widget.bookingData['bookingDate'] as String? ?? '';
  String get _slotTime => widget.bookingData['slotTime'] as String? ?? '';
  bool get _hasDiscount => _discountedAmount > 0 && _totalAmount != _finalAmount;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentRepository>().fetchWalletSummary();
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Razorpay handlers ──────────────────────────────────────────────────────
  void _handleRazorpaySuccess(PaymentSuccessResponse res) async {
    if (!mounted) return;
    setState(() => _isVerifying = true);
    final result = await context.read<PaymentRepository>().verifyPayment(
      bookingId: _bookingId ?? _bookingIdFromData,
      razorpayPaymentId: res.paymentId ?? '',
      razorpayOrderId: res.orderId ?? _razorpayOrderId ?? '',
      razorpaySignature: res.signature ?? '',
    );
    setState(() => _isVerifying = false);
    if (!mounted) return;
    if (result.isSuccess) {
      _goToConfirm(paymentStatus: 'completed', paymentMethod: 'online');
    } else {
      _snack(result.error ?? 'Payment verification failed', isError: true);
    }
  }

  void _handleRazorpayError(PaymentFailureResponse res) {
    if (!mounted) return;
    _snack('Payment failed: ${res.message ?? "Unknown error"}', isError: true);
  }

  void _handleExternalWallet(ExternalWalletResponse res) {
    _snack('External wallet selected: ${res.walletName}');
  }

  // ── Proceed ────────────────────────────────────────────────────────────────
  Future<void> _proceed() async {
    if (_bookingIdFromData == 0) {
      _snack('Invalid booking. Please try again.', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    final result = await context.read<PaymentRepository>().createPayment(
      bookingId: _bookingIdFromData,
      paymentMethod: _selectedMethod,
    );
    setState(() => _isProcessing = false);
    if (!mounted) return;

    if (!result.isSuccess) {
      _snack(result.error ?? 'Could not initiate payment', isError: true);
      return;
    }
    if (result.isCod) {
      _goToConfirm(paymentStatus: 'pending', paymentMethod: 'cod');
      return;
    }
    if (result.walletOnly) {
      _goToConfirm(paymentStatus: 'completed', paymentMethod: 'wallet');
      return;
    }

    _bookingId = result.bookingId ?? _bookingIdFromData;
    _razorpayOrderId = result.razorpayOrderId;

    if (result.razorpayKey == null || result.razorpayOrderId == null) {
      _snack('Payment gateway error. Please try again.', isError: true);
      return;
    }

    final amountPaise = ((result.remainingAmount ?? _finalAmount) * 100).toInt();
    try {
      _razorpay.open({
        'key': result.razorpayKey,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'PetSaathi',
        'description': '$_serviceName for $_petName',
        'order_id': result.razorpayOrderId,
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#1A5C38'},
        'notes': {'booking_id': _bookingId.toString()},
      });
    } catch (e) {
      _snack('Could not open Razorpay: $e', isError: true);
    }
  }

  void _goToConfirm({required String paymentStatus, required String paymentMethod}) {
    context.pushReplacement(AppConstants.routeBookingConfirm, extra: {
      ...widget.bookingData,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.info_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? AppTheme.error : const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final payRepo = context.watch<PaymentRepository>();
    final wallet = payRepo.wallet;

    if (_isVerifying) return _buildVerifyingScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ── Scrollable content ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // 1. Order Summary Card (compact)
                    _buildOrderSummaryCard(),
                    const SizedBox(height: 14),

                    // 2. Payment Methods + contextual info in one card
                    _buildPaymentCard(wallet, payRepo),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Sticky bottom: button + security note ───────────────────────
            _buildStickyBottom(wallet),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A1A2E)),
        onPressed: () => context.pop(),
      ),
      title: const Text('Payment',
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEFF4)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. ORDER SUMMARY CARD — compact horizontal layout
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOrderSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF82), Color(0xFF2E7D5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // ── Service + booking info row ──────────────────────────────────
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: Text(_serviceEmoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_serviceName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('For $_petName  ·  #$_bookingIdFromData',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                    if (_providerName.isNotEmpty || _slotTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [if (_providerName.isNotEmpty) _providerName, if (_slotTime.isNotEmpty) _slotTime]
                            .join('  ·  '),
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Price row ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                // Left: original + discount (if any)
                if (_hasDiscount) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${_totalAmount.toInt()}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white54)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('− ₹${_discountedAmount.toInt()} off',
                                  style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Text('Total Payable',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ),

                // Right: final amount (prominent)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_finalAmount.toInt()}',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    if (_hasDiscount)
                      Text('Total payable',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. PAYMENT CARD — methods + inline contextual info
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentCard(WalletInfo? wallet, PaymentRepository repo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEFF4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text('PAYMENT METHOD',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1.0)),
          ),

          // ── Online ──────────────────────────────────────────────────────
          _MethodTile(
            icon: Icons.credit_card_rounded,
            title: 'Pay Online',
            subtitle: 'UPI, Cards, Net Banking via Razorpay',
            badge: 'Instant',
            badgeColor: const Color(0xFF1565C0),
            selected: _selectedMethod == 'online',
            onTap: () => setState(() => _selectedMethod = 'online'),
          ),

          const _TileDivider(),

          // ── Wallet ──────────────────────────────────────────────────────
          _MethodTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'PetSaathi Wallet',
            subtitle: repo.isLoadingWallet
                ? 'Loading balance…'
                : wallet != null
                ? 'Balance: ₹${wallet.balance.toStringAsFixed(2)}'
                : 'Balance: ₹0.00',
            badge: wallet == null
                ? null
                : wallet.balance >= _finalAmount
                ? 'Sufficient'
                : wallet.balance > 0
                ? 'Partial'
                : null,
            badgeColor: wallet != null && wallet.balance >= _finalAmount
                ? const Color(0xFF16A34A)
                : const Color(0xFFF57C00),
            selected: _selectedMethod == 'wallet',
            onTap: () => setState(() => _selectedMethod = 'wallet'),
            trailingWidget: repo.isLoadingWallet
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            )
                : null,
          ),

          const _TileDivider(),

          // ── COD ──────────────────────────────────────────────────────────
          _MethodTile(
            icon: Icons.home_rounded,
            title: 'Pay at Doorstep',
            subtitle: 'Pay cash when provider arrives',
            badge: 'COD',
            badgeColor: const Color(0xFF7C3AED),
            selected: _selectedMethod == 'cod',
            onTap: () => setState(() => _selectedMethod = 'cod'),
          ),

          // ── Inline contextual info ──────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _buildContextualInfo(wallet),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Contextual info: rendered INSIDE the payment card, below methods ───────
  Widget _buildContextualInfo(WalletInfo? wallet) {
    // COD details
    if (_selectedMethod == 'cod') {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(
          children: [
            _CodPoint(
              icon: Icons.schedule_rounded,
              text: 'Payment collected at the start of service',
            ),
            const SizedBox(height: 8),
            _CodPoint(
              icon: Icons.currency_rupee_rounded,
              text: 'Keep exact cash ready — ₹${_finalAmount.toInt()}',
            ),
            const SizedBox(height: 8),
            _CodPoint(
              icon: Icons.receipt_long_rounded,
              text: 'Digital receipt sent after service completion',
            ),
          ],
        ),
      );
    }

    // Partial wallet notice
    if (_selectedMethod == 'wallet' && wallet != null && wallet.balance > 0 && wallet.balance < _finalAmount) {
      final remaining = _finalAmount - wallet.balance;
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade800, height: 1.5),
                  children: [
                    TextSpan(
                        text: '₹${wallet.balance.toStringAsFixed(0)} ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: 'from wallet  +  '),
                    TextSpan(
                        text: '₹${remaining.toStringAsFixed(0)} ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: 'via Razorpay'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STICKY BOTTOM — button + security note
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStickyBottom(WalletInfo? wallet) {
    final isCod = _selectedMethod == 'cod';
    final label = _resolveButtonLabel(wallet);
    final icon = _resolveButtonIcon(wallet);
    final gradientColors = isCod
        ? [const Color(0xFF7C3AED), const Color(0xFF5B21B6)]
        : [const Color(0xFF4CAF82), const Color(0xFF2E7D5E)];
    final shadowColor = isCod
        ? const Color(0xFF7C3AED).withOpacity(0.3)
        : AppTheme.primary.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── CTA Button ────────────────────────────────────────────────
            GestureDetector(
              onTap: _isProcessing ? null : _proceed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: shadowColor, blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _isProcessing
                      ? [
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    const Text('Processing…',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]
                      : [
                    Icon(icon, color: Colors.white, size: 19),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.1)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Security note ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCod ? Icons.info_outline_rounded : Icons.verified_user_rounded,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 5),
                Text(
                  isCod
                      ? 'Booking confirmed · payment collected on arrival'
                      : 'Payments secured by Razorpay · 256-bit SSL',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Button label/icon helpers ──────────────────────────────────────────────
  String _resolveButtonLabel(WalletInfo? wallet) {
    switch (_selectedMethod) {
      case 'cod':
        return 'Confirm — Pay ₹${_finalAmount.toInt()} at Doorstep';
      case 'wallet':
        if (wallet != null && wallet.balance >= _finalAmount) {
          return 'Pay ₹${_finalAmount.toInt()} from Wallet';
        } else if (wallet != null && wallet.balance > 0) {
          final rem = _finalAmount - wallet.balance;
          return 'Pay ₹${rem.toInt()} via Razorpay + Wallet';
        }
        return 'Pay ₹${_finalAmount.toInt()} via Razorpay';
      default:
        return 'Pay ₹${_finalAmount.toInt()} Online';
    }
  }

  IconData _resolveButtonIcon(WalletInfo? wallet) {
    switch (_selectedMethod) {
      case 'cod':
        return Icons.home_rounded;
      case 'wallet':
        if (wallet != null && wallet.balance >= _finalAmount) {
          return Icons.account_balance_wallet_rounded;
        }
        return Icons.credit_card_rounded;
      default:
        return Icons.lock_rounded;
    }
  }

  // ── Verifying screen ───────────────────────────────────────────────────────
  Widget _buildVerifyingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: AppTheme.primarySurface, shape: BoxShape.circle),
              child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3)),
            ),
            const SizedBox(height: 20),
            const Text('Verifying Payment…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            const Text('Please wait, do not close the app',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAYMENT METHOD TILE
// ═══════════════════════════════════════════════════════════════════════════════
class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.selected,
    required this.onTap,
    this.trailingWidget,
  });

  // Color helpers
  Color get _isCod => badgeColor == const Color(0xFF7C3AED)
      ? const Color(0xFF7C3AED)
      : AppTheme.primary;
  Color get _selBg => badgeColor == const Color(0xFF7C3AED)
      ? const Color(0xFFF5F3FF)
      : AppTheme.primarySurface;
  Color get _selTextColor => badgeColor == const Color(0xFF7C3AED)
      ? const Color(0xFF5B21B6)
      : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _selBg : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? _isCod : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? _isCod : const Color(0xFFEEEFF4),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : const Color(0xFF6B7280), size: 21),
            ),
            const SizedBox(width: 13),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected ? _selTextColor : const Color(0xFF1A1A2E))),
                      if (badge != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppTheme.primary).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor ?? AppTheme.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            // Radio or spinner
            trailingWidget ??
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? _isCod : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COD BULLET POINT
// ═══════════════════════════════════════════════════════════════════════════════
class _CodPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CodPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF5B21B6), fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THIN DIVIDER BETWEEN TILES
// ═══════════════════════════════════════════════════════════════════════════════
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0F0F0));
  }
}