import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Bento Card Component inspired by Best-Flutter-UI-Templates
/// Supports standard rounded corners, asymmetrical signature curve,
/// gradients, and interactive tap states with ripple effects.
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final double elevation;
  final bool asymmetricCorners;
  final double? width;
  final double? height;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.elevation = 0,
    this.asymmetricCorners = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Signature asymmetric pattern from Best-Flutter-UI-Templates fitness app:
    // 3 corners at 16.0, top-right at 48.0 for dynamic modern fitness look.
    final borderRadius = asymmetricCorners
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
            topRight: Radius.circular(48),
          )
        : BorderRadius.circular(20);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppTheme.surfaceElevated : AppTheme.lightSurface;
    final resolvedBg = (backgroundColor == AppTheme.surfaceElevated || backgroundColor == AppTheme.surface)
        ? defaultBg
        : (backgroundColor ?? defaultBg);

    final resolvedBorder = border ?? Border.all(
      color: isDark ? AppTheme.border : AppTheme.lightBorder,
      width: 1,
    );

    final cardWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null ? resolvedBg : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: resolvedBorder,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation * 1.5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          splashColor: context.brandAccent.withValues(alpha: 0.12),
          highlightColor: context.brandAccent.withValues(alpha: 0.05),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return cardWidget;

    return InclineScaleButton(
      onTap: onTap,
      pressedScale: 0.985,
      child: cardWidget,
    );
  }
}

/// Bento Header Widget with icon, eyebrow, and optional trailing badge/action
class BentoHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  const BentoHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.brandAccent;

    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: effectiveIconColor,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
