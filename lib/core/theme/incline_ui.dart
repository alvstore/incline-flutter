import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Centralized Reusable Incline UI Design System Components
/// Use these shared widgets across all screens for 100% color & visual consistency.

/// 0. Universal Tactile Animated Scale Wrapper
/// Applies restrained scale micro-interaction (0.975x) with subtle haptic feedback.
class InclineScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const InclineScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.duration = const Duration(milliseconds: 90),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<InclineScaleButton> createState() => _InclineScaleButtonState();
}

class _InclineScaleButtonState extends State<InclineScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 1. Universal Primary Action Button with Tactile Animation
/// Adapts automatically to Light Mode (Forest Green + White) and Dark Mode (Gold + Black).
class InclinePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;

  const InclinePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.width,
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 12,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.brandAccent;
    final fg = foregroundColor ?? context.onBrandAccent;

    return InclineScaleButton(
      onTap: isLoading ? null : onPressed,
      child: SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.5),
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            elevation: 0,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Row(
                  mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, size: fontSize + 4, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        letterSpacing: 0.3,
                        color: fg,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// 2. Universal Outlined Secondary Button with Tactile Animation
class InclineSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool isLoading;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? textColor;
  final double borderRadius;
  final double fontSize;

  const InclineSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.isLoading = false,
    this.width,
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.borderColor,
    this.textColor,
    this.borderRadius = 12,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final strokeColor = borderColor ?? context.brandAccent.withValues(alpha: 0.5);
    final fg = textColor ?? context.brandAccent;

    return InclineScaleButton(
      onTap: isLoading ? null : onPressed,
      child: SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: strokeColor, width: 1.2),
            elevation: 0,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Row(
                  mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, size: fontSize + 4, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 2.5 Animated Tactile Icon Button
class InclineIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final Border? border;
  final double borderRadius;

  const InclineIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.iconColor,
    this.size = 44,
    this.iconSize = 20,
    this.border,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.cardElevated;
    final fg = iconColor ?? context.brandAccent;
    final bd = border ?? Border.all(color: context.borderCol, width: 1);

    Widget button = InclineScaleButton(
      onTap: onPressed,
      pressedScale: 0.92,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: bd,
        ),
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: button,
    );
  }
}


/// 3. Universal Filter & Category Chip
class InclineFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final Widget? trailing;

  const InclineFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onSelected,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = context.brandAccent;
    const activeFg = Colors.white;
    final inactiveBg = context.cardElevated;
    final inactiveFg = context.textPrimary;

    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,
      avatar: icon != null
          ? Icon(
              icon,
              size: 15,
              color: isSelected ? activeFg : context.brandAccent,
            )
          : null,
      label: Text(label),
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? activeFg : inactiveFg,
      ),
      backgroundColor: inactiveBg,
      selectedColor: activeBg,
      side: BorderSide(
        color: isSelected ? activeBg : context.borderCol,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      showCheckmark: false,
    );
  }
}

/// 4. Universal Incline Badge
enum InclineBadgeVariant { accent, emerald, rose, amber, sky, neutral }

class InclineBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final InclineBadgeVariant variant;
  final bool filled;
  final double fontSize;

  const InclineBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = InclineBadgeVariant.accent,
    this.filled = false,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    switch (variant) {
      case InclineBadgeVariant.accent:
        baseColor = context.brandAccent;
        break;
      case InclineBadgeVariant.emerald:
        baseColor = AppTheme.emerald;
        break;
      case InclineBadgeVariant.rose:
        baseColor = AppTheme.rose;
        break;
      case InclineBadgeVariant.amber:
        baseColor = AppTheme.amber;
        break;
      case InclineBadgeVariant.sky:
        baseColor = AppTheme.sky;
        break;
      case InclineBadgeVariant.neutral:
        baseColor = context.textSecondary;
        break;
    }

    final bg = filled ? baseColor : baseColor.withValues(alpha: 0.12);
    final fg = filled ? Colors.white : baseColor;
    final border = filled ? Colors.transparent : baseColor.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Universal Luxury Incline Card
class InclineCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final double? width;
  final double? height;

  const InclineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.backgroundColor,
    this.border,
    this.borderRadius = 20,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.cardBg;
    final bd = border ?? Border.all(color: context.borderCol, width: 1);

    final cardWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: bd,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: context.brandAccent.withValues(alpha: 0.1),
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
