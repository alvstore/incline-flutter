import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/models/models.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/watch_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../components/activity_bento_grid.dart';
import '../components/daily_quote_card.dart';
import '../components/featured_workout_spotlight.dart';
import '../components/home_hero_card.dart';
import '../components/inbody_scan_sheet.dart';
import '../components/recovery_services_row.dart';

/// Principal Material 3 Home Dashboard View (2026 Design Language)
/// Composes modular components into a responsive, fluid [CustomScrollView].
class HomeScreen extends StatefulWidget {
  final Member? member;
  final void Function(int tabIndex)? onNavigateTab;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onOpenNotifications;

  const HomeScreen({
    super.key,
    this.member,
    this.onNavigateTab,
    this.onStartWorkout,
    this.onOpenNotifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Member? _currentMember;
  MemberAttendanceAnalysis? _attendanceAnalysis;
  int _unreadNotifications = 0;
  RealtimeChannel? _notifChannel;

  // Real workout assignment state
  WorkoutPlan? _assignedWorkoutPlan;
  MyTrainer? _assignedTrainer;

  // Reactive state models for dashboard metrics
  late DailyActivityMetrics _activityMetrics;
  late FeaturedWorkoutData _featuredWorkout;

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
    if (_currentMember == null || _currentMember?.avatarUrl == null) {
      _loadCurrentMember();
    }

    final wData = WatchSyncService.instance.data;
    _activityMetrics = DailyActivityMetrics(
      activeCalories: wData.activeCalories,
      targetCalories: wData.goalCalories,
      workoutMinutes: wData.workoutMinutes,
      targetMinutes: wData.goalWorkoutMinutes,
      heartRateBpm: wData.heartRate,
      heartRateRecordedAt: wData.heartRateRecordedAt,
      heartRateVariabilityMs: wData.heartRateVariabilityMs,
      heartRateVariabilityRecordedAt: wData.heartRateVariabilityRecordedAt,
      heartRateZone: wData.heartRate > 0 ? 'Latest reading' : 'No recent reading',
      stepCount: wData.steps,
      targetSteps: wData.goalSteps,
      sleepHours: wData.sleepHours,
      targetSleepHours: wData.goalSleepHours,
      hasSyncedToday: wData.hasSyncedToday,
      isConnected: wData.isConnected,
      isManualSleep: wData.isManualSleep,
    );

    WatchSyncService.instance.addListener(_onWatchSyncUpdated);
    _loadRealActivityMetrics();
    _subscribeToNotifications();

    // Fluid entry animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _featuredWorkout = const FeaturedWorkoutData(
      title: 'Daily Functional Split',
      category: 'GENERAL ATHLETIC SPLIT',
      durationText: '45 min',
      intensity: 'High Intensity',
      exerciseCount: 6,
      coachName: 'Incline Coaching Team',
      tag: 'DAILY ASSIGNMENT',
    );

    _animController.forward();
  }

  @override
  void dispose() {
    if (_notifChannel != null) {
      SupabaseService.instance.unsubscribeChannel(_notifChannel!);
    }
    WatchSyncService.instance.removeListener(_onWatchSyncUpdated);
    _animController.dispose();
    super.dispose();
  }

  void _subscribeToNotifications() {
    try {
      _notifChannel = SupabaseService.instance.subscribeToNotifications(
        onNotificationChanged: () {
          if (mounted) {
            _refreshNotificationsOnly();
          }
        },
      );
    } catch (e) {
      debugPrint('[HomeScreen] Realtime notifications subscription notice: $e');
    }
  }

