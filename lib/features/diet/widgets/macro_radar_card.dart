import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bento_card.dart';

/// Interactive Bento Card displaying Daily Calorie, Macronutrient & Micronutrient Progress
class MacroRadarCard extends StatefulWidget {
  final DietDayPlan dayPlan;

  const MacroRadarCard({
    super.key,
    required this.dayPlan,
  });

  @override
  State<MacroRadarCard> createState() => _MacroRadarCardState();
}

class _MacroRadarCardState extends State<MacroRadarCard> {
  int _activeRadarTab = 0; // 0: Macros, 1: Clinical Micros

  @override
  Widget build(BuildContext context) {
    final dayPlan = widget.dayPlan;
    final targetCals = dayPlan.targetCalories;
    final consumedCals = dayPlan.consumedCalories;
    final remainingCals = (targetCals - consumedCals).clamp(0, targetCals);
    final calProgress = targetCals > 0 ? (consumedCals / targetCals).clamp(0.0, 1.0) : 0.0;

    final targetProt = dayPlan.targetProtein;
    final consumedProt = dayPlan.consumedProtein;
    final protProgress = targetProt > 0 ? (consumedProt / targetProt).clamp(0.0, 1.0) : 0.0;

    final targetCarb = dayPlan.targetCarbs;
    final consumedCarb = dayPlan.consumedCarbs;
    final carbProgress = targetCarb > 0 ? (consumedCarb / targetCarb).clamp(0.0, 1.0) : 0.0;

    final targetFat = dayPlan.targetFats;
    final consumedFat = dayPlan.consumedFats;
    final fatProgress = targetFat > 0 ? (consumedFat / targetFat).clamp(0.0, 1.0) : 0.0;

    final targetMicros = dayPlan.effectiveTargetMicros;
    final consumedMicros = dayPlan.consumedMicros;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Segmented Mode Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.gold),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'DAILY MACRONUTRIENTS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: context.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: calProgress >= 1.0
                      ? AppTheme.emerald.withValues(alpha: 0.15)
                      : context.cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: calProgress >= 1.0
                        ? AppTheme.emerald.withValues(alpha: 0.4)
                        : context.borderCol,
                  ),
                ),
                child: Text(
                  calProgress >= 1.0 ? 'GOAL HIT' : '${(calProgress * 100).toInt()}% CONSUMED',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: calProgress >= 1.0 ? AppTheme.emerald : AppTheme.gold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Segmented Switch: [ Macros (Calories/Protein/Carbs/Fat) ] | [ Micros & Electrolytes ]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderCol),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeRadarTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeRadarTab == 0 ? context.brandAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 13,
                                color: _activeRadarTab == 0 ? context.onBrandAccent : context.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Macros & Calories',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _activeRadarTab == 0 ? context.onBrandAccent : context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeRadarTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _activeRadarTab == 1 ? context.brandAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 13,
                                color: _activeRadarTab == 1 ? context.onBrandAccent : context.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Micros & Electrolytes',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _activeRadarTab == 1 ? context.onBrandAccent : context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_activeRadarTab == 0) ...[
            // Calorie Hub Row
            Row(
              children: [
                // Radial Progress
                RepaintBoundary(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: calProgress,
                          strokeWidth: 8,
                          backgroundColor: context.cardBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            calProgress >= 1.0 ? AppTheme.emerald : AppTheme.gold,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$consumedCals',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                'kcal',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Calorie breakdown summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remainingCals kcal remaining',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Daily Target: $targetCals kcal • Clean Burn Split',
                        style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildMacroChip('P: ${consumedProt.toInt()}/${targetProt.toInt()}g', AppTheme.gold),
                          _buildMacroChip('C: ${consumedCarb.toInt()}/${targetCarb.toInt()}g', AppTheme.amber),
                          _buildMacroChip('F: ${consumedFat.toInt()}/${targetFat.toInt()}g', InclineColors.accentOrange),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3-Macro Ring Distribution
            Row(
              children: [
                _buildCircularMacroTile(
                  context: context,
                  label: 'Protein',
                  consumed: consumedProt,
                  target: targetProt,
                  progress: protProgress,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 8),
                _buildCircularMacroTile(
                  context: context,
                  label: 'Carbs',
                  consumed: consumedCarb,
                  target: targetCarb,
                  progress: carbProgress,
                  color: InclineColors.accentOrange,
                ),
                const SizedBox(width: 8),
                _buildCircularMacroTile(
                  context: context,
                  label: 'Fats',
                  consumed: consumedFat,
                  target: targetFat,
                  progress: fatProgress,
                  color: AppTheme.gold,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Detailed Macro Progress Bars
            _buildMacroBar(
              context: context,
              label: 'PROTEIN',
              consumed: consumedProt,
              target: targetProt,
              progress: protProgress,
              color: AppTheme.gold,
              subtitle: 'Target: 2.2g / kg lean body mass',
            ),
            const SizedBox(height: 10),
            _buildMacroBar(
              context: context,
              label: 'CARBOHYDRATES',
              consumed: consumedCarb,
              target: targetCarb,
              progress: carbProgress,
              color: AppTheme.amber,
              subtitle: 'Complex glycogen fueling',
            ),
            const SizedBox(height: 10),
            _buildMacroBar(
              context: context,
              label: 'HEALTHY FATS',
              consumed: consumedFat,
              target: targetFat,
              progress: fatProgress,
              color: InclineColors.accentOrange,
              subtitle: 'Endocrine & cellular recovery',
            ),

            const SizedBox(height: 16),

            // Quick Micro Snapshot Banner at bottom of Macros tab
            InkWell(
              onTap: () => setState(() => _activeRadarTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.brandAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, size: 16, color: context.brandAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Micronutrients: Fiber ${consumedMicros.fiber.toInt()}g • Potassium ${consumedMicros.potassium.toInt()}mg • Mg ${consumedMicros.magnesium.toInt()}mg',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'View All ›',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.brandAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // CLINICAL MICRONUTRIENTS & ELECTROLYTES TAB
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLINICAL ELECTROLYTES & MICRONUTRIENTS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Cellular Hydration & Neuromuscular Recovery',
                        style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'ATHLETIC RDA',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emerald,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Real Dietary Fiber (always tracked from authentic food items)
            _buildMicroProgressRow(
              context: context,
              name: 'Dietary Fiber',
              consumed: consumedMicros.fiber,
              target: targetMicros.fiber > 0 ? targetMicros.fiber : 38.0,
              unit: 'g',
              color: AppTheme.emerald,
              role: 'Microbiome health & glycemic stability',
            ),

            const SizedBox(height: 12),

            if (dayPlan.targetMicros != null || consumedMicros.potassium > 0 || consumedMicros.sodium > 0) ...[
              // Section 1: Hydration & Essential Electrolytes
              Text(
                'HYDRATION & MUSCLE CONTRACTION ELECTROLYTES',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: context.brandAccent,
                ),
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Potassium (K)',
                consumed: consumedMicros.potassium,
                target: targetMicros.potassium,
                unit: 'mg',
                color: InclineColors.accentOrange,
                role: 'Intracellular hydration & anti-cramp',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Sodium (Na)',
                consumed: consumedMicros.sodium,
                target: targetMicros.sodium,
                unit: 'mg',
                color: AppTheme.amber,
                role: 'Blood volume & athletic sweat balance',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Magnesium (Mg)',
                consumed: consumedMicros.magnesium,
                target: targetMicros.magnesium,
                unit: 'mg',
                color: AppTheme.emerald,
                role: 'ATP muscle relaxation & sleep recovery',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Calcium (Ca)',
                consumed: consumedMicros.calcium,
                target: targetMicros.calcium,
                unit: 'mg',
                color: AppTheme.gold,
                role: 'Bone density & muscle contraction signaling',
              ),

              const SizedBox(height: 16),

              // Section 2: Clinical Vitamins & Minerals
              Text(
                'ESSENTIAL VITAMINS & MINERALS',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: context.brandAccent,
                ),
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Zinc (Zn)',
                consumed: consumedMicros.zinc,
                target: targetMicros.zinc,
                unit: 'mg',
                color: InclineColors.thermalAmber,
                role: 'Testosterone support & tissue repair',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Iron (Fe)',
                consumed: consumedMicros.iron,
                target: targetMicros.iron,
                unit: 'mg',
                color: InclineColors.thermalRed,
                role: 'Hemoglobin & VO2 max oxygen transport',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Vitamin D3',
                consumed: consumedMicros.vitaminD,
                target: targetMicros.vitaminD,
                unit: 'IU',
                color: AppTheme.gold,
                role: 'Immune defense & bone calcium uptake',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Vitamin C',
                consumed: consumedMicros.vitaminC,
                target: targetMicros.vitaminC,
                unit: 'mg',
                color: AppTheme.amber,
                role: 'Collagen synthesis & tendon resilience',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Vitamin B12',
                consumed: consumedMicros.vitaminB12,
                target: targetMicros.vitaminB12,
                unit: 'mcg',
                color: InclineColors.accentOrange,
                role: 'Cellular energy metabolism & nerve health',
              ),
              const SizedBox(height: 8),

              _buildMicroProgressRow(
                context: context,
                name: 'Omega-3 EPA/DHA',
                consumed: consumedMicros.omega3,
                target: targetMicros.omega3,
                unit: 'mg',
                color: AppTheme.emerald,
                role: 'Joint lubrication & systemic anti-inflammation',
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.brandAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.biotech_rounded, size: 20, color: context.brandAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical Micronutrient Panel',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Specific electrolyte & vitamin targets are configured via clinical lab reports. Macronutrients & Dietary Fiber above are 100% verified from your assigned plan.',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: context.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCircularMacroTile({
    required BuildContext context,
    required String label,
    required double consumed,
    required double target,
    required double progress,
    required Color color,
  }) {
    final pct = (progress * 100).toInt();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderCol),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: context.borderCol.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '$pct%',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${consumed.toInt()}g / ${target.toInt()}g',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMacroBar({
    required BuildContext context,
    required String label,
    required double consumed,
    required double target,
    required double progress,
    required Color color,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '• $subtitle',
                      style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${consumed.toInt()}g / ${target.toInt()}g',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: context.cardBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMicroProgressRow({
    required BuildContext context,
    required String name,
    required double consumed,
    required double target,
    required String unit,
    required Color color,
    required String role,
  }) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();

    final statusText = pct >= 95
        ? 'Optimal'
        : (pct >= 60 ? 'In Range' : 'Target Deficit');
    final statusColor = pct >= 95
        ? AppTheme.emerald
        : (pct >= 60 ? AppTheme.gold : InclineColors.accentOrange);

    final consumedDisplay = unit == 'mcg'
        ? consumed.toStringAsFixed(1)
        : (unit == 'mg' && target < 30 ? consumed.toStringAsFixed(1) : consumed.toInt().toString());
    final targetDisplay = unit == 'mcg'
        ? target.toStringAsFixed(1)
        : (unit == 'mg' && target < 30 ? target.toStringAsFixed(1) : target.toInt().toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              Expanded(
                child: Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '• $role',
                        style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.cardElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$consumedDisplay / $targetDisplay $unit ($pct%)',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
