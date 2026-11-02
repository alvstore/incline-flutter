import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/incline_colors.dart';

/// Branded welcome screen that continues into the real app authentication flow.
class InclineWelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const InclineWelcomeScreen({super.key, required this.onContinue});

  @override
  State<InclineWelcomeScreen> createState() => _InclineWelcomeScreenState();
}

class _InclineWelcomeScreenState extends State<InclineWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _trackController;

  @override
  void initState() {
    super.initState();
    _trackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
  }

  @override
  void dispose() {
    _trackController.dispose();
    super.dispose();
  }

  void _continueToLogin() {
    HapticFeedback.selectionClick();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InclineColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _trackController,
              builder: (context, child) => CustomPaint(
                painter: _InclineTrackPainter(progress: _trackController.value),
                child: child,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          _buildSplash(context),
        ],
      ),
    );
  }

  Widget _buildSplash(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isLandscape) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Column: Branding and Editorial Splitting Copy
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusPill(),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome to',
                          style: GoogleFonts.outfit(
                            color: InclineColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'INCLINE',
                          style: GoogleFonts.outfit(
                            color: InclineColors.textPrimary,
                            fontSize: 42,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'High-performance athletic programming, real-time 3D telemetry, and clinical biometrics engineered for club members.',
                          style: GoogleFonts.inter(
                            color: InclineColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 36),

                  // Right Column: Brand Motto and Call To Action
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rise. Reflect. Repeat.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: InclineColors.accentOrange,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildPrimaryAction(
                            label: 'Enter Club',
                            onPressed: _continueToLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Portrait Mode
          return Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Club Status Pill + Refined Brand Motto
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusPill(),
                    Text(
                      'Rise. Reflect. Repeat.',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: InclineColors.accentOrange,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 3),

                // 2. Main Title Hierarchy
                Text(
                  'Welcome to',
                  style: GoogleFonts.outfit(
                    color: InclineColors.textSecondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'INCLINE',
                  style: GoogleFonts.outfit(
                    color: InclineColors.textPrimary,
                    fontSize: 54,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Polished Periodized Athletic Splitting Description
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    'High-performance athletic programming, real-time 3D telemetry, and clinical biometrics engineered for club members.',
                    style: GoogleFonts.inter(
                      color: InclineColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Spacer(flex: 2),

                // 4. Premium High-End Action Button with Specular Glow & Smooth Border
                _buildPrimaryAction(
                  label: 'Enter Club',
                  onPressed: _continueToLogin,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: InclineColors.accentOrange,
            ),
          ),
          const SizedBox(width: 7.5),
          Text(
            'MEMBER ACCESS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: InclineColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF5722),
                  InclineColors.accentOrange,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(path, track);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final start = progress * metric.length;
    final segmentLength = metric.length * 0.16;
    final movingPaint = Paint()
      ..color = InclineColors.accentOrange.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
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
        Paint()..color = InclineColors.accentOrange.withValues(alpha: 0.24),
      );
      canvas.drawCircle(
        tangent.position,
        2,
        Paint()..color = InclineColors.accentOrange,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InclineTrackPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
