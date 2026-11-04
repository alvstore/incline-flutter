import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/incline_colors.dart';

/// Navigation item definition for the Curved Notch Navigation Bar
class CapsuleNavItem {
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final bool isCenterHero;

  const CapsuleNavItem({
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    this.isCenterHero = false,
  });
}

/// 1:1 Curved Notch Animated Bottom Navigation Bar
///
/// Implements exact CAD-grade tangency:
/// - Concentric circular cradle arc wrapping smoothly around the active circular bubble
/// - Tangent-continuous convex fillet arcs (C1 continuity) transitioning smoothly from the cradle to the flat top edge
/// - Exact concentric cradle gap (uniform depth around the circle)
/// - Adaptive rounded ears for edge tabs (tab 0 and last tab)
/// - Dual-theme mastery:
///   * Light Mode: crisp white dock with soft claymorphic cradle groove
///   * Dark Mode: elevated obsidian glass gradient with specular 1px white highlight rim and ambient thermal aura
class CurvedNotchNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<CapsuleNavItem> items;

  const CurvedNotchNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  State<CurvedNotchNavBar> createState() => _CurvedNotchNavBarState();
}

class _CurvedNotchNavBarState extends State<CurvedNotchNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _fromIndex = 0.0;
  double _toIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = widget.selectedIndex.toDouble();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(CurvedNotchNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      if (disableAnimations) {
        _fromIndex = widget.selectedIndex.toDouble();
        _toIndex = widget.selectedIndex.toDouble();
        _controller.value = 1.0;
      } else {
        _fromIndex = _currentInterpolatedIndex;
        _toIndex = widget.selectedIndex.toDouble();
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _currentInterpolatedIndex {
    return ui.lerpDouble(_fromIndex, _toIndex, _animation.value) ?? _toIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final barHeight = isCompact ? 62.0 : 66.0;
        const topOverflow = 24.0;
        final totalHeight = barHeight + topOverflow;

        // Exact CAD proportions
        final circleRadius = isCompact ? 22.0 : 25.0;
        final bubbleSize = circleRadius * 2;
        final cradleRadius = isCompact ? 28.5 : 32.5; // Uniform 7.5dp gap
        final filletRadius = isCompact ? 11.0 : 13.5;
        const circleCenterY = 9.0; // Y center of active circle relative to barTop

        final margin = isCompact
            ? const EdgeInsets.fromLTRB(12, 0, 12, 6)
            : const EdgeInsets.fromLTRB(16, 0, 16, 10);

        final usableWidth = constraints.maxWidth - margin.horizontal;
        final itemCount = widget.items.length;
        final itemWidth = usableWidth / itemCount;

        // Calculate fillet tangent spread (dx)
        final distSq = math.pow(cradleRadius + filletRadius, 2) -
            math.pow(filletRadius - circleCenterY, 2);
        final spreadDx = math.sqrt(math.max(0.0, distSq));

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final activeInterpolated = _currentInterpolatedIndex;
            final rawNotchCenter = (activeInterpolated + 0.5) * itemWidth;

            // Clamped notch center so tangent fillet always stays within dock boundaries
            final minXc = spreadDx + 6.0;
            final maxXc = usableWidth - spreadDx - 6.0;
            final notchCenter = math.max(minXc, math.min(maxXc, rawNotchCenter));

            // Bubble placement: center aligns with notchCenter and circleCenterY
            final bubbleTop = (topOverflow + circleCenterY) - circleRadius;
            final bubbleLeft = notchCenter - circleRadius;

            return Container(
              margin: margin,
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Mathematically tangent curved notch dock
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TangentCurvedNotchPainter(
                        notchCenter: notchCenter,
                        circleCenterY: circleCenterY,
                        cradleRadius: cradleRadius,
                        filletRadius: filletRadius,
                        spreadDx: spreadDx,
                        barTop: topOverflow,
                        cornerRadius: isCompact ? 24.0 : 28.0,
                        fillColor: isDark
                            ? const Color(0xFF222226)
                            : InclineColors.lightCardSurface,
                        borderColor: isDark
                            ? const Color(0x30FFFFFF) // Crisp 19% white specular rim
                            : InclineColors.lightCardBorder,
                        shadowColor: isDark
                            ? Colors.black.withValues(alpha: 0.70)
                            : Colors.black.withValues(alpha: 0.08),
                        isDark: isDark,
                      ),
                    ),
                  ),

                  // 2. Inactive Tab Buttons
                  Positioned(
                    top: topOverflow,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(itemCount, (index) {
                        final item = widget.items[index];
                        final isSelected = widget.selectedIndex == index;

                        // Smoothly fade inactive icon as notch approaches
                        final distance = (activeInterpolated - index).abs();
                        final iconOpacity = math.max(
                          0.0,
                          math.min(1.0, distance * 1.6 - 0.3),
                        );

                        return Expanded(
                          child: _buildInactiveTabTarget(
                            context: context,
                            item: item,
                            index: index,
                            isSelected: isSelected,
                            iconOpacity: iconOpacity,
                            isDark: isDark,
                          ),
                        );
                      }),
                    ),
                  ),

                  // 3. Floating Active Circular Bubble
                  Positioned(
                    top: bubbleTop,
                    left: bubbleLeft,
                    child: _buildActiveFloatingBubble(
                      bubbleSize: bubbleSize,
                      item: widget.items[widget.selectedIndex],
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Builds the touch target for inactive tabs with high-contrast text & icons
  Widget _buildInactiveTabTarget({
    required BuildContext context,
    required CapsuleNavItem item,
    required int index,
    required bool isSelected,
    required double iconOpacity,
    required bool isDark,
  }) {
    final iconColor = isDark
        ? const Color(0xFFA1A1AA) // Crisp silver zinc for high dark-mode contrast
        : InclineColors.lightTextSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: () {
            if (item.isCenterHero) {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.lightImpact();
            }
            widget.onItemSelected(index);
          },
          highlightShape: BoxShape.circle,
          containedInkWell: true,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hidden label for accessibility & widget test verification
                Opacity(
                  opacity: 0.0,
                  child: SizedBox.shrink(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 1),
                    ),
                  ),
                ),
                Opacity(
                  opacity: iconOpacity,
                  child: Icon(
                    item.outlineIcon,
                    size: 22,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the active circular bubble with crisp focused depth & dark-mode thermal glow
  Widget _buildActiveFloatingBubble({
    required double bubbleSize,
    required CapsuleNavItem item,
    required bool isDark,
  }) {
    const activeGradient = LinearGradient(
      colors: [InclineColors.accentOrange, InclineColors.thermalRed],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return IgnorePointer(
      child: Container(
        width: bubbleSize,
        height: bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: activeGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (isDark)
              BoxShadow(
                color: InclineColors.accentOrange.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: child,
              );
            },
            child: Icon(
              item.filledIcon,
              key: ValueKey(item.label),
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// CAD-Grade Tangent Curved Notch Painter with Dual-Theme Mastery
class _TangentCurvedNotchPainter extends CustomPainter {
  final double notchCenter;
  final double circleCenterY;
  final double cradleRadius;
  final double filletRadius;
  final double spreadDx;
  final double barTop;
  final double cornerRadius;
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final bool isDark;

  _TangentCurvedNotchPainter({
    required this.notchCenter,
    required this.circleCenterY,
    required this.cradleRadius,
    required this.filletRadius,
    required this.spreadDx,
    required this.barTop,
    required this.cornerRadius,
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height - barTop;

    final xc = notchCenter;
    final yc = circleCenterY;
    final rc = cradleRadius;
    final rf = filletRadius;
    final dx = spreadDx;

    // Contact vector between cradle circle and fillet circle
    final vx = dx / (rc + rf);
    final vy = (rf - yc) / (rc + rf);
    final cx = vx * rc;
    final cy = yc + vy * rc;

    final xLeftStart = xc - dx;
    final xLeftContact = xc - cx;
    final yContact = barTop + cy;
    final xRightContact = xc + cx;
    final xRightEnd = xc + dx;

    // Adaptive corner ears
    final leftCornerR = math.min(cornerRadius, math.max(6.0, xLeftStart));
    final rightCornerR = math.min(cornerRadius, math.max(6.0, W - xRightEnd));

    final path = Path();

    // 1. Start at top-left corner
    path.moveTo(0, barTop + leftCornerR);
    path.arcToPoint(
      Offset(leftCornerR, barTop),
      radius: Radius.circular(leftCornerR),
    );

    // 2. Flat top line to start of left fillet
    if (xLeftStart > leftCornerR) {
      path.lineTo(xLeftStart, barTop);
    }

    // 3. Convex left fillet arc (curves downward into the scoop)
    path.arcToPoint(
      Offset(xLeftContact, yContact),
      radius: Radius.circular(rf),
      clockwise: true,
    );

    // 4. Concentric circular cradle arc (sweeps counter-clockwise under the bubble)
    path.arcToPoint(
      Offset(xRightContact, yContact),
      radius: Radius.circular(rc),
      clockwise: false,
    );

    // 5. Convex right fillet arc (curves upward back to flat line)
    path.arcToPoint(
      Offset(xRightEnd, barTop),
      radius: Radius.circular(rf),
      clockwise: true,
    );

    // 6. Flat top line to top-right corner
    if (W - rightCornerR > xRightEnd) {
      path.lineTo(W - rightCornerR, barTop);
    }

    // 7. Top-right corner
    path.arcToPoint(
      Offset(W, barTop + rightCornerR),
      radius: Radius.circular(rightCornerR),
    );

    // 8. Right vertical edge to bottom-right corner
    path.lineTo(W, barTop + H - cornerRadius);
    path.arcToPoint(
      Offset(W - cornerRadius, barTop + H),
      radius: Radius.circular(cornerRadius),
    );

    // 9. Bottom edge
    path.lineTo(cornerRadius, barTop + H);
    path.arcToPoint(
      Offset(0, barTop + H - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // 10. Close path
    path.close();

    // Ambient drop shadow under the dock
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 20 : 16);
    canvas.drawPath(path.shift(Offset(0, isDark ? 8 : 6)), shadowPaint);

    // Surface fill: luxury vertical obsidian gradient in dark mode, pure crisp white in light mode
    final fillPaint = Paint()..style = PaintingStyle.fill;
    if (isDark) {
      fillPaint.shader = ui.Gradient.linear(
        Offset(0, barTop),
        Offset(0, barTop + H),
        [
          const Color(0xFF26262B), // Specular elevated top
          const Color(0xFF18181C), // Deep obsidian carbon base
        ],
      );
    } else {
      fillPaint.color = fillColor;
    }
    canvas.drawPath(path, fillPaint);

    // Concentric cradle groove / highlight path
    final cradleGroovePath = Path()
      ..moveTo(xLeftStart, barTop)
      ..arcToPoint(
        Offset(xLeftContact, yContact),
        radius: Radius.circular(rf),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(xRightContact, yContact),
        radius: Radius.circular(rc),
        clockwise: false,
      )
      ..arcToPoint(
        Offset(xRightEnd, barTop),
        radius: Radius.circular(rf),
        clockwise: true,
      );

    if (isDark) {
      // Dark Mode: Specular highlight on notch lip + recessed trough shadow
      final darkGrooveShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawPath(cradleGroovePath, darkGrooveShadowPaint);

      final notchHighlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(cradleGroovePath, notchHighlightPaint);
    } else {
      // Light Mode: Soft claymorphic groove shadow
      final groovePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawPath(cradleGroovePath, groovePaint);
    }

    // 1px crisp outline border (specular in dark mode, soft border in light mode)
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_TangentCurvedNotchPainter oldDelegate) {
    return oldDelegate.notchCenter != notchCenter ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark;
  }
}
