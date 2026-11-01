import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

// -----------------------------------------------------------------------------
// 1. CUSTOM ARC RECT TWEEN (60FPS FLUID MOTION INTERPOLATION)
// -----------------------------------------------------------------------------

/// Custom RectTween interpolating bounding boxes along a curved parabolic arc
/// with iOS fluid spring easing Cubic(0.2, 0.0, 0.0, 1.0).
class CardMorphArcRectTween extends RectTween {
  CardMorphArcRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return null;

    // Apply luxury cubic easing curve (Curves.fastLinearToSlowEaseIn / 60fps spring)
    final curvedT = const Cubic(0.2, 0.0, 0.0, 1.0).transform(t);

    // Parabolic arc for center coordinates
    final centerArc = MaterialPointArcTween(
      begin: begin!.center,
      end: end!.center,
    ).lerp(curvedT);

    final width = ui.lerpDouble(begin!.width, end!.width, curvedT)!;
    final height = ui.lerpDouble(begin!.height, end!.height, curvedT)!;

    return Rect.fromCenter(
      center: centerArc,
      width: width,
      height: height,
    );
  }
}

// -----------------------------------------------------------------------------
// 2. CURVED PAGE ROUTE BUILDER
// -----------------------------------------------------------------------------

/// Custom PageRouteBuilder delivering seamless card-to-screen morph transitions.
class CardMorphPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  CardMorphPageRoute({
    required this.child,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Smooth background backdrop cross-fade
            final fadeIn = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
            );

            return FadeTransition(
              opacity: fadeIn,
              child: child,
            );
          },
        );
}

// -----------------------------------------------------------------------------
// 3. FULL CARD HERO DETAIL SCREEN
// -----------------------------------------------------------------------------

class ProductDetailScreen extends StatefulWidget {
  final StoreProduct product;
  final Member? member;
  final String imageUrl;
  final String subCategory;
  final bool isInCart;
  final int quantity;
  final VoidCallback onAddToCart;
  final void Function(int delta) onUpdateQuantity;
  final VoidCallback onOpenBag;
  final VoidCallback onDirectCheckout;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.member,
    required this.imageUrl,
    required this.subCategory,
    required this.isInCart,
    required this.quantity,
    required this.onAddToCart,
    required this.onUpdateQuantity,
    required this.onOpenBag,
    required this.onDirectCheckout,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _contentFadeController;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;

  late bool _isInCart;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _isInCart = widget.isInCart;
    _quantity = widget.quantity;

