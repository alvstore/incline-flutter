import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/incline_colors.dart';

/// The low-contrast rising track from the saved splash concept, reused behind login.
class InclineMotionTrackBackground extends StatelessWidget {
  const InclineMotionTrackBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const CustomPaint(painter: _InclineTrackPainter(progress: 0.46));
    }

    return const SizedBox.expand()
        .animate(onPlay: (controller) => controller.repeat())
        .custom(
          duration: 5.seconds,
          builder: (context, value, child) => CustomPaint(
            painter: _InclineTrackPainter(progress: value),
            child: child,
          ),
        );
  }
}

class _InclineTrackPainter extends CustomPainter {
  final double progress;

  const _InclineTrackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.66, size.height * 0.92)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.67,
        size.width * 0.73,
        size.height * 0.43,
        size.width * 1.04,
        size.height * 0.12,
      );
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.055)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    final start = progress * metric.length;
    final segmentLength = metric.length * 0.16;
    final movingPaint = Paint()
      ..color = InclineColors.accentOrange.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    if (start + segmentLength <= metric.length) {
      canvas.drawPath(metric.extractPath(start, start + segmentLength), movingPaint);
    } else {
      canvas.drawPath(metric.extractPath(start, metric.length), movingPaint);
      canvas.drawPath(
        metric.extractPath(0, start + segmentLength - metric.length),
        movingPaint,
      );
    }

    final tangent = metric.getTangentForOffset(start % metric.length);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        4,
        Paint()..color = InclineColors.accentOrange.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        tangent.position,
        2,
        Paint()..color = InclineColors.accentOrange.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InclineTrackPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
