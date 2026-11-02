import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/watch_sync_service.dart';
import '../../../core/theme/incline_colors.dart';

/// Data model representing daily activity metrics for the Activity Bento Grid.
class DailyActivityMetrics {
  final int activeCalories;
  final int targetCalories;
  final int workoutMinutes;
  final int targetMinutes;
  final int heartRateBpm;
  final String heartRateZone;
  final int stepCount;
  final int targetSteps;
  final double sleepHours;
  final double targetSleepHours;
  final bool hasSyncedToday;
  final bool isConnected;
  final bool isManualSleep;
  final DateTime? heartRateRecordedAt;
  final double heartRateVariabilityMs;
  final DateTime? heartRateVariabilityRecordedAt;

  const DailyActivityMetrics({
    this.activeCalories = -1,
    this.targetCalories = 750,
    this.workoutMinutes = -1,
    this.targetMinutes = 60,
    this.heartRateBpm = -1,
    this.heartRateZone = 'Sensor Disconnected',
    this.stepCount = -1,
    this.targetSteps = 10000,
    this.sleepHours = 0.0,
    this.targetSleepHours = 8.0,
    this.hasSyncedToday = false,
    this.isConnected = false,
    this.isManualSleep = false,
    this.heartRateRecordedAt,
    this.heartRateVariabilityMs = -1,
    this.heartRateVariabilityRecordedAt,
  });

  DailyActivityMetrics copyWith({
    int? activeCalories,
    int? targetCalories,
    int? workoutMinutes,
    int? targetMinutes,
    int? heartRateBpm,
    String? heartRateZone,
    int? stepCount,
    int? targetSteps,
    double? sleepHours,
    double? targetSleepHours,
    bool? hasSyncedToday,
    bool? isConnected,
    bool? isManualSleep,
    DateTime? heartRateRecordedAt,
    double? heartRateVariabilityMs,
    DateTime? heartRateVariabilityRecordedAt,
  }) {
    return DailyActivityMetrics(
      activeCalories: activeCalories ?? this.activeCalories,
      targetCalories: targetCalories ?? this.targetCalories,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      heartRateZone: heartRateZone ?? this.heartRateZone,
      stepCount: stepCount ?? this.stepCount,
      targetSteps: targetSteps ?? this.targetSteps,
      sleepHours: sleepHours ?? this.sleepHours,
      targetSleepHours: targetSleepHours ?? this.targetSleepHours,
      hasSyncedToday: hasSyncedToday ?? this.hasSyncedToday,
      isConnected: isConnected ?? this.isConnected,
      isManualSleep: isManualSleep ?? this.isManualSleep,
      heartRateRecordedAt: heartRateRecordedAt ?? this.heartRateRecordedAt,
      heartRateVariabilityMs: heartRateVariabilityMs ?? this.heartRateVariabilityMs,
      heartRateVariabilityRecordedAt: heartRateVariabilityRecordedAt ?? this.heartRateVariabilityRecordedAt,
    );
  }
}

/// M3 Activity Bento Grid
/// Renders an expressive 2x2 Bento grid with Heart Rate ticker & Goal Customization
class ActivityBentoGrid extends StatelessWidget {
  final DailyActivityMetrics metrics;
  final void Function(String metricKey)? onMetricTap;
  final VoidCallback? onSetGoalsTap;
  final VoidCallback? onSyncTap;
  final bool isSyncing;
  final bool showSyncInHeader;

