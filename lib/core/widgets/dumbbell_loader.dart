import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum DumbbellLoaderSize { sm, md, lg }

/// Ultra-Luxury Fitness Dumbbell Loader matching backend gym-loader.tsx
/// Features:
/// - Soft ambient pulsing primary halo
/// - Faint baseline ring
/// - Smooth spinning gradient arc
/// - Animated bouncing dumbbell glyph with plates & knurled barbell shaft
/// - Subtle breathing caption text
/// - Semantic tokens: automatically adapts to Light and Dark themes
class DumbbellLoader extends StatefulWidget {
  final String? text;
  final DumbbellLoaderSize size;
  final Color? color;

  const DumbbellLoader({
    super.key,
    this.text,
    this.size = DumbbellLoaderSize.md,
    this.color,
  });

  @override
  State<DumbbellLoader> createState() => _DumbbellLoaderState();
}

class _DumbbellLoaderState extends State<DumbbellLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _bounceController;
  late final AnimationController _pulseController;

  late final Animation<double> _bounceAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Continuous spinning arc
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 2. Dumbbell vertical bounce & rhythmic pump (cadence)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 3. Halo soft breath/pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.color ?? InclineColors.accentOrange;
    final ringColor =
        isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
    final textColor =
        isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary;

    final double ringSize = switch (widget.size) {
      DumbbellLoaderSize.sm => 56.0,
      DumbbellLoaderSize.md => 84.0,
      DumbbellLoaderSize.lg => 112.0,
    };

    final double dumbWidth = switch (widget.size) {
      DumbbellLoaderSize.sm => 24.0,
      DumbbellLoaderSize.md => 36.0,
      DumbbellLoaderSize.lg => 48.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Soft pulsing glow halo
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return Container(
                    width: ringSize * 0.9,
                    height: ringSize * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.20 * _pulseAnimation.value),
                          blurRadius: 24 * _pulseAnimation.value,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 2. Faint full baseline ring
              Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2.5),
                ),
              ),

              // 3. Spinning arc
              RotationTransition(
                turns: _spinController,
                child: CustomPaint(
                  size: Size(ringSize, ringSize),
                  painter: _SpinningArcPainter(color: primaryColor),
                ),
              ),

              // 4. Center bouncing dumbbell glyph
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnimation.value),
                    child: CustomPaint(
                      size: Size(dumbWidth, dumbWidth * 0.45),
                      painter: _DumbbellPainter(
                        primaryColor: primaryColor,
                        barColor: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Optional pulsing label
        if (widget.text != null && widget.text!.isNotEmpty) ...[
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Opacity(
                opacity: 0.70 + 0.30 * _pulseAnimation.value,
                child: Text(
                  widget.text!,
                  style: GoogleFonts.outfit(
                    fontSize: widget.size == DumbbellLoaderSize.sm ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: textColor,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Custom painter for the spinning gradient arc
class _SpinningArcPainter extends CustomPainter {
  final Color color;

  _SpinningArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 1.5,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.5),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(1.25),
      -math.pi / 2,
      math.pi * 1.3,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinningArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Custom painter for the dumbbell glyph matching backend gym-loader.tsx SVG
class _DumbbellPainter extends CustomPainter {
  final Color primaryColor;
  final Color barColor;

  _DumbbellPainter({required this.primaryColor, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final primaryPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final innerPlatePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    // Proportions matching:
    // Left outer plate: rect x: 4/72, y: 6/32, w: 8/72, h: 20/32
    // Left inner plate: rect x: 12/72, y: 10/32, w: 5/72, h: 12/32
    // Center bar:       rect x: 17/72, y: 13/32, w: 38/72, h: 6/32
    // Right inner plate: rect x: 55/72, y: 10/32, w: 5/72, h: 12/32
    // Right outer plate: rect x: 60/72, y: 6/32, w: 8/72, h: 20/32

    // 1. Center Bar
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (17 / 72), h * (13 / 32), w * (38 / 72), h * (6 / 32)),
      Radius.circular(h * 0.1),
    );
    canvas.drawRRect(barRect, barPaint);

    // 2. Left Outer Plate
    final leftOuter = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (4 / 72), h * (6 / 32), w * (8 / 72), h * (20 / 32)),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(leftOuter, primaryPaint);

    // 3. Left Inner Plate
    final leftInner = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (12 / 72), h * (10 / 32), w * (5 / 72), h * (12 / 32)),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(leftInner, innerPlatePaint);

    // 4. Right Inner Plate
    final rightInner = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (55 / 72), h * (10 / 32), w * (5 / 72), h * (12 / 32)),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(rightInner, innerPlatePaint);

    // 5. Right Outer Plate
    final rightOuter = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (60 / 72), h * (6 / 32), w * (8 / 72), h * (20 / 32)),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(rightOuter, primaryPaint);
  }

  @override
  bool shouldRepaint(covariant _DumbbellPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor || oldDelegate.barColor != barColor;
}
