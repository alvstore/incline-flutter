import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bento_card.dart';

/// Expandable and Interactive Meal Bento Card
class MealCard extends StatefulWidget {
  final DietMeal meal;
  final int index;
  final Function(bool isCompleted) onToggleCompleted;

  const MealCard({
    super.key,
    required this.meal,
    required this.index,
    required this.onToggleCompleted,
  });

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final isDone = meal.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        border: isDone
            ? Border.all(color: AppTheme.emerald.withValues(alpha: 0.35), width: 1.5)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkmark + Meal Info + Expand Icon
            Row(
              children: [
                // Interactive Checkmark
                InkWell(
                  onTap: () => widget.onToggleCompleted(!isDone),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.emerald.withValues(alpha: 0.18)
                          : context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDone
                            ? AppTheme.emerald
                            : context.borderCol,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isDone ? AppTheme.emerald : context.textMuted,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Title & Time & Dynamic Slot Label
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slot Label Pill + Time + Logged Badge
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? AppTheme.emerald.withValues(alpha: 0.15)
                                    : context.brandAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isDone
                                      ? AppTheme.emerald.withValues(alpha: 0.3)
                                      : context.brandAccent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                meal.displaySlotLabel.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDone ? AppTheme.emerald : context.brandAccent,
                                ),
                              ),
                            ),
                            Text(
                              meal.time,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                            if (isDone)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'LOGGED',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.emerald,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                meal.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDone ? context.textMuted : context.textPrimary,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Quick Macro Pill
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${meal.targetCalories} kcal',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'P ${meal.targetProtein.toInt()}g • C ${meal.targetCarbs.toInt()}g • F ${meal.targetFats.toInt()}g',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.brandAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // Expanded Portion & Ingredients
            if (_isExpanded) ...[
              const SizedBox(height: 14),
              Divider(color: context.borderCol, height: 1),
              const SizedBox(height: 12),

              Text(
                'CURATED NUTRITIONAL ITEMS & PORTIONS',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: context.textMuted,
                ),
              ),

              const SizedBox(height: 8),

              // Itemized Food rows
              ...meal.items.map((item) => _buildFoodItemRow(context, item)),

              // Meal-level Micronutrient & Electrolyte breakdown
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, size: 14, color: AppTheme.emerald),
                            const SizedBox(width: 6),
                            Text(
                              'MICROS IN THIS MEAL',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Clinical Density',
                          style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMicroBadge(context, 'Fiber', '${meal.totalMicros.fiber.toStringAsFixed(1)}g', AppTheme.emerald),
                        _buildMicroBadge(context, 'Potassium', '${meal.totalMicros.potassium.toInt()}mg', InclineColors.accentOrange),
                        _buildMicroBadge(context, 'Magnesium', '${meal.totalMicros.magnesium.toInt()}mg', AppTheme.gold),
                        _buildMicroBadge(context, 'Sodium', '${meal.totalMicros.sodium.toInt()}mg', AppTheme.amber),
                        if (meal.totalMicros.zinc > 0)
                          _buildMicroBadge(context, 'Zinc', '${meal.totalMicros.zinc.toStringAsFixed(1)}mg', InclineColors.thermalAmber),
                        if (meal.totalMicros.iron > 0)
                          _buildMicroBadge(context, 'Iron', '${meal.totalMicros.iron.toStringAsFixed(1)}mg', InclineColors.thermalRed),
                      ],
                    ),
                  ],
                ),
              ),

              if (meal.prepTips != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.brandAccent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 14, color: context.brandAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meal.prepTips!,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: context.brandAccent.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(
                      isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: isDone ? context.textMuted : AppTheme.emerald,
                    ),
                    label: Text(
                      isDone ? 'Undo Consumption' : 'Mark Meal Consumed',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDone ? context.textMuted : AppTheme.emerald,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDone
                            ? context.borderCol
                            : AppTheme.emerald.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => widget.onToggleCompleted(!isDone),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItemRow(BuildContext context, MealFoodItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.cardElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.borderCol),
                ),
                child: Text(
                  item.quantity,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.brandAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                '${item.calories} kcal',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary),
              ),
              Text(
                '• P: ${item.protein.toInt()}g',
                style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent),
              ),
              Text(
                '• C: ${item.carbs.toInt()}g',
                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.amber),
              ),
              Text(
                '• F: ${item.fats.toInt()}g',
                style: GoogleFonts.outfit(fontSize: 11, color: InclineColors.accentOrange),
              ),
              if (item.fiber != null && item.fiber! > 0)
                Text(
                  '• Fib: ${item.fiber!.toStringAsFixed(1)}g',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.emerald),
                ),
            ],
          ),
          if (item.alternative != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 12, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Swap option: ${item.alternative!}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: context.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicroBadge(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
