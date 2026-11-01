import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/watch_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/components/activity_bento_grid.dart';
import '../home/components/health_goals_sheet.dart';
import '../progress/components/body_assessment_3d_sheet.dart';

/// 2026 World-Class Health Telemetry & Daily Activity Hub
/// Hosts real-time biometric tracking, Galaxy Watch & Health Connect synchronization,
/// Activity Bento Grid, and HOWBODY 3D body composition & posture diagnostics.
class ActivityScreen extends StatefulWidget {
  final Member? member;
  final int initialSubTab; // 0: Wear Telemetry, 1: 3D Body Progress

  const ActivityScreen({
    super.key,
    this.member,
    this.initialSubTab = 0,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  DailyActivityMetrics _metrics = const DailyActivityMetrics();
  Member? _currentMember;
  bool _isTelemetryExpanded = false;
  late int _selectedSubTab;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _currentMember = widget.member ?? SupabaseService.instance.cachedMember;
    WatchSyncService.instance.addListener(_onWatchSyncUpdated);
    _applyWatchDataToMetrics();
    if (_currentMember == null) {
      _loadCurrentMember();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
  }

  Future<void> _loadCurrentMember() async {
    try {
      final member = await SupabaseService.instance.fetchCurrentMember();
      if (mounted && member != null) {
        setState(() => _currentMember = member);
      }
    } catch (e) {
      debugPrint('[INCLINE] ActivityScreen member resolution notice: $e');
    }
  }

  @override
  void dispose() {
    WatchSyncService.instance.removeListener(_onWatchSyncUpdated);
    super.dispose();
  }

  void _onWatchSyncUpdated() {
    if (mounted) {
      _applyWatchDataToMetrics();
    }
  }

  void _applyWatchDataToMetrics() {
    final watch = WatchSyncService.instance.data;
    setState(() {
      _metrics = DailyActivityMetrics(
        activeCalories: watch.activeCalories,
        targetCalories: watch.goalCalories > 0 ? watch.goalCalories : 750,
        workoutMinutes: watch.workoutMinutes,
        targetMinutes: watch.goalWorkoutMinutes > 0 ? watch.goalWorkoutMinutes : 60,
        heartRateBpm: watch.heartRate,
        heartRateZone: watch.heartRate > 0
            ? (watch.heartRate > 140
                ? 'Cardio Zone'
                : (watch.heartRate > 100 ? 'Aerobic' : 'Resting Flow'))
            : 'Sensor Disconnected',
        stepCount: watch.steps,
        targetSteps: watch.goalSteps > 0 ? watch.goalSteps : 10000,
        sleepHours: watch.sleepHours,
        targetSleepHours: watch.goalSleepHours > 0 ? watch.goalSleepHours : 8.0,
        sleepScore: watch.sleepScore,
        hasSyncedToday: watch.hasSyncedToday,
        isConnected: watch.isConnected,
      );
    });
  }

  Future<void> _loadActivityData() async {
    _applyWatchDataToMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const accentGold = InclineColors.accentOrange;
    final isSyncing = WatchSyncService.instance.isSyncing;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedSubTab == 0 ? 'Wear Telemetry' : '3D Body Progress',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              _selectedSubTab == 0
                  ? 'Real-Time Sensor Sync · Galaxy Watch & Health'
                  : 'HOWBODY 360° Volumetric Telemetry & Clinical Scan',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Luxury M3 Segmented Pill Switcher (2 Sub-Tabs: Wear Telemetry | 3D Body Progress)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildSubTabPill(
                    index: 0,
                    label: 'Wear Telemetry',
                    icon: Icons.watch_rounded,
                    isDark: isDark,
                  ),
                  _buildSubTabPill(
                    index: 1,
                    label: '3D Body Progress',
                    icon: Icons.view_in_ar_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _selectedSubTab,
                children: [
                  // Sub-Tab 0: Wear Telemetry
                  RefreshIndicator(
                    onRefresh: () async {
                      await WatchSyncService.instance.syncNow();
                      await _loadActivityData();
                      await _loadCurrentMember();
                    },
                    color: AppTheme.gold,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY TELEMETRY & BIOMETRICS',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: accentGold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ActivityBentoGrid(
                            metrics: _metrics,
                            isSyncing: isSyncing,
                            showSyncInHeader: false,
                            onMetricTap: (key) {
                              HapticFeedback.lightImpact();
                              HealthGoalsSheet.show(context);
                            },
                            onSetGoalsTap: () => HealthGoalsSheet.show(context),
                          ),
                          const SizedBox(height: 14),
                          _buildSyncButton(context, isDark, isSyncing),
                          const SizedBox(height: 14),
                          _buildCollapsibleTelemetryCard(context, isDark),
                        ],
                      ),
                    ),
                  ),

                  // Sub-Tab 1: 3D Body Progress (Embedded View)
                  BodyAssessment3DSheet(
                    key: ValueKey('body_3d_${_currentMember?.id}'),
                    member: _currentMember,
                    isEmbeddedView: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB PILL SWITCHER
  // ---------------------------------------------------------------------------
  Widget _buildSubTabPill({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedSubTab == index;
    final textPrimary = isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;
    final textSecondary = isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSubTab = index);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? InclineColors.accentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.black : textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SYNC WEARABLE TELEMETRY BUTTON (AFTER WIDGETS, ABOVE SUPPORTED SENSORS)
  // ---------------------------------------------------------------------------
  Widget _buildSyncButton(BuildContext context, bool isDark, bool isSyncing) {
    final surface = isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface;
    final border = isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
    final textPrimary = isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;
    final watchService = WatchSyncService.instance;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: isSyncing
            ? null
            : () async {
                HapticFeedback.lightImpact();
                await watchService.syncNow();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Synchronized wearable telemetry via ${watchService.ecosystemSubtitle}',
                        style: GoogleFonts.inter(fontSize: 12.5),
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          side: BorderSide(
            color: isSyncing ? InclineColors.accentOrange : border,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: InclineColors.accentOrange,
                ),
              )
            else
              const Icon(
                Icons.sync_rounded,
                size: 18,
                color: InclineColors.accentOrange,
              ),
            const SizedBox(width: 8),
            Text(
              isSyncing ? 'Syncing Wearable Telemetry...' : 'Sync Wearable Telemetry',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSyncing ? InclineColors.accentOrange : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COLLAPSIBLE TELEMETRY SENSOR CARD (SAVES SPACE)
  // ---------------------------------------------------------------------------
  Widget _buildCollapsibleTelemetryCard(BuildContext context, bool isDark) {
    final surface = isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface;
    final border = isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
    final textPrimary = isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;
    final textSecondary = isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isTelemetryExpanded = !_isTelemetryExpanded);
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: InclineColors.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: InclineColors.accentOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What These Devices Actually Provide',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isTelemetryExpanded
                              ? 'Tap to collapse'
                              : 'Tap to view verified sensor metrics',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isTelemetryExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content (when _isTelemetryExpanded is true)
          if (_isTelemetryExpanded) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTelemetryContractRow(
                    icon: Icons.directions_walk_rounded,
                    title: 'Steps',
                    desc: 'Measured by phone/watch accelerometer.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTelemetryContractRow(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Active Calories',
                    desc: 'Estimated by the wearable based on heart rate and movement.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTelemetryContractRow(
                    icon: Icons.timer_outlined,
                    title: 'Workout Minutes',
                    desc: 'Duration of tracked exercise sessions.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTelemetryContractRow(
                    icon: Icons.favorite_rounded,
                    title: 'Heart Rate',
                    desc: 'Measured only when the member wears a smartwatch with an optical PPG sensor.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTelemetryContractRow(
                    icon: Icons.bedtime_rounded,
                    title: 'Sleep Duration',
                    desc: 'Tracked only if the member wears the device to bed.',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryContractRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: InclineColors.accentOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
