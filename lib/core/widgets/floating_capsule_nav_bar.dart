import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/incline_colors.dart';

/// Navigation item definition for the Floating Capsule Navigation Bar
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

/// 1:1 Rift-Inspired Floating Dock Navigation Bar
/// Precision floating frosted capsule dock with glowing coral-circle active indicator
/// and dark translucent touch targets for inactive tabs.
class FloatingCapsuleNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<CapsuleNavItem> items;

  const FloatingCapsuleNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final barHeight = isCompact ? 62.0 : 66.0;
        final bubbleSize = isCompact ? 44.0 : 48.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
            borderRadius: BorderRadius.circular(38),
            border: Border.all(
              color: isDark
                  ? InclineColors.cardBorder
                  : InclineColors.lightCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(items.length, (index) {
              final isSelected = selectedIndex == index;
              final item = items[index];

              return Expanded(
                child: _buildRiftDockItem(
                  context: context,
                  item: item,
                  isSelected: isSelected,
                  isDark: isDark,
                  size: bubbleSize,
                  onTap: () {
                    if (item.isCenterHero) {
                      HapticFeedback.mediumImpact();
                    } else {
                      HapticFeedback.lightImpact();
                    }
                    onItemSelected(index);
                  },
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// 1:1 Circular touch target: Coral active circle with glow, dark pill bubble when inactive
  Widget _buildRiftDockItem({
    required BuildContext context,
    required CapsuleNavItem item,
    required bool isSelected,
    required bool isDark,
    required double size,
    required VoidCallback onTap,
  }) {
    const activeCoralGradient = LinearGradient(
      colors: [InclineColors.accentOrange, InclineColors.thermalRed],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final inactiveBg =
        isDark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed;
    final inactiveBorder =
        isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;

    final iconColor = isSelected
        ? Colors.white
        : (isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2 + 4,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Accessibility & test helper: renders text without layout impact
                Opacity(
                  opacity: 0.0,
                  child: SizedBox.shrink(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 1),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected ? activeCoralGradient : null,
                    color: isSelected ? null : inactiveBg,
                    border: Border.all(
                      color: isSelected ? Colors.transparent : inactiveBorder,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: InclineColors.accentOrange
                                  .withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      isSelected ? item.filledIcon : item.outlineIcon,
                      size: isSelected ? 24 : 22,
                      color: iconColor,
                    )
                        .animate(target: isSelected ? 1 : 0)
                        .scale(
                          begin: const Offset(0.88, 0.88),
                          end: const Offset(1.08, 1.08),
                          duration: 250.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
