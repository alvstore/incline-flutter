import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
/// 2026 World-Class Weekly Training Momentum & Habit Consistency Card
/// Interactive 7-day routine tracker and recovery suite reservation.
/// Built with Dart 3 Pattern Matching & Responsive LayoutBuilder.
class WeeklyMomentumCard extends StatelessWidget {
  final MemberAttendanceAnalysis? attendanceAnalysis;
  final VoidCallback onReserveSuiteTap;

  const WeeklyMomentumCard({
    super.key,
    this.attendanceAnalysis,
    required this.onReserveSuiteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final analysis = attendanceAnalysis;
    final streakDays = analysis?.streakDays ?? 0;
    final isVisitedToday = analysis?.isVisitedToday ?? false;
    final weekActivity = analysis?.weekActivity ?? List.filled(7, false);
    final monthlyVisits = analysis?.monthlyVisits ?? 0;

    // Today's day of week (1 = Monday, 7 = Sunday)
    final todayWeekday = DateTime.now().weekday; // 1 to 7

    // Count visited days this week
    final visitedCount = weekActivity.where((visited) => visited).length;
    final weeklyConsistencyPct = ((visitedCount / 7) * 100).toInt();

    final cardBg = isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface;
    final borderColor = isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
    const accentGold = InclineColors.accentOrange;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Weekly Momentum Eyebrow & Live Consistency Streak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: InclineColors.accentOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: InclineColors.accentOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.show_chart_rounded,
                            size: 13,
                            color: InclineColors.accentOrange,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'WEEKLY MOMENTUM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: InclineColors.accentOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          streakDays > 0
                              ? '$streakDays Days Streak 🔥'
                              : 'Start Streak Today 🔥',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accentGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Training Frequency Headline & Consistency Ratio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVisitedToday
                              ? 'Today\'s Session Logged ✓'
                              : 'Floor Check-In Ready',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$visitedCount of 7 Days Active this week • $monthlyVisits monthly',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$weeklyConsistencyPct%',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: InclineColors.accentOrange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. 7-Day Interactive Visualizer Rail (Mon-Sun) using Dart 3 Pattern Matching
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNumber = index + 1; // 1 = Mon ... 7 = Sun
                  final isVisited = index < weekActivity.length && weekActivity[index];
                  final isToday = dayNumber == todayWeekday;
                  final isPast = dayNumber < todayWeekday;

                  // Dart 3 Exhaustive Pattern Matching on a 3-tuple record
                  final (icon, bgColor, iconColor, statusLabel) =
                      switch ((isVisited, isToday, isPast)) {
                    (true, true, _) => (
                        Icons.local_fire_department_rounded,
                        InclineColors.accentOrange.withValues(alpha: 0.22),
                        InclineColors.accentOrange,
                        'Today ✓'
                      ),
                    (true, false, _) => (
                        Icons.check_rounded,
                        InclineColors.accentOrange.withValues(alpha: 0.16),
                        InclineColors.accentOrange,
                        'Done'
                      ),
                    (false, true, _) => (
                        Icons.radio_button_checked_rounded,
                        accentGold.withValues(alpha: 0.2),
                        accentGold,
                        'Today'
                      ),
                    (false, false, true) => (
                        Icons.remove_rounded,
                        isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        isDark ? Colors.white38 : Colors.black38,
                        'Rest'
                      ),
                    (false, false, false) => (
                        Icons.circle_outlined,
                        isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        isDark ? Colors.white24 : Colors.black26,
                        'Upcoming'
                      ),
                  };

                  final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Tooltip(
                        message: '${dayLetters[index]} • $statusLabel',
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday
                                ? (isDark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed)
                                : (isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday
                                  ? (isVisited
                                      ? InclineColors.accentOrange
                                      : accentGold)
                                  : (isDark
                                      ? InclineColors.cardBorder
                                      : Colors.black.withValues(alpha: 0.05)),
                              width: isToday ? 1.4 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayLetters[index],
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isToday
                                      ? (isVisited
                                          ? InclineColors.accentOrange
                                          : accentGold)
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: bgColor,
                                ),
                                child: Icon(
                                  icon,
                                  size: 13,
                                  color: iconColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // 4. Quick Action Footer: Reserve Recovery Suite
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onReserveSuiteTap();
                  },
                  icon: const Icon(Icons.hot_tub_rounded, size: 16),
                  label: Text(
                    'Book Contrast Suite (Cold Plunge & Sauna)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: InclineColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