  Future<void> _refreshNotificationsOnly() async {
    try {
      final notifs = await SupabaseService.instance.fetchNotifications();
      final unreadCount = notifs.where((n) => !n.isRead).length;
      if (mounted) {
        setState(() {
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Notifications refresh notice: $e');
    }
  }

  void _onWatchSyncUpdated() {
    if (!mounted) return;
    final wData = WatchSyncService.instance.data;
    setState(() {
      _activityMetrics = _activityMetrics.copyWith(
        stepCount: wData.steps,
        targetSteps: wData.goalSteps,
        activeCalories: wData.activeCalories,
        targetCalories: wData.goalCalories,
        workoutMinutes: wData.workoutMinutes,
        targetMinutes: wData.goalWorkoutMinutes,
        sleepHours: wData.sleepHours,
        targetSleepHours: wData.goalSleepHours,
          heartRateBpm: wData.heartRate,
        heartRateRecordedAt: wData.heartRateRecordedAt,
        heartRateVariabilityMs: wData.heartRateVariabilityMs,
        heartRateVariabilityRecordedAt: wData.heartRateVariabilityRecordedAt,
        heartRateZone: wData.heartRate > 0 ? 'Latest reading' : 'No recent reading',
        hasSyncedToday: wData.hasSyncedToday,
        isConnected: wData.isConnected,
        isManualSleep: wData.isManualSleep,
      );
    });
  }

  Future<void> _loadRealActivityMetrics() async {
    try {
      final memberId = widget.member?.id ?? _currentMember?.id ?? SupabaseService.instance.cachedMember?.id ?? '';

      final results = await Future.wait([
        SupabaseService.instance.analyzeMemberAttendance(
          memberId.isNotEmpty ? memberId : null,
        ),
        SupabaseService.instance.fetchNotifications(memberId.isNotEmpty ? memberId : null).catchError((_) => <GymNotification>[]),
        SupabaseService.instance.fetchWorkoutPlan(memberId).catchError((_) => null),
        SupabaseService.instance.fetchAssignedTrainer().catchError((_) => null),
      ]);

      final analysis = results[0] as MemberAttendanceAnalysis;
      final notifs = results[1] as List<GymNotification>;
      final workoutPlan = results[2] as WorkoutPlan?;
      final trainer = results[3] as MyTrainer?;
      final unreadCount = notifs.where((n) => !n.isRead).length;

      // Evaluate and trigger missed-gym streak defense alert if habitual window passed
      PushNotificationService.instance.checkAndDispatchMissedGymAlert(analysis);

      final wData = WatchSyncService.instance.data;

      // Extract real assigned workout day if assigned
      WorkoutDay? activeDay;
      FeaturedWorkoutData? assignedData;

      if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
        final todayWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
        activeDay = workoutPlan.days.firstWhere(
          (d) => d.weekdayIndex == (todayWeekday % 7) && !d.isRest,
          orElse: () => workoutPlan.days.firstWhere(
            (d) => !d.isRest,
            orElse: () => workoutPlan.days.first,
          ),
        );

        final exerciseNames = activeDay.exercises
            .map((e) => e.name)
            .where((name) => name.isNotEmpty)
            .take(4)
            .toList();

        final muscles = (activeDay.focus != null && activeDay.focus!.isNotEmpty)
            ? [activeDay.focus!, ...exerciseNames.take(3)]
            : (exerciseNames.isNotEmpty ? exerciseNames : const ['Upper Body', 'Core Stability']);

        assignedData = FeaturedWorkoutData(
          title: (activeDay.focus != null && activeDay.focus!.isNotEmpty)
              ? activeDay.focus!
              : activeDay.dayLabel,
          category: (activeDay.weekLabel != null && activeDay.weekLabel!.isNotEmpty)
              ? activeDay.weekLabel!.toUpperCase()
              : 'COACH ASSIGNED SPLIT',
          durationText: '${activeDay.estimatedMinutes} min',
          intensity: activeDay.isRest ? 'Rest & Recovery' : 'Hypertrophy Focus',
          exerciseCount: activeDay.exercises.length,
          coachName: workoutPlan.trainerName ?? trainer?.fullName ?? 'Incline Coaching Team',
          tag: activeDay.isRest ? 'REST DAY' : 'ASSIGNED TODAY',
          muscleGroups: muscles,
        );
      }

      if (mounted) {
        setState(() {
          _attendanceAnalysis = analysis;
          _unreadNotifications = unreadCount;
          _assignedWorkoutPlan = workoutPlan;
          _assignedTrainer = trainer;
          if (assignedData != null) {
            _featuredWorkout = assignedData;
          }

          // Pure real data: NO fabricated 350 kcal fallback!
          _activityMetrics = _activityMetrics.copyWith(
            activeCalories: wData.activeCalories,
            targetCalories: wData.goalCalories,
            stepCount: wData.steps,
            targetSteps: wData.goalSteps,
            sleepHours: wData.sleepHours,
            targetSleepHours: wData.goalSleepHours,
                  workoutMinutes: wData.workoutMinutes,
            targetMinutes: wData.goalWorkoutMinutes,
            hasSyncedToday: wData.hasSyncedToday,
            isConnected: wData.isConnected,
            isManualSleep: wData.isManualSleep,
            heartRateBpm: wData.heartRate,
            heartRateRecordedAt: wData.heartRateRecordedAt,
            heartRateVariabilityMs: wData.heartRateVariabilityMs,
            heartRateVariabilityRecordedAt: wData.heartRateVariabilityRecordedAt,
            heartRateZone: wData.heartRate > 0 ? 'Latest reading' : 'No recent reading',
          );
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Telemetry attendance notice: $e');
    }
  }

  Future<void> _loadCurrentMember() async {
    try {
      final m = await SupabaseService.instance.fetchCurrentMember();
      if (m != null && mounted) {
        setState(() {
          _currentMember = m;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Member fetch notice: $e');
    }
  }

  // --- M3 Quick Action Sheets & Gate Pass ---

  void _showWaterLogSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: InclineColors.accentOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.water_drop_rounded,
                          color: InclineColors.accentOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hydration Tracker',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Record water intake to maintain optimum cellular hydration.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [250, 500, 750].map((ml) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logged +${ml}ml hydration!'),
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('+$ml ml',
                              style: textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAwaitingWorkoutCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = colorScheme.primary;

    final hasRealCoach = _assignedTrainer != null &&
        _assignedTrainer!.fullName.trim().isNotEmpty &&
        !_assignedTrainer!.fullName.toLowerCase().contains('incline coach') &&
        !_assignedTrainer!.fullName.toLowerCase().contains('incline coaching team');

    final coachFirstName =
        hasRealCoach ? _assignedTrainer!.fullName.split(' ').first : '';

    final statusText =
        hasRealCoach ? 'NO SPLIT ASSIGNED' : 'NO ACTIVE ROUTINE';
    final sentence = hasRealCoach
        ? 'Open Workout to explore training routines or request your personalized split from Coach $coachFirstName.'
        : 'Open Workout to explore club routines or request a custom split from an Incline coach.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? InclineColors.cardBorder
              : InclineColors.lightCardBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Verified Status Pill + Coach Tag (ONLY when real coach exists)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: InclineColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: InclineColors.accentOrange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 11,
                      color: InclineColors.accentOrange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: InclineColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRealCoach)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isDark
                          ? InclineColors.cardBorder
                          : InclineColors.lightCardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: InclineColors.accentOrange,
                        ),
                        child: Center(
                          child: Text(
                            coachFirstName.isNotEmpty
                                ? coachFirstName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Coach $coachFirstName',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? InclineColors.textSecondary
                              : InclineColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'No Workout Routine Assigned Yet',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? InclineColors.textPrimary
                  : InclineColors.lightTextPrimary,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            sentence,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.4,
              color: isDark
                  ? InclineColors.textSecondary
                  : InclineColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: InclineScaleButton(
              onTap: () {
                HapticFeedback.lightImpact();
                context.go('${AppRoutePaths.workout}?tab=0');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fitness_center_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Open Workout & Request Split',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final member = _currentMember ?? widget.member;
    final memberName = member?.profile?.fullName ??
        (SupabaseService.instance.currentUser?.email?.split('@').first.toUpperCase() ??
            'Incline Member');
    final avatarUrl = member?.avatarUrl ?? member?.profile?.avatarUrl;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              color: InclineColors.accentOrange,
              backgroundColor: colorScheme.surfaceContainerHighest,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await Future.wait([
                  _loadCurrentMember(),
                  _loadRealActivityMetrics(),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 1. Luxury Hero Telemetry & Consistency Card
                  SliverToBoxAdapter(
                    child: HomeHeroCard(
                      memberName: memberName,
                      avatarUrl: avatarUrl,
                      membershipStatus:
                          (member?.status ?? 'active').toUpperCase(),
                      streakDays: _attendanceAnalysis?.streakDays ?? 0,
                      attendanceAnalysis: _attendanceAnalysis,
                      unreadNotifications: _unreadNotifications,
                      onNotificationTap: () {
                        if (widget.onOpenNotifications != null) {
                          widget.onOpenNotifications!();
                        } else {
                          context.push(AppRoutePaths.notifications);
                        }
                      },
                      onProfileTap: () =>
                          context.push(AppRoutePaths.profile),
                      onBookTap: () =>
                          context.go('${AppRoutePaths.bookings}?section=0'),
                      onWorkoutTap: () {
                        if (widget.onStartWorkout != null) {
                          widget.onStartWorkout!();
                        } else {
                          context.go('${AppRoutePaths.workout}?tab=0');
                        }
                      },
                      onWaterTap: () => _showWaterLogSheet(context),
                      onDietTap: () =>
                          context.go('${AppRoutePaths.workout}?tab=1'),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // 3. Offline Deterministic Daily Quote (Animated & Responsive)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: DailyQuoteCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // 4. Quick Recovery Services & Amenities Row
                  SliverToBoxAdapter(
                    child: RecoveryServicesRow(
                      onColdPlungeTap: () =>
                          context.go('${AppRoutePaths.bookings}?section=1&filter=ice'),
                      onSaunaTap: () =>
                          context.go('${AppRoutePaths.bookings}?section=1&filter=sauna'),
                      onNutritionTap: () =>
                          context.go('${AppRoutePaths.workout}?tab=1'),
                      onInBodyTap: () => InBodyScanSheet.show(context,
                          member: _currentMember ?? widget.member),
                      onSeeAllTap: () =>
                          context.go('${AppRoutePaths.bookings}?section=1'),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 22)),

                  // 5. Featured Workout Spotlight Section (Authentic Assignment Check)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TODAY\'S HIGHLIGHT',
                            style: textTheme.labelSmall?.copyWith(
                              color: context.brandAccent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_assignedWorkoutPlan != null &&
                              _assignedWorkoutPlan!.days.isNotEmpty)
                            FeaturedWorkoutSpotlight(
                              data: _featuredWorkout,
                              onStartSession: () {
                                if (widget.onStartWorkout != null) {
                                  widget.onStartWorkout!();
                                } else {
                                  context.go('${AppRoutePaths.workout}?tab=0');
                                }
                              },
                              onViewDetails: () =>
                                  context.go('${AppRoutePaths.workout}?tab=0'),
                            )
                          else
                            _buildAwaitingWorkoutCard(context),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Padding for smooth overscroll above floating navigation bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
