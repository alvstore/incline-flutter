import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Dedicated Coach & PT Quota Tracker Card
/// Inspired by the "Savings goal" circular/linear progress card from Image 2
class CoachQuotaCard extends StatelessWidget {
  final String coachName;
  final String coachRole;
  final int completedSessions;
  final int totalSessions;
  final VoidCallback onScheduleTap;

  const CoachQuotaCard({
    super.key,
    this.coachName = 'Incline Personal Coach',
    this.coachRole = 'Head Strength & Biomechanics Specialist',
    this.completedSessions = 12,
    this.totalSessions = 16,
    required this.onScheduleTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = totalSessions > 0 ? (completedSessions / totalSessions) : 0.0;
    final percentage = (progress * 100).toInt();

    const activeColor = InclineColors.accentOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Coach Info Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withValues(alpha: 0.15),
                  border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'BG',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            coachName,
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: activeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coachRole,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$percentage%',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed,
              valueColor: const AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Quota Text & Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedSessions of $totalSessions PT Sessions Completed',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onScheduleTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: InclineColors.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: InclineColors.accentOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Schedule',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: activeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
