import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// High-performance Shimmer Skeleton Loading Widget
/// Uses single repeating animation controller isolated in a RepaintBoundary
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? InclineColors.cardSurface : InclineColors.lightCardRecessed;
    final highlightColor =
        isDark ? InclineColors.cardRecessed : InclineColors.lightCardSurface;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor,
                  highlightColor,
                  baseColor,
                ],
                stops: const [0.1, 0.5, 0.9],
                transform: _SlidingGradientTransform(slidePercent: _shimmerController.value),
              ).createShader(bounds);
            },
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Skeleton Bento Card placeholder
class ShimmerBentoCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerBentoCard({
    super.key,
    this.height = 110,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
        ),
      ),
    );
  }
}
