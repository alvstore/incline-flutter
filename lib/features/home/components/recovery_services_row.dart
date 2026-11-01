import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/incline_colors.dart';

/// Quick Recovery Services & Amenities Row
/// Inspired by the "Pay bills" quick service tiles from Image 2
class RecoveryServicesRow extends StatelessWidget {
  final VoidCallback onColdPlungeTap;
  final VoidCallback onSaunaTap;
  final VoidCallback onNutritionTap;
  final VoidCallback onInBodyTap;
  final VoidCallback onSeeAllTap;

  const RecoveryServicesRow({
    super.key,
    required this.onColdPlungeTap,
    required this.onSaunaTap,
    required this.onNutritionTap,
    required this.onInBodyTap,
    required this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final services = [
      _ServiceItem(
        title: 'Cold Plunge',
        icon: Icons.ac_unit_rounded,
        lightBg: InclineColors.lightCardSurface,
        darkBg: InclineColors.cardSurface,
        iconColor: InclineColors.accentOrange,
        onTap: onColdPlungeTap,
      ),
      _ServiceItem(
        title: 'Sauna',
        icon: Icons.hot_tub_rounded,
        lightBg: InclineColors.lightCardSurface,
        darkBg: InclineColors.cardSurface,
        iconColor: InclineColors.thermalAmber,
        onTap: onSaunaTap,
      ),
      _ServiceItem(
        title: 'Fuel Bar',
        icon: Icons.local_cafe_rounded,
        lightBg: InclineColors.lightCardSurface,
        darkBg: InclineColors.cardSurface,
        iconColor: InclineColors.accentOrange,
        onTap: onNutritionTap,
      ),
      _ServiceItem(
        title: '3D Scan',
        icon: Icons.view_in_ar_rounded,
        lightBg: InclineColors.lightCardSurface,
        darkBg: InclineColors.cardSurface,
        iconColor: InclineColors.thermalRed,
        onTap: onInBodyTap,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECOVERY SUITE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: InclineColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSeeAllTap();
                },
                child: Text(
                  'Bookings',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: InclineColors.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Service Tiles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: services.map((s) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  s.onTap();
                },
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isDark ? s.darkBg : s.lightBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? s.iconColor.withValues(alpha: 0.25)
                                : InclineColors.lightCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(s.icon, size: 26, color: s.iconColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final String title;
  final IconData icon;
  final Color lightBg;
  final Color darkBg;
  final Color iconColor;
  final VoidCallback onTap;

  _ServiceItem({
    required this.title,
    required this.icon,
    required this.lightBg,
    required this.darkBg,
    required this.iconColor,
    required this.onTap,
  });
}
