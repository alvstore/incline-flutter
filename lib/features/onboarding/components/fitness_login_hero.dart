import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/incline_colors.dart';

/// A small, decorative lifting scene for the fitness-led login concept.
class FitnessLoginHero extends StatelessWidget {
  const FitnessLoginHero({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final barbell = RepaintBoundary(
      child: ExcludeSemantics(
        child: const SizedBox(
          width: 190,
          height: 126,
          child: CustomPaint(painter: _FitnessBarbellPainter()),
        ),
      ),
    );
    final movingBarbell = reduceMotion
        ? barbell
        : barbell
            .animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            )
            .moveY(
              begin: 3,
              end: -3,
              duration: 1800.ms,
              curve: Curves.easeInOutSine,
            );

    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [InclineColors.cardSurface, InclineColors.bgPrimary],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _FitnessHeroBackdropPainter()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoWidth = (constraints.maxWidth * 0.40)
                      .clamp(100.0, 138.0)
                      .toDouble();
                  Widget logo = Semantics(
                    image: true,
                    label: 'Incline — Rise. Reflect. Repeat.',
                    child: Image.asset(
                      'assets/images/incline_brand_logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                    ),
                  );
                  if (!reduceMotion) {
                    logo = logo
                        .animate()
                        .fadeIn(duration: 560.ms)
                        .slideX(
                          begin: -0.08,
                          end: 0,
                          duration: 560.ms,
                          curve: Curves.easeOutCubic,
                        );
                  }

                  return Row(
                    children: [
                      SizedBox(width: logoWidth, child: logo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: movingBarbell,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return hero;
  }
}

class _FitnessHeroBackdropPainter extends CustomPainter {
  const _FitnessHeroBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.58);
    final spotlight = Paint()
      ..shader = RadialGradient(
        colors: [
          InclineColors.accentOrange.withValues(alpha: 0.22),
          InclineColors.accentOrange.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.62),
      );
    canvas.drawCircle(center, size.width * 0.62, spotlight);
  }

  @override
  bool shouldRepaint(covariant _FitnessHeroBackdropPainter oldDelegate) => false;
}

class _FitnessBarbellPainter extends CustomPainter {
  const _FitnessBarbellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.min(size.width / 224, size.height / 112).toDouble();
    canvas.save();
    canvas.translate(
      (size.width - 224 * scale) / 2,
      (size.height - 112 * scale) / 2,
    );
    canvas.scale(scale);

    final center = const Offset(224 * 0.56, 112 * 0.58);
    final glow = Paint()
      ..color = InclineColors.accentOrange.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, 224 * 0.27, glow);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final shaft = Paint()
      ..color = Colors.white70
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-92, 0), const Offset(92, 0), shaft);

    for (final side in const [-1.0, 1.0]) {
      final platePaint = Paint()..color = InclineColors.cardRecessed;
      final plateEdge = Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final inner = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(side * 65, 0),
          width: 18,
          height: 52,
        ),
        const Radius.circular(5),
      );
      final outer = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(side * 81, 0),
          width: 22,
          height: 68,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(inner, platePaint);
      canvas.drawRRect(inner, plateEdge);
      canvas.drawRRect(outer, platePaint);
      canvas.drawRRect(outer, plateEdge);
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FitnessBarbellPainter oldDelegate) => false;
}