  const ActivityBentoGrid({
    super.key,
    required this.metrics,
    this.onMetricTap,
    this.onSetGoalsTap,
    this.onSyncTap,
    this.isSyncing = false,
    this.showSyncInHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hrvMetricName = WatchSyncService.instance.heartRateVariabilityMetricName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Telemetry Action Controls Bar (Set Goals & Sync)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Heart Rate / Sensor Status Pill
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onMetricTap?.call('heart_rate');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (metrics.heartRateBpm > 0)
                            ? InclineColors.thermalRed
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      metrics.heartRateBpm > 0
                          ? '${metrics.heartRateBpm} BPM'
                          : '-- BPM',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      metrics.heartRateBpm > 0
                          ? '• Last read ${metrics.heartRateRecordedAt == null ? "recently" : DateFormat("h:mm a").format(metrics.heartRateRecordedAt!.toLocal())}'
                          : '• No recent reading',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Action Controls: Set Goals & Sync
            Row(
              children: [
                if (onSetGoalsTap != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSetGoalsTap!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.track_changes_rounded, size: 14, color: InclineColors.accentOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Targets',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (showSyncInHeader && onSyncTap != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isSyncing
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            onSyncTap!();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSyncing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: InclineColors.accentOrange),
                            )
                          else
                            const Icon(Icons.sync_rounded, size: 14, color: InclineColors.accentOrange),
                          const SizedBox(width: 4),
                          Text(
                            isSyncing ? 'Syncing...' : 'Sync',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isSyncing ? colorScheme.onSurfaceVariant : InclineColors.accentOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Bento Grid 2x2: Calories & Steps, Workout Time & Sleep
        Row(
          children: [
            Expanded(
              child: _BentoMetricCard(
                title: 'ACTIVE CALORIES',
                value: metrics.activeCalories >= 0
                    ? '${metrics.activeCalories}'
                    : '--',
                unit: 'kcal',
                subtitle: metrics.activeCalories >= 0
                    ? 'Goal: ${metrics.targetCalories} kcal'
                    : 'No Health sample',
                icon: Icons.local_fire_department_rounded,
                accentColor: InclineColors.accentOrange,
                progress: metrics.targetCalories > 0
                    ? (metrics.activeCalories / metrics.targetCalories).clamp(0.0, 1.0)
                    : 0.0,
                onTap: () => onMetricTap?.call('calories'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoMetricCard(
                title: 'DAILY STEPS',
                value: metrics.stepCount >= 0
                    ? _formatSteps(metrics.stepCount)
                    : '--',
                unit: 'steps',
                subtitle: 'Goal: ${_formatSteps(metrics.targetSteps)}',
                icon: Icons.directions_walk_rounded,
                accentColor: InclineColors.thermalAmber,
                progress: metrics.targetSteps > 0
                    ? (metrics.stepCount / metrics.targetSteps).clamp(0.0, 1.0)
                    : 0.0,
                onTap: () => onMetricTap?.call('steps'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoMetricCard(
                title: 'WORKOUT TIME',
                value: metrics.workoutMinutes >= 0
                    ? '${metrics.workoutMinutes}'
                    : '--',
                unit: 'min',
                subtitle: metrics.workoutMinutes >= 0
                    ? 'Goal: ${metrics.targetMinutes} min'
                    : 'No Health sample',
                icon: Icons.timer_outlined,
                accentColor: InclineColors.accentOrange,
                progress: metrics.targetMinutes > 0
                    ? (metrics.workoutMinutes / metrics.targetMinutes).clamp(0.0, 1.0)
                    : 0.0,
                onTap: () => onMetricTap?.call('time'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoMetricCard(
                title: 'SLEEP & RECOVERY',
                value: metrics.sleepHours > 0 ? metrics.sleepHours.toStringAsFixed(1) : '--',
                unit: 'hrs',
                subtitle: metrics.heartRateVariabilityMs > 0
                    ? 'HRV $hrvMetricName ${metrics.heartRateVariabilityMs.toStringAsFixed(0)} ms · ${metrics.heartRateVariabilityRecordedAt == null ? 'measured' : DateFormat('h:mm a').format(metrics.heartRateVariabilityRecordedAt!.toLocal())}'
                    : (metrics.sleepHours > 0 && metrics.isManualSleep
                        ? 'Manual sleep · no HRV $hrvMetricName sample'
                        : (metrics.sleepHours > 0
                            ? 'Sleep tracked · no HRV $hrvMetricName sample'
                            : 'No sleep or HRV $hrvMetricName sample')),
                icon: Icons.nightlight_round,
                accentColor: InclineColors.thermalRed,
                progress: metrics.targetSleepHours > 0
                    ? (metrics.sleepHours / metrics.targetSleepHours).clamp(0.0, 1.0)
                    : 0.0,
                onTap: () => onMetricTap?.call('sleep'),
              ),
            ),
          ],
        ),

        // Guidance when the native health provider has no recent samples
        if (!metrics.hasSyncedToday &&
            metrics.stepCount < 0 &&
            metrics.activeCalories < 0 &&
            metrics.workoutMinutes < 0 &&
            metrics.heartRateBpm < 0 &&
            metrics.heartRateVariabilityMs < 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No recent health samples. Connect your health provider or check that your device has synced.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }
}

/// Single Bento Metric Card using M3 Tonal Surface & Responsive Feedback
class _BentoMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final double? progress;
  final VoidCallback? onTap;

  const _BentoMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Semantics(
      button: true,
      label: '$title: $value $unit, $subtitle',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          splashColor: accentColor.withValues(alpha: 0.12),
          highlightColor: accentColor.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with subtle M3 tonal icon container
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: accentColor,
                      ),
                    ),
                    if (progress != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(progress! * 100).toInt()}%',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Eyebrow Label
                Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Large Primary Value with AnimatedSwitcher
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        value,
                        key: ValueKey<String>(value),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Linear indicator if applicable
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: colorScheme.surfaceContainerLow,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Subtitle context
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
