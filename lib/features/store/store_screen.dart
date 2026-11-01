import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/config/env_config.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';
import '../profile/invoices_screen.dart';
import 'product_detail_screen.dart';

/// Item in the Incline Member Shopping Bag
class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String subCategory;
  int quantity;
  final String? size;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.subCategory,
    this.quantity = 1,
    this.size,
  });

  double get totalPrice => price * quantity;
}

/// Material 3 Luxury Boutique Store for Incline Members
/// Supplements, High-Performance Nutrition & Recovery Add-Ons
class StoreScreen extends StatefulWidget {
  final Member? member;

  const StoreScreen({super.key, this.member});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String _activeCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<BenefitPackage> _packages = [];
  List<StoreProduct> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Shopping Bag State
  final Map<String, CartItem> _cart = {};
  final String _fulfillmentMethod = 'concierge';

  // Razorpay Gateway State
  late Razorpay _razorpay;
  String? _pendingOrderId;
  String? _pendingInvoiceId;
  double _pendingAmount = 0.0;
  BuildContext? _checkoutSheetContext;
  BuildContext? _verificationDialogContext;

  // Promo Code & Wallet State
  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;
  String? _couponError;
  double _walletBalance = 0.0;
  bool _useWalletBalance = false;
  bool _isLoadingWallet = false;
  StateSetter? _sheetSetState;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _loadStoreData();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _searchController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _showVerifyingPaymentDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _verificationDialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: context.cardElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: context.brandAccent.withValues(alpha: 0.5)),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DumbbellLoader(size: DumbbellLoaderSize.md),
                  const SizedBox(height: 20),
                  Text(
                    'Verifying with Incline Vault',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: context.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cryptographically authenticating payment ID: $paymentId',
                    style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.brandAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Strict Invariant: Server-Side Cryptographic Verification',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: context.brandAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissVerificationDialog() {
    if (_verificationDialogContext != null && _verificationDialogContext!.mounted) {
      Navigator.pop(_verificationDialogContext!);
      _verificationDialogContext = null;
    }
  }

  void _showPaymentUnverifiedDialog({
    required String paymentId,
    required String errorReason,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: InclineColors.thermalAmber, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: InclineColors.thermalAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: InclineColors.thermalAmber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verification Pending',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17, color: context.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment of ₹${_pendingAmount.toInt()} was received by Razorpay (ID: $paymentId), but instant server cryptographic verification was not completed.',
              style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: InclineColors.thermalAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Status: $errorReason',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: InclineColors.thermalAmber),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Per Incline financial invariants, client callbacks are never treated as final proof of payment. Our automated webhook reconciler will confirm and settle your order automatically within 2-5 minutes.',
                    style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.outfit(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_checkoutSheetContext != null && _checkoutSheetContext!.mounted) {
                Navigator.pop(_checkoutSheetContext!);
                _checkoutSheetContext = null;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoicesScreen(
                    member: widget.member,
                    branch: null,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandAccent,
              foregroundColor: context.onBrandAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('View Invoices', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    final orderId = response.orderId ?? _pendingOrderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final signature = response.signature ?? '';

    if (_pendingInvoiceId == null) {
      debugPrint('[INCLINE] Warning: _pendingInvoiceId is null in _handleRazorpaySuccess');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment registered, but order invoice reference was missing. Check Invoices screen.'),
            backgroundColor: InclineColors.thermalAmber,
          ),
        );
      }
      return;
    }

    // 1. Show verifying dialog with strict server-side verification requirement
    _showVerifyingPaymentDialog(paymentId);

    // 2. Authoritative backend signature verification via verify-payment Edge Function
    final verifyResult = await SupabaseService.instance.verifyRazorpayPayment(
      invoiceId: _pendingInvoiceId!,
      razorpayPaymentId: paymentId,
      razorpayOrderId: orderId,
      razorpaySignature: signature,
      branchId: widget.member?.branchId,
    );

    // 3. Dismiss verification loader
    _dismissVerificationDialog();

    // 4. Strict Invariant: Display confirmed status ONLY after server-side verification passes
    if (verifyResult.isVerified) {
      // Settle coupon if applied
      if (_appliedCoupon != null) {
        await SupabaseService.instance.redeemCoupon(
          code: _appliedCoupon!['code']?.toString() ?? '',
          subtotal: _cartTotal,
          branchId: widget.member?.branchId,
          memberId: widget.member?.id,
          referenceType: 'invoice',
          referenceId: _pendingInvoiceId,
        );
      }

      // Settle partial wallet balance if applied
      if (_useWalletBalance && _walletBalance > 0) {
        final couponDiscount = (_appliedCoupon?['discount_amount'] as num?)?.toDouble() ?? 0.0;
        final rawNet = _cartTotal - couponDiscount;
        final walletPart = (rawNet - _pendingAmount).clamp(0.0, _walletBalance);
        if (walletPart > 0) {
          await SupabaseService.instance.payInvoiceWithWallet(
            invoiceId: _pendingInvoiceId!,
            amount: walletPart,
            branchId: widget.member?.branchId,
            memberId: widget.member?.id,
            notes: 'Partial payment via Incline Wallet Balance',
          );
        }
      }

      // Settle store order and activate benefits
      await SupabaseService.instance.settleStoreOrder(
        invoiceId: _pendingInvoiceId,
        orderNumber: _pendingOrderId,
        paymentReference: paymentId,
      );

      // Re-fetch wallet balance
      await _fetchWalletBalance();

      if (mounted) {
        if (_checkoutSheetContext != null && _checkoutSheetContext!.mounted) {
          Navigator.pop(_checkoutSheetContext!);
          _checkoutSheetContext = null;
        }
        _showOrderSuccessDialog(
          orderId: _pendingOrderId ?? orderId,
          methodTitle: 'Razorpay Payment Gateway',
          methodSubtitle: 'Payment ID: $paymentId • Cryptographically Verified by Vault',
          amount: _pendingAmount,
        );
      }
    } else {
      // NEVER treat client callback alone as proof of payment
      debugPrint('[INCLINE] Payment verification rejected or pending: ${verifyResult.error}');
      if (mounted) {
        _showPaymentUnverifiedDialog(
          paymentId: paymentId,
          errorReason: verifyResult.error ?? 'Server cryptographic verification failed',
        );
      }
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    debugPrint('[INCLINE] Razorpay payment failure: ${response.code} - ${response.message}');
    if (mounted) {
      final isCancel = response.code == 2 || (response.message?.toLowerCase().contains('cancelled') ?? false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCancel ? 'Payment cancelled' : 'Payment not completed: ${response.message ?? "Cancelled"}'),
          backgroundColor: isCancel ? InclineColors.cardRecessed : Colors.red.shade900,
        ),
      );
    }
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redirected to external wallet: ${response.walletName}'),
          backgroundColor: InclineColors.cardSurface,
        ),
      );
    }
  }

  Future<void> _loadStoreData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchBenefitPackages(widget.member?.branchId),
        SupabaseService.instance.fetchProducts(),
      ]);

      if (mounted) {
        setState(() {
          _packages = results[0] as List<BenefitPackage>;
          _products = results[1] as List<StoreProduct>;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] Store fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load store catalog. Please check your internet connection.';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CART OPERATIONS
  // ---------------------------------------------------------------------------

  int get _totalCartCount => _cart.values.fold(0, (sum, i) => sum + i.quantity);
  double get _cartTotal => _cart.values.fold(0.0, (sum, i) => sum + i.totalPrice);

  void _addToCart(CartItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity += 1;
      } else {
        _cart[item.id] = item;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.cardElevated,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.brandAccent.withValues(alpha: 0.3)),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added ${item.name} to bag',
                style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _showCartSheet(context);
              },
              child: Text(
                'VIEW BAG',
                style: GoogleFonts.outfit(color: context.brandAccent, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuantity(String id, int delta) {
    setState(() {
      if (_cart.containsKey(id)) {
        final newQty = _cart[id]!.quantity + delta;
        if (newQty <= 0) {
          _cart.remove(id);
        } else {
          _cart[id]!.quantity = newQty;
        }
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      _cart.remove(id);
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // PRODUCT IMAGE & CATEGORY RESOLVERS
  // ---------------------------------------------------------------------------

  String _getProductImage(StoreProduct p) {
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty && !p.imageUrl!.contains('unsplash.com')) {
      return p.imageUrl!;
    }
    final name = p.name.toLowerCase();
    if (name.contains('isopure')) {
      if (name.contains('chocolate') || name.contains('dutch')) {
        return 'https://iyqqpbvnszyrrgerniog.supabase.co/storage/v1/object/public/products/products/a4ad96e7-5c6b-45af-8883-b8b727ef740e.webp';
      }
      return 'https://iyqqpbvnszyrrgerniog.supabase.co/storage/v1/object/public/products/products/79af284a-9978-44f6-bfa2-5535451a9cf5.webp';
    }
    if (name.contains('whey')) {
      return 'https://iyqqpbvnszyrrgerniog.supabase.co/storage/v1/object/public/products/products/ce4d37bf-dedb-4a2a-9ad3-e49c4e5ff05d.png';
    }
    if (name.contains('eaa')) {
      return 'https://iyqqpbvnszyrrgerniog.supabase.co/storage/v1/object/public/products/products/d599d9a2-a00e-4078-868d-cecee296c77b.png';
    }
    // No random Unsplash stock photos. Returns empty string to render branded luxury Incline placeholder.
    return '';
  }

  Widget _buildLuxuryPlaceholder({required String subCat, double height = 120, bool isHero = false}) {
    IconData icon = Icons.fitness_center_rounded;
    if (subCat.contains('AMINO') || subCat.contains('RECOVERY')) {
      icon = Icons.bolt_rounded;
    } else if (subCat.contains('FUEL') || subCat.contains('SNACK')) {
      icon = Icons.restaurant_rounded;
    } else if (subCat.contains('BREW') || subCat.contains('COFFEE')) {
      icon = Icons.local_cafe_rounded;
    } else if (subCat.contains('LONGEVITY')) {
      icon = Icons.spa_rounded;
    }

    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            InclineColors.cardRecessed,
            AppTheme.surfaceElevated,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isHero ? 16 : 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.brandAccent.withValues(alpha: 0.12),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Icon(icon, color: context.brandAccent, size: isHero ? 36 : 22),
            ),
            const SizedBox(height: 6),
            Text(
              'INCLINE',
              style: GoogleFonts.outfit(
                fontSize: isHero ? 12 : 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: context.brandAccent.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductSubCategory(StoreProduct p) {
    final name = p.name.toLowerCase();
    if (name.contains('isopure') || name.contains('whey')) return 'PROTEIN & ISOLATE';
    if (name.contains('creatine')) return 'STRENGTH & POWER';
    if (name.contains('eaa') || name.contains('b.c.a.a')) return 'AMINO & RECOVERY';
    if (name.contains('butter') || name.contains('oats') || name.contains('museli')) return 'CLEAN FUEL & SNACKS';
    if (name.contains('coffee')) return 'PROTEIN BREW';
    if (name.contains('fish oil') || name.contains('multivitamin')) return 'DAILY LONGEVITY';
    return 'SUPPLEMENTS';
  }

  bool _isFoodFuel(StoreProduct p) {
    final name = p.name.toLowerCase();
    return name.contains('butter') ||
        name.contains('oats') ||
        name.contains('museli') ||
        name.contains('coffee') ||
        name.contains('edamame');
  }

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    _sheetSetState?.call(() => _isLoadingWallet = true);
    try {
      final bal = await SupabaseService.instance.fetchWalletBalance(widget.member?.id);
      if (mounted) {
        setState(() {
          _walletBalance = bal;
          _isLoadingWallet = false;
        });
        _sheetSetState?.call(() {
          _walletBalance = bal;
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchWalletBalance error: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
        _sheetSetState?.call(() => _isLoadingWallet = false);
      }
    }
  }

  Future<void> _applyCouponCode(String code, double cartTotal, StateSetter setSheetState) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    setSheetState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final res = await SupabaseService.instance.validateCoupon(
        code: trimmed,
        subtotal: cartTotal,
        branchId: widget.member?.branchId,
      );

      if (res['success'] == true) {
        setSheetState(() {
          _appliedCoupon = res;
          _isValidatingCoupon = false;
          _couponError = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Promo code "$trimmed" applied successfully!'),
              backgroundColor: InclineColors.cardSurface,
            ),
          );
        }
      } else {
        final reason = res['reason']?.toString() ?? 'Invalid promo code';
        String msg = 'Invalid promo code';
        if (reason == 'not_found') msg = 'Promo code not recognized';
        if (reason == 'expired') msg = 'This promo code has expired';
        if (reason == 'max_uses') msg = 'Promo code usage limit reached';
        if (reason.contains('min_purchase')) msg = 'Cart does not meet minimum purchase';

        setSheetState(() {
          _couponError = msg;
          _isValidatingCoupon = false;
          _appliedCoupon = null;
        });
      }
    } catch (e) {
      setSheetState(() {
        _couponError = 'Failed to validate promo code';
        _isValidatingCoupon = false;
      });
    }
  }

  void _removeCoupon(StateSetter setSheetState) {
    setSheetState(() {
      _appliedCoupon = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  Future<void> _completeZeroPayOrder({required BuildContext sheetCtx}) async {
    final method = _useWalletBalance ? 'Incline Wallet' : 'Promo Voucher (100% Covered)';
    final ref = 'COVERED/INC-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final orderId = 'ORD-2026-${(DateTime.now().millisecondsSinceEpoch % 90000) + 10000}';

    final itemsPayload = _cart.values.map((item) => {
      'product_id': item.id,
      'name': item.name,
      'quantity': item.quantity,
      'unit_price': item.price,
      'total': item.price * item.quantity,
      if (item.size != null) 'size': item.size,
      if (item.subCategory.isNotEmpty) 'category': item.subCategory,
    }).toList();

    // 1. Create order & invoice in Supabase backend
    final res = await SupabaseService.instance.placeOnlineStoreOrder(
      memberId: widget.member?.id,
      branchId: widget.member?.branchId,
      orderNumber: orderId,
      items: itemsPayload,
      subtotal: _cartTotal,
      totalAmount: 0.0,
      paymentMethod: method,
      paymentReference: ref,
      fulfillmentMethod: _fulfillmentMethod,
      shippingAddress: {
        'fulfillment': _fulfillmentMethod,
        'method': 'Club Concierge Front Desk',
        if (_appliedCoupon != null) 'coupon_code': _appliedCoupon!['code'],
        if (_appliedCoupon != null) 'discount_amount': (_appliedCoupon!['discount_amount'] as num?)?.toDouble() ?? 0.0,
        if (_useWalletBalance) 'wallet_used': _walletBalance,
      },
      isPaid: true,
    );

    final invoiceId = res['invoice_id'] as String?;

    // 2. If coupon applied, redeem it via authoritative RPC
    if (_appliedCoupon != null && invoiceId != null) {
      await SupabaseService.instance.redeemCoupon(
        code: _appliedCoupon!['code']?.toString() ?? '',
        subtotal: _cartTotal,
        branchId: widget.member?.branchId,
        memberId: widget.member?.id,
        referenceType: 'invoice',
        referenceId: invoiceId,
      );
    }

    // 3. If wallet used, record wallet payment via authoritative RPC
    if (_useWalletBalance && invoiceId != null) {
      final couponDiscount = (_appliedCoupon?['discount_amount'] as num?)?.toDouble() ?? 0.0;
      final walletNeeded = (_cartTotal - couponDiscount).clamp(0.0, _walletBalance);
      if (walletNeeded > 0) {
        await SupabaseService.instance.payInvoiceWithWallet(
          invoiceId: invoiceId,
          amount: walletNeeded,
          branchId: widget.member?.branchId,
          memberId: widget.member?.id,
          transactionId: ref,
          notes: 'Zero-balance store order settled via member wallet',
        );
      }
    }

    // 4. Settle store order and activate benefits
    await SupabaseService.instance.settleStoreOrder(
      invoiceId: invoiceId,
      orderNumber: orderId,
      paymentReference: ref,
    );

    // Refresh wallet balance from DB
    await _fetchWalletBalance();

    if (mounted && sheetCtx.mounted) {
      Navigator.pop(sheetCtx);
      _showOrderSuccessDialog(
        orderId: orderId,
        methodTitle: method,
        methodSubtitle: 'Zero-Balance Settlement • Order Fully Covered',
        amount: 0.0,
      );
    }
  }

  Future<void> _payWithRazorpay({required double amount, required BuildContext sheetCtx}) async {
    _checkoutSheetContext = sheetCtx;
    _pendingAmount = amount;

    final orderId = 'ORD-2026-${(DateTime.now().millisecondsSinceEpoch % 90000) + 10000}';
    _pendingOrderId = orderId;

    final itemsPayload = _cart.values.map((item) => {
      'product_id': item.id,
      'name': item.name,
      'quantity': item.quantity,
      'unit_price': item.price,
      'total': item.price * item.quantity,
      if (item.size != null) 'size': item.size,
      if (item.subCategory.isNotEmpty) 'category': item.subCategory,
    }).toList();

    // 1. Create online store order & invoice in Supabase backend (unpaid pending status)
    final res = await SupabaseService.instance.placeOnlineStoreOrder(
      memberId: widget.member?.id,
      branchId: widget.member?.branchId,
      orderNumber: orderId,
      items: itemsPayload,
      subtotal: _cartTotal,
      totalAmount: amount,
      paymentMethod: 'Razorpay Gateway',
      paymentReference: 'pending',
      fulfillmentMethod: _fulfillmentMethod,
      shippingAddress: {
        'fulfillment': _fulfillmentMethod,
        'method': 'Club Concierge Front Desk',
        if (_appliedCoupon != null) 'coupon_code': _appliedCoupon!['code'],
        if (_appliedCoupon != null) 'discount_amount': (_appliedCoupon!['discount_amount'] as num?)?.toDouble() ?? 0.0,
        if (_useWalletBalance) 'wallet_used': _walletBalance,
      },
      isPaid: false,
    );

    _pendingInvoiceId = res['invoice_id'] as String?;

    if (_pendingInvoiceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize store invoice with backend. Please try again.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    // 2. Request trusted payment order from backend edge function
    final paymentOrder = await SupabaseService.instance.createPaymentOrder(
      invoiceId: _pendingInvoiceId!,
      branchId: widget.member?.branchId,
      gateway: 'razorpay',
    );

    if (paymentOrder == null || paymentOrder['gatewayOrderId'] == null) {
      final errorMsg = paymentOrder?['error']?.toString() ?? 'Backend did not produce a payment order';
      debugPrint('[INCLINE] Payment order error: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment order initialization failed: $errorMsg. Try charging to Member Folio.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    final key = paymentOrder['razorpayKey'] as String? ?? EnvConfig.razorpayKeyId;
    final gatewayOrderId = paymentOrder['gatewayOrderId'] as String;
    final serverAmount = (paymentOrder['amount'] is num)
        ? (paymentOrder['amount'] as num).toDouble()
        : amount;

    // 3. Launch native Razorpay checkout with backend-signed order
    final memberName = widget.member?.fullName ?? 'Incline Member';
    final memberEmail = widget.member?.profile?.email ?? 'member@incline.fit';
    final memberPhone = widget.member?.profile?.phone ?? SupabaseService.instance.currentUser?.phone ?? '';

    final options = {
      'key': key,
      'amount': (serverAmount * 100).toInt(),
      'name': 'INCLINE',
      'description': 'Store Order $orderId',
      'order_id': gatewayOrderId,
      'prefill': {
        'contact': memberPhone,
        'email': memberEmail,
        'name': memberName,
      },
      'theme': {
        'color': '#F0441C',
      },
      'modal': {
        'confirm_close': true,
      },
      'external': {
        'wallets': ['paytm', 'phonepe'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('[INCLINE] Native Razorpay exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment gateway is currently unreachable on this device. Please retry or contact front desk.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
    }
  }

  void _showOrderSuccessDialog({
    required String orderId,
    required String methodTitle,
    required String methodSubtitle,
    required double amount,
  }) {
    final fulfillmentText = 'Collect at Club Concierge Front Desk';

    // Capture items summary before clearing cart
    final boughtCount = _totalCartCount;
    _clearCart();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.brandAccent.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Order Confirmed',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: context.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thank you, ${widget.member?.fullName ?? 'Member'}. Your Incline order of $boughtCount item${boughtCount > 1 ? 's' : ''} has been authenticated with our concierge dispensary.',
              style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Number:', style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted)),
                      Text(orderId, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: context.brandAccent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Paid (incl. GST):', style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted)),
                      Text('₹${amount.toInt()}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.emerald)),
                    ],
                  ),
                  Divider(height: 16, color: context.borderCol),
                  Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: context.brandAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          methodTitle,
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      methodSubtitle,
                      style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: context.brandAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          fulfillmentText,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoicesScreen(member: widget.member)),
              );
            },
            child: Text(
              'View GST Invoices',
              style: GoogleFonts.outfit(color: context.brandAccent, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandAccent,
              foregroundColor: context.onBrandAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTERACTIVE CART BOTTOM SHEET (PHONEPE / RAZORPAY / FOLIO)
  // ---------------------------------------------------------------------------

  void _showCartSheet(BuildContext context) {
    _fetchWalletBalance();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          _sheetSetState = setSheetState;
          final items = _cart.values.toList();
          final count = _totalCartCount;
          final rawSubtotal = _cartTotal;

          final discountAmount = _appliedCoupon != null
              ? ((_appliedCoupon!['discount_amount'] as num?)?.toDouble() ?? 0.0)
              : 0.0;
          final afterDiscount = math.max(0.0, rawSubtotal - discountAmount);

          final walletDeduction = _useWalletBalance
              ? math.min(_walletBalance, afterDiscount)
              : 0.0;
          final finalPayable = math.max(0.0, afterDiscount - walletDeduction);

          final gstAmount = (finalPayable * 0.18 / 1.18);

          if (items.isEmpty) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: context.borderCol, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 24),
                    Icon(Icons.shopping_bag_outlined, size: 56, color: context.textMuted),
                    const SizedBox(height: 16),
                    Text('Your Incline Bag is Empty', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Explore supplements and recovery suite packages to add items to your bag.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandAccent,
                        foregroundColor: context.onBrandAccent,
                      ),
                      child: Text('Browse Catalog', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: context.borderCol, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Count & Clear Bag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_rounded, color: context.brandAccent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Incline Bag ($count)',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _clearCart();
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppTheme.rose),
                        label: Text('Clear', style: GoogleFonts.outfit(color: AppTheme.rose, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  Divider(height: 18, color: context.borderCol),

                  // Cart Item List
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(height: 16, color: context.borderCol),
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 56,
                                height: 56,
                                color: context.cardBg,
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.fitness_center_rounded, color: context.brandAccent, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.subCategory}${item.size != null ? ' • Size: ${item.size}' : ''}',
                                    style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${item.price.toInt()}',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: context.brandAccent),
                                  ),
                                ],
                              ),
                            ),
                            // Stepper Controls & Delete Action
                            Container(
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.borderCol),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _updateQuantity(item.id, -1);
                                      setSheetState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.remove_rounded, size: 16, color: context.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      _updateQuantity(item.id, 1);
                                      setSheetState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.add_rounded, size: 16, color: context.brandAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                _removeFromCart(item.id);
                                setSheetState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 18, color: context.textMuted),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Fulfillment Option (Concierge vs Locker)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COLLECTION / FULFILLMENT',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: context.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: context.brandAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.brandAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: context.brandAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Front Desk / Concierge Collection',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Prepared and packaged for member pickup at club reception',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Promo Code / Discount Voucher
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _appliedCoupon != null ? AppTheme.emerald.withValues(alpha: 0.5) : context.borderCol,
                      ),
                    ),
                    child: _appliedCoupon != null
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.emerald),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _appliedCoupon!['code']?.toString() ?? 'PROMO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.emerald,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emerald.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'APPLIED',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.emerald,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Saved ₹${discountAmount.toInt()} on this order',
                                      style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: context.textMuted,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Remove promo code',
                                onPressed: () => _removeCoupon(setSheetState),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_offer_outlined, size: 16, color: context.brandAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _couponController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'ENTER PROMO CODE',
                                        hintStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textMuted, letterSpacing: 0.8),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                      ),
                                      onSubmitted: (code) => _applyCouponCode(code, rawSubtotal, setSheetState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: _isValidatingCoupon
                                          ? null
                                          : () => _applyCouponCode(_couponController.text, rawSubtotal, setSheetState),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context.brandAccent,
                                        foregroundColor: context.onBrandAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: _isValidatingCoupon
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text('Apply', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                ],
                              ),
                              if (_couponError != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.rose),
                                    const SizedBox(width: 4),
                                    Text(
                                      _couponError!,
                                      style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.rose, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 8),

                  // Incline Wallet Balance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _useWalletBalance && walletDeduction > 0
                            ? AppTheme.emerald.withValues(alpha: 0.5)
                            : context.borderCol,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_walletBalance > 0 ? AppTheme.emerald : context.textMuted).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 16,
                            color: _walletBalance > 0 ? AppTheme.emerald : context.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Incline Member Wallet',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              _isLoadingWallet
                                  ? Text('Fetching balance...', style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted))
                                  : Text(
                                      _walletBalance > 0
                                          ? 'Available: ₹${_walletBalance.toInt()}${_useWalletBalance && walletDeduction > 0 ? ' (Applying -₹${walletDeduction.toInt()})' : ''}'
                                          : 'Available balance: ₹0',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: _walletBalance > 0 ? FontWeight.w600 : FontWeight.w400,
                                        color: _walletBalance > 0 ? AppTheme.emerald : context.textMuted,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        if (_walletBalance > 0)
                          Switch.adaptive(
                            value: _useWalletBalance,
                            activeColor: AppTheme.emerald,
                            activeTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
                            onChanged: (val) {
                              setSheetState(() => _useWalletBalance = val);
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Pricing Breakdown Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Items Subtotal:', style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted)),
                            Text('₹${rawSubtotal.toInt()}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                          ],
                        ),
                        if (discountAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Promo Discount (${_appliedCoupon?['code'] ?? 'COUPON'}):',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '-₹${discountAmount.toInt()}',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                              ),
                            ],
                          ),
                        ],
                        if (walletDeduction > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Wallet Balance Applied:',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '-₹${walletDeduction.toInt()}',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Integrated GST (18% Included):', style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted)),
                            Text('₹${gstAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Concierge Bag Fulfillment:', style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted)),
                            Text('COMPLIMENTARY', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                          ],
                        ),
                        Divider(height: 12, color: context.borderCol),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Payable:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
                            Text(
                              '₹${finalPayable.toInt()}',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: finalPayable == 0 ? AppTheme.emerald : context.brandAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Payment Trigger Buttons
                  if (finalPayable <= 0)
                    // Zero Balance Full Coverage Button
                    ElevatedButton(
                      onPressed: () => _completeZeroPayOrder(sheetCtx: sheetCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Confirm Order (Fully Covered)  •  ₹0',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Online Gateway (Consolidated Single Source of Truth: Razorpay handles UPI, Cards, NetBanking)
                    ElevatedButton(
                      onPressed: () => _payWithRazorpay(amount: finalPayable, sheetCtx: sheetCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InclineColors.cardSurface, // Razorpay Dark Navy
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: InclineColors.accentOrange, width: 1.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment_rounded, color: InclineColors.accentOrange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Pay ₹${finalPayable.toInt()} • UPI / Cards / NetBanking',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _sheetSetState = null);
  }

  // ---------------------------------------------------------------------------
  // PRODUCT DETAIL (CARD MORPH TO SCREEN TRANSITION)
  // ---------------------------------------------------------------------------

  void _showProductDetail(StoreProduct product) {
    final img = _getProductImage(product);
    final subCat = _getProductSubCategory(product);
    final isInCart = _cart.containsKey(product.id);
    final qty = isInCart ? _cart[product.id]!.quantity : 0;

    Navigator.push(
      context,
      CardMorphPageRoute(
        child: ProductDetailScreen(
          product: product,
          member: widget.member,
          imageUrl: img,
          subCategory: subCat,
          isInCart: isInCart,
          quantity: qty,
          onAddToCart: () => _addToCart(CartItem(
            id: product.id,
            name: product.name,
            price: product.price,
            imageUrl: img,
            subCategory: subCat,
          )),
          onUpdateQuantity: (delta) => _updateQuantity(product.id, delta),
          onOpenBag: () => _showCartSheet(context),
          onDirectCheckout: () {
            if (!_cart.containsKey(product.id)) {
              _addToCart(CartItem(
                id: product.id,
                name: product.name,
                price: product.price,
                imageUrl: img,
                subCategory: subCat,
              ));
            }
            _showCartSheet(context);
          },
        ),
      ),
    );
  }

  void _onPurchasePackage(BenefitPackage pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Purchase ${pkg.name}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pkg.description ?? 'Recovery suite package for Incline members.',
              style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price (incl. GST):', style: GoogleFonts.outfit(color: context.textMuted)),
                  Text(
                    '₹${pkg.price.toInt()}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.brandAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addToCart(CartItem(
                id: pkg.id,
                name: pkg.name,
                price: pkg.price,
                imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=600&q=80',
                subCategory: 'RECOVERY PACK',
              ));
              _showCartSheet(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandAccent,
              foregroundColor: context.onBrandAccent,
            ),
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter products by category and search
    final query = _searchQuery.trim().toLowerCase();

    final filteredProducts = _products.where((p) {
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_activeCategory == 'all') return true;
      if (_activeCategory == 'supplements') {
        return !_isFoodFuel(p);
      }
      if (_activeCategory == 'fuel') {
        return _isFoodFuel(p);
      }
      if (_activeCategory == 'recovery') return false; // Handled separately
      return true;
    }).toList();

    final cartCount = _totalCartCount;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incline Member Store', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
            Text('Nutrition & recovery suite dispensary', style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_rounded, color: context.brandAccent),
            tooltip: 'Past Invoices & Receipts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InvoicesScreen(member: widget.member)),
            ),
          ),
          // Luxury Shopping Bag Icon with Count Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.shopping_bag_outlined, color: context.brandAccent),
                tooltip: 'Shopping Bag',
                onPressed: () => _showCartSheet(context),
              ),
              if (cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.brandAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        '$cartCount',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: cartCount > 0
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: context.cardElevated,
                border: Border(top: BorderSide(color: context.brandAccent.withValues(alpha: 0.3))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$cartCount ITEM${cartCount > 1 ? 'S' : ''} IN BAG',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: context.textMuted),
                        ),
                        Text(
                          '₹${_cartTotal.toInt()}',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: context.brandAccent),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showCartSheet(context),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text('Checkout Bag', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandAccent,
                        foregroundColor: context.onBrandAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: DumbbellLoader(text: 'Loading Incline catalog...', size: DumbbellLoaderSize.md))
            : (_errorMessage != null && _packages.isEmpty && _products.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, color: context.brandAccent, size: 48),
                          const SizedBox(height: 14),
                          Text(
                            'Could Not Load Dispensary Catalog',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _loadStoreData,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.brandAccent,
                              foregroundColor: context.onBrandAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: context.cardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(fontSize: 14, color: context.textPrimary),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search nutrition, supplements, recovery packs...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13, color: context.textMuted),
                          prefixIcon: Icon(Icons.search_rounded, color: context.brandAccent, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: context.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _categoryPill('all', 'All Items', Icons.grid_view_rounded),
                          const SizedBox(width: 8),
                          _categoryPill('supplements', 'Nutrition & Whey', Icons.fitness_center_rounded),
                          const SizedBox(width: 8),
                          _categoryPill('recovery', 'Recovery Packs', Icons.hot_tub_rounded),
                          const SizedBox(width: 8),
                          _categoryPill('fuel', 'Clean Fuel & Snacks', Icons.restaurant_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recovery Add-Ons Featured Carousel (when 'all' or 'recovery')
                    if ((_activeCategory == 'all' || _activeCategory == 'recovery') && _packages.isNotEmpty && _searchQuery.isEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECOVERY SUITE PACKAGES',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: context.textMuted,
                            ),
                          ),
                          Text(
                            '${_packages.length} Available',
                            style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 165,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _packages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, idx) {
                            final pkg = _packages[idx];
                            return _buildPackageCard(pkg);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Products Bento Grid Section
                    if (filteredProducts.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeCategory == 'fuel'
                                ? 'HEALTHY SNACKS & NUTRITION FUEL'
                                : (_activeCategory == 'supplements' ? 'PERFORMANCE NUTRITION & ISOLATES' : 'INCLINE DISPENSARY CATALOG'),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: context.textMuted,
                            ),
                          ),
                          Text(
                            '${filteredProducts.length} Products',
                            style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProducts.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        itemBuilder: (context, idx) {
                          final product = filteredProducts[idx];
                          return _buildProductBentoCard(product);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (filteredProducts.isEmpty && _activeCategory != 'recovery') ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, color: context.textMuted, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No products found matching "$_searchQuery"'
                                    : 'No products currently available in this category.',
                                style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _categoryPill(String id, String label, IconData icon) {
    final isSelected = _activeCategory == id;
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.brandAccent : context.cardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? context.brandAccent : context.borderCol),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : context.brandAccent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.black : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(BenefitPackage pkg) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hot_tub_rounded, color: context.brandAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pkg.name,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            pkg.description ?? '${pkg.quantity} private sessions • ${pkg.validityDays}d validity',
            style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${pkg.price.toInt()}',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.brandAccent),
              ),
              ElevatedButton.icon(
                onPressed: () => _onPurchasePackage(pkg),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: Text('Add to Bag', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandAccent,
                  foregroundColor: context.onBrandAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductBentoCard(StoreProduct product) {
    final img = _getProductImage(product);
    final subCat = _getProductSubCategory(product);
    final isInCart = _cart.containsKey(product.id);
    final qty = isInCart ? _cart[product.id]!.quantity : 0;
    final heroTag = 'product_card_hero_${product.id}';

    return GestureDetector(
      onTap: () => _showProductDetail(product),
      child: BentoCard(
        padding: EdgeInsets.zero,
        backgroundColor: context.cardElevated,
        border: Border.all(color: context.borderCol),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image with Category Pill (Full Card Hero Header)
            Hero(
              tag: heroTag,
              createRectTween: (begin, end) => CardMorphArcRectTween(begin: begin, end: end),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        color: context.cardBg,
                        child: img.isNotEmpty
                            ? Image.network(
                                img,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildLuxuryPlaceholder(subCat: subCat, height: 120),
                              )
                            : _buildLuxuryPlaceholder(subCat: subCat, height: 120),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.cardElevated.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.brandAccent.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              subCat,
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: context.brandAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content info & Direct Add/Stepper
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.price.toInt()}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.brandAccent,
                          ),
                        ),
                        if (isInCart)
                          Container(
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.brandAccent.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _updateQuantity(product.id, -1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.remove_rounded, size: 14, color: context.textSecondary),
                                  ),
                                ),
                                Text(
                                  '$qty',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: context.brandAccent),
                                ),
                                InkWell(
                                  onTap: () => _updateQuantity(product.id, 1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.add_rounded, size: 14, color: context.brandAccent),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          InclineScaleButton(
                            onTap: () => _addToCart(CartItem(
                              id: product.id,
                              name: product.name,
                              price: product.price,
                              imageUrl: img,
                              subCategory: subCat,
                            )),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.brandAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 14, color: context.onBrandAccent),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Add',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: context.onBrandAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