    _contentFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _contentFadeAnimation = CurvedAnimation(
      parent: _contentFadeController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentFadeController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    ));

    // Stagger content reveal right as the hero header finishes its morph arc
    _contentFadeController.forward();
  }

  @override
  void dispose() {
    _contentFadeController.dispose();
    super.dispose();
  }

  void _handleAddToCart() {
    HapticFeedback.lightImpact();
    setState(() {
      _isInCart = true;
      _quantity += 1;
    });
    widget.onAddToCart();
  }

  void _handleUpdateQuantity(int delta) {
    HapticFeedback.selectionClick();
    final newQty = _quantity + delta;
    setState(() {
      if (newQty <= 0) {
        _isInCart = false;
        _quantity = 0;
      } else {
        _quantity = newQty;
      }
    });
    widget.onUpdateQuantity(delta);
  }

  Widget _buildLuxuryHeroPlaceholder({required String subCat, double height = 300}) {
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.brandAccent.withValues(alpha: 0.15),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(icon, color: context.brandAccent, size: 44),
            ),
            const SizedBox(height: 10),
            Text(
              'INCLINE',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: context.brandAccent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'product_card_hero_${widget.product.id}';
    final hasImage = widget.imageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels < -60) {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
            return true;
          }
          return false;
        },
        child: Stack(
          children: [
            // Scrollable Page Content
            CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ---------------------------------------------------------------
              // FULL CARD HERO HEADER
              // ---------------------------------------------------------------
              SliverToBoxAdapter(
                child: Hero(
                  tag: heroTag,
                  createRectTween: (begin, end) => CardMorphArcRectTween(begin: begin, end: end),
                  flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
                    );
                    return AnimatedBuilder(
                      animation: curvedAnimation,
                      builder: (context, _) {
                        final radius = ui.lerpDouble(16.0, 0.0, curvedAnimation.value)!;
                        return Material(
                          color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(flightDirection == HeroFlightDirection.push ? 0 : 16),
                              bottom: Radius.circular(radius),
                            ),
                            child: toHeroContext.widget,
                          ),
                        );
                      },
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardElevated,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                        border: Border(
                          bottom: BorderSide(color: context.borderCol, width: 1.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Product Image Visual
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                            child: Container(
                              height: 340,
                              width: double.infinity,
                              color: context.cardBg,
                              child: hasImage
                                  ? Image.network(
                                      widget.imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _buildLuxuryHeroPlaceholder(subCat: widget.subCategory, height: 340),
                                    )
                                  : _buildLuxuryHeroPlaceholder(subCat: widget.subCategory, height: 340),
                            ),
                          ),

                          // Ambient Bottom Gradient Vignette
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.65),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Header Overlay Badges (Top & Bottom)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Category Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: context.brandAccent.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: context.brandAccent.withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    widget.subCategory,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: context.brandAccent,
                                    ),
                                  ),
                                ),

                                // Incline Verified Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.emerald.withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 14, color: AppTheme.emerald),
                                      const SizedBox(width: 4),
                                      Text(
                                        '100% Incline Certified',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.emerald,
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
                  ),
                ),
              ),

              // ---------------------------------------------------------------
              // STAGGERED REVEAL CONTENT BODY
              // ---------------------------------------------------------------
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _contentFadeAnimation,
                  child: SlideTransition(
                    position: _contentSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Price Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${widget.product.price.toInt()}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: context.brandAccent,
                                    ),
                                  ),
                                  Text(
                                    'incl. 18% GST',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Product Description
                          Text(
                            widget.product.description ??
                                'Premium club-verified sports nutrition and wellness supplement. Temperature-controlled and stored in Incline concierge dispensary for peak biological absorption.',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.55,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Dispensary Storage & Quality Guarantee Bento Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.cardElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderCol),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: context.brandAccent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.ac_unit_rounded, size: 20, color: context.brandAccent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cold-Chain Vault Storage',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Preserved at 18°C in club dispensary until collected.',
                                        style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Collection / Fulfillment Selection
                          Text(
                            'COLLECTION / FULFILLMENT PREFERENCE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: context.brandAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.brandAccent.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 20,
                                  color: context.brandAccent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Front Desk / Concierge Pickup',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Packaged and ready at reception after your workout',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
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
                  ),
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // FLOATING GLASSMORPHIC TOP BAR (BACK & BAG BUTTONS)
          // -------------------------------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (Triggers reverse hero morph back into card)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                        tooltip: 'Back to Store',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),

                // Bag Quick Access
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white),
                        tooltip: 'View Bag',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenBag();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // STICKY BOTTOM CHECKOUT ACTION BAR
          // -------------------------------------------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: context.cardElevated.withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(color: context.borderCol, width: 1.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Direct Add / Stepper
                      if (_isInCart)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.brandAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 20),
                                color: context.textSecondary,
                                onPressed: () => _handleUpdateQuantity(-1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$_quantity',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.brandAccent,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 20),
                                color: context.brandAccent,
                                onPressed: () => _handleUpdateQuantity(1),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _handleAddToCart,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.brandAccent,
                              side: BorderSide(color: context.brandAccent, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add to Bag',
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(width: 12),

                      // Instant Buy / Open Bag
                      Expanded(
                        flex: 3,
                        child: InclineScaleButton(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            widget.onDirectCheckout();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: context.brandAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, size: 18, color: context.onBrandAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'Instant Checkout',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: context.onBrandAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
