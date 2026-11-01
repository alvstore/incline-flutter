import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:incline_app/core/theme/incline_colors.dart';

/// Kinetic background paths inspired by Incline web brand visual panel
/// Renders upward ascending curved paths that gently shift/animate to convey
/// continuous ascension, performance, and momentum.
class FloatingPathsBackground extends StatefulWidget {
  final Widget? child;
  final Color? color;
  final double intensity;

  const FloatingPathsBackground({
    super.key,
    this.child,
    this.color,
    this.intensity = 1.0,
  });

  @override
  State<FloatingPathsBackground> createState() => _FloatingPathsBackgroundState();
}

class _FloatingPathsBackgroundState extends State<FloatingPathsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strokeColor = widget.color ?? InclineColors.accentOrange;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Kinetic SVG-like curved paths
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _PathsPainter(
                progress: _controller.value,
                color: strokeColor,
                intensity: widget.intensity,
                isDark: isDark,
              ),
            );
          },
        ),

        // Optional child content on top
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _PathsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double intensity;
  final bool isDark;

  _PathsPainter({
    required this.progress,
    required this.color,
    required this.intensity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final baseAlpha = isDark ? 0.07 : 0.05;
    const pathCount = 14;

    for (int i = 0; i < pathCount; i++) {
      final double offsetPhase = (progress + (i / pathCount)) % 1.0;
      final double dynamicOpacity = (baseAlpha + (i * 0.009)) * intensity;

      paint.color = color.withValues(alpha: dynamicOpacity.clamp(0.01, 0.35));
      paint.strokeWidth = 1.0 + (i * 0.12);

      final path = Path();
      // Wave parameters mimicking upward incline bezier curve
      final startY = size.height * (0.85 - (i * 0.045));
      final ctrlX1 = size.width * (0.25 + (0.1 * math.sin(offsetPhase * math.pi * 2)));
      final ctrlY1 = size.height * (0.65 - (i * 0.04));
      final ctrlX2 = size.width * (0.75 - (0.1 * math.cos(offsetPhase * math.pi * 2)));
      final ctrlY2 = size.height * (0.35 - (i * 0.035));
      final endX = size.width;
      final endY = size.height * (0.15 - (i * 0.03));

      path.moveTo(-40, startY);
      path.cubicTo(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX + 40, endY);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity;
}
