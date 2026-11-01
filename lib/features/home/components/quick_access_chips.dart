import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Action descriptor for the Quick Access bar.
class QuickActionItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const QuickActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// M3 Quick Access Chips
/// A horizontally scrolling ribbon of Material 3 [ActionChip] components
/// designed for fast, one-tap member workflows.
///
/// Material 3 Design Choices:
/// - Built using canonical [ActionChip] components styled with [ColorScheme.surfaceContainerHighest]
///   and [ColorScheme.outlineVariant].
/// - Text strictly adheres to [TextTheme.labelMedium] for ergonomic chip typography.
/// - Tactile engagement is enforced via [HapticFeedback.lightImpact] on every chip tap.
/// - Edge-to-edge scroll view with horizontal padding preserves the M3 20dp margin gutter.
class QuickAccessChips extends StatelessWidget {
  final VoidCallback? onLogWater;
  final VoidCallback? onBookPT;
  final VoidCallback? onClassSchedule;
  final VoidCallback? onLogMeal;

  const QuickAccessChips({
    super.key,
    this.onLogWater,
    this.onBookPT,
    this.onClassSchedule,
    this.onLogMeal,
  });

  List<QuickActionItem> _getActions() {
    return [
      if (onClassSchedule != null)
        QuickActionItem(
          id: 'classes',
          label: 'Classes',
          icon: Icons.calendar_today_rounded,
          onTap: onClassSchedule!,
        ),
      if (onBookPT != null)
        QuickActionItem(
          id: 'book_pt',
          label: 'Book Coach',
          icon: Icons.person_search_rounded,
          onTap: onBookPT!,
        ),
      if (onLogWater != null)
        QuickActionItem(
          id: 'log_water',
          label: 'Log Water',
          icon: Icons.water_drop_rounded,
          onTap: onLogWater!,
        ),
      if (onLogMeal != null)
        QuickActionItem(
          id: 'log_meal',
          label: 'Log Meal',
          icon: Icons.restaurant_rounded,
          onTap: onLogMeal!,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final actions = _getActions();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: actions.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: Icon(
                item.icon,
                size: 18,
                color: colorScheme.primary,
              ),
              label: Text(
                item.label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pressElevation: 1,
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              onPressed: () {
                HapticFeedback.lightImpact();
                item.onTap();
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
