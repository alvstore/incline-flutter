import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env_config.dart';
import '../../core/models/models.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';
import '../diet/diet_view.dart';
import '../profile/member_requests_screen.dart';
import 'workout_execution_sheet.dart';
import '../notifications/notifications_screen.dart';
import '../../core/services/watch_sync_service.dart';

/// Full Day-Wise Workout Schedule and Interactive Routine Screen
class WorkoutScreen extends StatefulWidget {
  final Member? member;
  final int initialTab; // 0: Workout, 1: Diet
  final int? initialDayIndex;
  final WorkoutPlan? initialPlan;
  final MyTrainer? trainer;

  const WorkoutScreen({
    super.key,
    this.member,
    this.initialTab = 0,
    this.initialDayIndex,
    this.initialPlan,
    this.trainer,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final GlobalKey<DietViewState> _dietViewKey = GlobalKey<DietViewState>();
  WorkoutPlan? _plan;
  MyTrainer? _assignedTrainer;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasBoughtPt = false;
  int _selectedDayIndex = 0;
  late int _activeMode; // 0: Workout, 1: Diet, 2: Coach

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialTab;
    _assignedTrainer = widget.trainer;
    if (widget.initialPlan != null) {
      _plan = widget.initialPlan;
      _isLoading = false;
      if (widget.initialDayIndex != null &&
          widget.initialDayIndex! >= 0 &&
          widget.initialDayIndex! < _plan!.days.length) {
        _selectedDayIndex = widget.initialDayIndex!;
      } else {
        final todayWeekday = DateTime.now().weekday;
        if (_plan!.days.isNotEmpty) {
          final match = _plan!.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
          _selectedDayIndex = match != -1 ? match : 0;
        }
      }
    } else {
      String targetMemberId = widget.member?.id ?? '';
      if (targetMemberId.isEmpty || targetMemberId == 'mem_default') {
        final cur = SupabaseService.instance.cachedMember;
        targetMemberId = cur?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      }
      final cachedPlan = SupabaseService.instance.getCachedWorkoutPlan(targetMemberId);
      final cachedTrainer = _assignedTrainer ?? SupabaseService.instance.getCachedAssignedTrainer();

      if (cachedPlan != null) {
        _plan = cachedPlan;
        _isLoading = false;
        if (cachedTrainer != null) _assignedTrainer = cachedTrainer;
        if (widget.initialDayIndex != null &&
            widget.initialDayIndex! >= 0 &&
            widget.initialDayIndex! < _plan!.days.length) {
          _selectedDayIndex = widget.initialDayIndex!;
        } else {
          final todayWeekday = DateTime.now().weekday;
          if (_plan!.days.isNotEmpty) {
            final match = _plan!.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
            if (match != -1) _selectedDayIndex = match;
          }
        }
      }

      _loadWorkoutPlan(silent: cachedPlan != null);
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _activeMode = widget.initialTab);
    }
  }

  Future<void> _loadWorkoutPlan({bool silent = false, bool forceRefresh = false}) async {
    if (!silent && _plan == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      String targetMemberId = widget.member?.id ?? '';
      if (targetMemberId.isEmpty || targetMemberId == 'mem_default') {
        final cur = SupabaseService.instance.cachedMember ?? await SupabaseService.instance.fetchCurrentMember();
        targetMemberId = cur?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      }

      final results = await Future.wait([
        SupabaseService.instance.fetchWorkoutPlan(targetMemberId, forceRefresh: forceRefresh),
        if (widget.trainer != null)
          Future.value(widget.trainer)
        else
          SupabaseService.instance.fetchAssignedTrainer(forceRefresh: forceRefresh),
        SupabaseService.instance.hasBoughtPersonalTraining(targetMemberId),
      ]);
      final plan = results[0] as WorkoutPlan?;
      final trainer = results[1] as MyTrainer?;
      final hasPt = results[2] as bool? ?? false;

      if (widget.initialPlan != null && !forceRefresh && plan == null) {
        // Retain initial plan in preview / widget test environments
        return;
      }

      if (plan != null) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        for (final day in plan.days) {
          final completedIndices = await OfflineSyncService.instance.getCompletedExerciseIndices(
            memberId: targetMemberId,
            date: today,
            planId: plan.id,
            dayLabel: day.dayLabel,
          );
          for (int i = 0; i < day.exercises.length; i++) {
            if (completedIndices.contains(i)) {
              day.exercises[i].isCompleted = true;
            }
          }
        }
      }

      int initialIndex = 0;
      if (plan != null &&
          widget.initialDayIndex != null &&
          widget.initialDayIndex! >= 0 &&
          widget.initialDayIndex! < plan.days.length) {
        initialIndex = widget.initialDayIndex!;
      } else if (plan != null && plan.days.isNotEmpty) {
        final todayWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
        final match = plan.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
        if (match != -1) {
          initialIndex = match;
        } else if (_selectedDayIndex < plan.days.length) {
          initialIndex = _selectedDayIndex;
        } else {
          initialIndex = 0;
        }
      }

      if (mounted) {
        setState(() {
          _plan = plan;
          _assignedTrainer = trainer;
          _hasBoughtPt = hasPt;
          _selectedDayIndex = initialIndex;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] Workout plan fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_plan == null) {
            _errorMessage = 'Could not load workout plan. Please check connection.';
          }
        });
      }
    }
  }

  void _openWorkoutPlayer({int exerciseIndex = 0}) async {
    if (_plan == null || _plan!.days.isEmpty) return;
    final currentDay = _plan!.days[_selectedDayIndex];
    if (currentDay.isRest || currentDay.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today is an active recovery day. Relax in the Steam Suite!')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => WorkoutExecutionSheet(
          day: currentDay,
          initialExerciseIndex: exerciseIndex,
          onExerciseUpdated: () async {
            setState(() {});
            final today = DateTime.now().toIso8601String().substring(0, 10);
            String targetMemberId = widget.member?.id ?? '';
            if (targetMemberId.isEmpty || targetMemberId == 'mem_default') {
              final cur = SupabaseService.instance.cachedMember;
              targetMemberId = cur?.id ?? SupabaseService.instance.currentUser?.id ?? '';
            }
            for (int i = 0; i < currentDay.exercises.length; i++) {
              if (currentDay.exercises[i].isCompleted) {
                await OfflineSyncService.instance.setExerciseCompleted(
                  memberId: targetMemberId,
                  date: today,
                  planId: _plan?.id ?? 'default_plan',
                  dayLabel: currentDay.dayLabel,
                  exerciseIndex: i,
                  isCompleted: true,
                );
              }
            }
            if (_plan != null) {
              await OfflineSyncService.instance.cacheWorkoutPlan(_plan!);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bg,
        body: const Center(
          child: DumbbellLoader(
            text: 'Loading assigned routine...',
            size: DumbbellLoaderSize.md,
          ),
        ),
      );
    }

    if (_errorMessage != null && _plan == null) {
      return Scaffold(
        backgroundColor: context.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: context.brandAccent),
                const SizedBox(height: 12),
                Text(
                  'Could not retrieve workout routine',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _loadWorkoutPlan(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandAccent,
                    foregroundColor: context.onBrandAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plan = _plan;
    final days = plan?.days ?? const <WorkoutDay>[];
    final activeDay = days.isNotEmpty
        ? days[_selectedDayIndex.clamp(0, days.length - 1)]
        : null;
    final today = DateUtils.dateOnly(DateTime.now());
    final scheduleEntries = <({int dayIndex, WorkoutDay day, DateTime date})>[
      for (var index = 0; index < days.length; index++)
        (
          dayIndex: index,
          day: days[index],
          date: _calendarDateForWorkoutDay(days[index], index, today),
        ),
    ]..sort((a, b) {
        final dateOrder = a.date.compareTo(b.date);
        return dateOrder != 0
            ? dateOrder
            : a.dayIndex.compareTo(b.dayIndex);
      });

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _activeMode == 0
                  ? 'Workout Routine'
                  : (_activeMode == 1
                      ? 'Nutrition & Diet'
                      : 'Assigned Coach'),
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              _activeMode == 0
                  ? 'Incline Periodized Athletic Split'
                  : (_activeMode == 1
                      ? 'Precision Fueling & Micronutrients'
                      : 'Dedicated Guidance & 1-on-1 Coaching'),
              style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: context.brandAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            tooltip: 'Club bulletins',
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.brandAccent),
            onPressed: () {
              _loadWorkoutPlan(forceRefresh: true);
              _dietViewKey.currentState?.reload(forceRefresh: true);
            },
            tooltip: 'Refresh from Incline server',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Luxury M3 Segmented Pill Switcher (3 Segments: Workout, Nutrition, Coach)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.cardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderCol),
              ),
              child: Row(
                children: [
                  _buildTabPill(index: 0, label: 'Workout', icon: Icons.fitness_center_rounded),
                  _buildTabPill(index: 1, label: 'Nutrition', icon: Icons.restaurant_menu_rounded),
                  _buildTabPill(index: 2, label: 'Coach', icon: Icons.person_rounded),
                ],
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _activeMode,
                children: [
                  RefreshIndicator(
                    onRefresh: () => _loadWorkoutPlan(forceRefresh: true),
                    color: context.brandAccent,
                    child: days.isEmpty
                        ? _buildEmptyWorkoutView()
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          // 1. Compact Weekly Training Schedule (Day Selector Rail)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'WEEKLY SCHEDULE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: context.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.emerald,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      (WatchSyncService.instance.data.isConnected &&
                                              WatchSyncService.instance.data.sleepScore > 0)
                                          ? 'READINESS ${WatchSyncService.instance.data.sleepScore}%'
                                          : 'SCHEDULE ACTIVE',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: scheduleEntries.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final entry = scheduleEntries[idx];
                                final d = entry.day;
                                final isSelected = entry.dayIndex == _selectedDayIndex;
                                final isToday = DateUtils.isSameDay(entry.date, today);

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedDayIndex = entry.dayIndex),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 64,
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? context.brandAccent : context.cardElevated,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? context.brandAccent
                                            : (isToday ? context.brandAccent.withValues(alpha: 0.5) : context.borderCol),
                                        width: isSelected || isToday ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          DateFormat('EEE').format(entry.date).toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? context.onBrandAccent : context.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          DateFormat('dd').format(entry.date),
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? context.onBrandAccent : context.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withValues(alpha: 0.16)
                                                : (d.isRest
                                                    ? AppTheme.cyan.withValues(alpha: 0.15)
                                                    : AppTheme.emerald.withValues(alpha: 0.15)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            d.isRest ? 'Rest' : '${d.exercises.length} ex',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? context.onBrandAccent
                                                  : (d.isRest ? AppTheme.cyan : AppTheme.emerald),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. Focused Active Day Hero & Action Card
                          if (activeDay != null) ...[
                            BentoCard(
                              asymmetricCorners: true,
                              padding: const EdgeInsets.all(14),
                              backgroundColor: context.cardElevated,
                              border: Border.all(color: context.borderCol),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: context.brandAccent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                activeDay.isRest ? Icons.spa_rounded : Icons.fitness_center_rounded,
                                                color: context.brandAccent,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    activeDay.dayLabel,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w800,
                                                      color: context.textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    activeDay.focus ?? 'Session Routine',
                                                    style: GoogleFonts.outfit(fontSize: 11.5, color: context.textSecondary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!activeDay.isRest)
                                        ElevatedButton(
                                          onPressed: () => _openWorkoutPlayer(exerciseIndex: 0),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: context.brandAccent,
                                            foregroundColor: context.onBrandAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            'Start Session',
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (!activeDay.isRest) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _statBadge(Icons.layers_rounded, '${activeDay.exercises.length} exercises'),
                                        _statBadge(Icons.timer_outlined, '~${activeDay.estimatedMinutes} min'),
                                        _statBadge(Icons.repeat_rounded, '${activeDay.totalSets} total sets'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Progress Bar
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Session Progress',
                                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            '${activeDay.completedExercisesCount} / ${activeDay.exercises.length} completed',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: context.brandAccent,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    LinearProgressIndicator(
                                      value: activeDay.exercises.isNotEmpty
                                          ? activeDay.completedExercisesCount / activeDay.exercises.length
                                          : 0.0,
                                      backgroundColor: context.borderCol,
                                      valueColor: AlwaysStoppedAnimation<Color>(context.brandAccent),
                                      borderRadius: BorderRadius.circular(4),
                                      minHeight: 5,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                const SizedBox(height: 24),

                // Exercise List or Rest Day Content
                if (activeDay.isRest) ...[
                  BentoCard(
                    padding: const EdgeInsets.all(28),
                    backgroundColor: context.cardElevated,
                    border: Border.all(color: context.borderCol),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cyan.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.hot_tub_rounded, color: AppTheme.cyan, size: 48),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Active Recovery & Contrast Day',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enjoy complimentary Steam Suite therapy, light walking, and deep tissue mobility to prepare for tomorrow.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'EXERCISES (${activeDay.exercises.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: context.textMuted,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.brandAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: context.brandAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'COACH PROTOCOL ACTIVE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: context.brandAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Optional Warm-Up Protocol Card
                  if (activeDay.warmUp != null && activeDay.warmUp!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WARM-UP PROTOCOL',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  activeDay.warmUp!,
                                  style: GoogleFonts.outfit(fontSize: 12, color: context.textPrimary, height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeDay.exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, exIdx) {
                      final ex = activeDay.exercises[exIdx];

                      return BentoCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: ex.isCompleted
                            ? AppTheme.emerald.withValues(alpha: 0.06)
                            : context.cardElevated,
                        border: Border.all(
                          color: ex.isCompleted
                                ? AppTheme.emerald.withValues(alpha: 0.35)
                              : context.borderCol,
                        ),
                        onTap: () => _openWorkoutPlayer(exerciseIndex: exIdx),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                final nextState = !ex.isCompleted;
                                setState(() => ex.isCompleted = nextState);
                                final today = DateTime.now().toIso8601String().substring(0, 10);
                                String targetMemberId = widget.member?.id ?? '';
                                if (targetMemberId.isEmpty || targetMemberId == 'mem_default') {
                                  final cur = SupabaseService.instance.cachedMember;
                                  targetMemberId = cur?.id ?? SupabaseService.instance.currentUser?.id ?? '';
                                }
                                await OfflineSyncService.instance.setExerciseCompleted(
                                  memberId: targetMemberId,
                                  date: today,
                                  planId: _plan?.id ?? 'default_plan',
                                  dayLabel: activeDay.dayLabel,
                                  exerciseIndex: exIdx,
                                  isCompleted: nextState,
                                );
                                if (_plan != null) {
                                  await OfflineSyncService.instance.cacheWorkoutPlan(_plan!);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: ex.isCompleted
                                        ? AppTheme.emerald
                                        : context.cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: context.borderCol),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (ex.imageUrl != null && ex.imageUrl!.isNotEmpty)
                                        Image.network(
                                          ex.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              '${exIdx + 1}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: context.brandAccent,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Center(
                                          child: Text(
                                            '${exIdx + 1}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: context.brandAccent,
                                            ),
                                          ),
                                        ),
                                      if (ex.isCompleted)
                                        Container(
                                          color: AppTheme.emerald.withValues(alpha: 0.85),
                                          child: const Center(
                                            child: Icon(Icons.check, color: Colors.black, size: 22),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: ex.isCompleted ? context.textMuted : context.textPrimary,
                                      decoration: ex.isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (ex.machineName != null && ex.machineName!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cyan.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.precision_manufacturing_rounded, size: 11, color: AppTheme.cyan),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              ex.machineName!,
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.cyan,
                                                letterSpacing: 0.3,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${ex.sets} Sets × ${ex.reps} Reps',
                                        style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 10, color: Colors.amber),
                                            const SizedBox(width: 3),
                                            Text(
                                              ex.rest ?? '60s',
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ex.coachCue != null || ex.notes != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      ex.coachCue != null ? 'Cue: ${ex.coachCue!}' : ex.notes!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: context.brandAccent.withValues(alpha: 0.9),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Form Media Indicator Chip (Driven by Backend Exercise Toggle)
                            if (ex.showVideo && ex.videoUrl != null && ex.videoUrl!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.brandAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      size: 13,
                                      color: context.brandAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Video',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.brandAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (ex.imageUrl != null && ex.imageUrl!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.borderCol.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.borderCol),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 13,
                                      color: context.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Guide',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Optional Cool-Down & Mobility Flush Card
                  if (activeDay.coolDown != null && activeDay.coolDown!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.ac_unit_rounded, color: AppTheme.cyan, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COOL-DOWN & MOBILITY FLUSH',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.cyan, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  activeDay.coolDown!,
                                  style: GoogleFonts.outfit(fontSize: 12, color: context.textPrimary, height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Official Program Wisdom & Guidelines (Do's, Don'ts & Pro Tips from PDF) - Editorial Bento Collage
                  if (plan != null && (plan.dos.isNotEmpty || plan.donts.isNotEmpty || plan.proTips.isNotEmpty)) ...[
                    const SizedBox(height: 18),
                    _buildTrainingWisdomCollage(plan),
                  ],
                  const SizedBox(height: 24),
                ],
              ],
            ],
          ),
        ),
      ),
      DietView(key: _dietViewKey, member: widget.member, trainer: _assignedTrainer),
      _buildCoachView(plan),
    ],
  ),
),
  ],
),
),
);
  }

  /// Maps recurring plan weekdays onto the next dates in the booking calendar.
  DateTime _calendarDateForWorkoutDay(
    WorkoutDay day,
    int dayIndex,
    DateTime today,
  ) {
    final todayWeekdayIndex = today.weekday % 7;
    final weekdayIndex =
        (day.weekdayIndex ?? ((todayWeekdayIndex + dayIndex) % 7)) % 7;
    final daysUntilNextOccurrence = (weekdayIndex - todayWeekdayIndex + 7) % 7;
    final weekLabel = day.weekLabel ?? '';
    final weekNumberText = RegExp(r'\d+').firstMatch(weekLabel)?.group(0);
    final weekNumber =
        int.tryParse(weekNumberText ?? '') ?? (dayIndex ~/ 7) + 1;
    final additionalWeeks = (weekNumber > 1 ? weekNumber - 1 : 0) * 7;

    return today.add(Duration(days: daysUntilNextOccurrence + additionalWeeks));
  }

  Widget _buildTabPill({required int index, required String label, required IconData icon}) {
    final isSelected = _activeMode == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _activeMode = index);
          if (index == 0) {
            _loadWorkoutPlan(silent: true);
          } else if (index == 1) {
            _dietViewKey.currentState?.reloadSilent();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.brandAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? context.onBrandAccent : context.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? context.onBrandAccent : context.textPrimary,
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

  Widget _statBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.brandAccent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: context.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// High-Performance Training Wisdom & Protocols Bento Collage
  Widget _buildTrainingWisdomCollage(WorkoutPlan plan) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.cardElevated,
      border: Border.all(color: context.borderCol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_stories_rounded, size: 16, color: context.brandAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAINING WISDOM & PROTOCOLS',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: context.brandAccent,
                      ),
                    ),
                    Text(
                      'Official Guidelines • Doc ${plan.docId ?? "INCLINE-MVNYA0Z2"}',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Collage Top Hero: Wisdom Quote
          if (plan.quote != null && plan.quote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, size: 20, color: context.brandAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.quote!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: context.textPrimary,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Collage Tile 2: Pro Tips Mosaic
          if (plan.proTips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'PRO TIPS',
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.proTips.map((tip) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.brandAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tips_and_updates_rounded, size: 11, color: context.brandAccent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tip,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.brandAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],

          // Collage Tile 3: Two-Column Side-by-Side DO'S & DON'TS
          if (plan.dos.isNotEmpty || plan.donts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: DO'S
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.emerald),
                            const SizedBox(width: 5),
                            Text(
                              "DO'S",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.emerald,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...plan.dos.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppTheme.emerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d,
                                  style: GoogleFonts.outfit(fontSize: 11, color: context.textPrimary, height: 1.25),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Right Column: DON'TS
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.rose.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.rose.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cancel_rounded, size: 14, color: AppTheme.rose),
                            const SizedBox(width: 5),
                            Text(
                              "DON'TS",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.rose,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...plan.donts.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppTheme.rose,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d,
                                  style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary, height: 1.25),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _callTrainer(String? phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = (phone != null && phone.isNotEmpty)
        ? phone.replaceAll(RegExp(r'[^0-9+]'), '')
        : EnvConfig.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open phone dialer for $cleanPhone')),
          );
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] Call trainer error: $e');
    }
  }

  /// Dedicated Coach & Training Tier View (4th Tab) - Single Source of Truth.
  /// Fetches dynamic assigned coach from backend (or Incline Head Coach).
  /// Distinguishes between General Training Program (shows Upgrade to Personal Training)
  /// and Active 1-on-1 Personal Training (shows Dedicated Coach details & Inquire/Schedule).
  Widget _buildCoachView(WorkoutPlan? plan) {
    final workoutPlan = plan;
    final isPtPurchased = _hasBoughtPt || (workoutPlan?.isPersonalTraining == true);

    final rawTrainerName = _assignedTrainer?.fullName.isNotEmpty == true
        ? _assignedTrainer!.fullName
        : (workoutPlan?.trainerName ?? 'Coach Bhagirath Gurjar');
    final trainerName = rawTrainerName.startsWith('Coach') || rawTrainerName.startsWith('Incline')
        ? rawTrainerName
        : 'Coach $rawTrainerName';

    final rawAvatar = _assignedTrainer?.avatarUrl;
    final avatarUrl = (rawAvatar != null && rawAvatar.isNotEmpty && !rawAvatar.contains('1568602471122'))
        ? rawAvatar
        : 'assets/images/coach_bhagirath.jpg';

    final trainerPhone = _assignedTrainer?.phone ?? EnvConfig.supportPhone;
    final coachRole = (_assignedTrainer?.specializations.isNotEmpty == true)
        ? _assignedTrainer!.specializations.join(' • ')
        : (isPtPurchased ? 'Dedicated 1-on-1 Personal Trainer' : 'Head Coach & Biomechanics Specialist');
    final coachBio = isPtPurchased
        ? 'Your dedicated 1-on-1 coach is actively programming your progressive overload split, biomechanics, and recovery protocols.'
        : 'Incline club coaches supervise the floor, offer lifting cues, and conduct 3D assessments. Upgrade to 1:1 Personal Training for dedicated daily coaching.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Unified Assigned Coach & Training Tier Card (Single Source of Truth)
          BentoCard(
            padding: const EdgeInsets.all(18),
            backgroundColor: context.cardElevated,
            border: Border.all(
              color: isPtPurchased
                  ? AppTheme.emerald.withValues(alpha: 0.35)
                  : context.brandAccent.withValues(alpha: 0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Coach Avatar, Name & Verified Badge
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPtPurchased ? AppTheme.emerald : context.brandAccent,
                          width: 2,
                        ),
                        color: context.cardBg,
                      ),
                      child: ClipOval(
                        child: _buildTrainerAvatar(avatarUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  trainerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: isPtPurchased ? AppTheme.emerald : context.brandAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coachRole,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isPtPurchased ? AppTheme.emerald : context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _assignedTrainer != null
                                ? 'Dynamic Backend Assigned Coach'
                                : 'Incline Coaching Team',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Status Badges Row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPtPurchased
                            ? AppTheme.emerald.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPtPurchased
                              ? AppTheme.emerald.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPtPurchased ? Icons.verified_rounded : Icons.shield_outlined,
                            size: 12,
                            color: isPtPurchased ? AppTheme.emerald : Colors.amber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPtPurchased
                                ? '1-ON-1 PERSONAL TRAINING'
                                : 'GENERAL TRAINING PROGRAM',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: isPtPurchased ? AppTheme.emerald : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPtPurchased
                            ? AppTheme.emerald.withValues(alpha: 0.12)
                            : context.brandAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPtPurchased ? 'ACTIVE BESPOKE PROTOCOL' : 'INCLUDED WITH MEMBERSHIP',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isPtPurchased ? AppTheme.emerald : context.brandAccent,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  coachBio,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: context.borderCol.withValues(alpha: 0.4)),
                const SizedBox(height: 14),

                // Single Source of Truth Action Buttons
                Row(
                  children: [
                    // Button 1: Call Coach
                    Expanded(
                      child: InkWell(
                        onTap: () => _callTrainer(trainerPhone),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call_rounded, size: 15, color: AppTheme.emerald),
                              const SizedBox(width: 6),
                              Text(
                                'Call Coach',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Button 2: If General Program -> Upgrade to Personal Training
                    //           Else (PT Purchased) -> Inquire Coach
                    Expanded(
                      child: InkWell(
                        onTap: isPtPurchased ? _openTrainerDialog : _showRequestPtUpgradeSheet,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isPtPurchased
                                  ? [context.cardElevated, context.cardBg]
                                  : [context.brandAccent, InclineColors.accentOrange],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: isPtPurchased ? Border.all(color: context.borderCol) : null,
                            boxShadow: isPtPurchased
                                ? null
                                : [
                                    BoxShadow(
                                      color: context.brandAccent.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPtPurchased ? Icons.chat_bubble_outline_rounded : Icons.star_rounded,
                                size: 15,
                                color: isPtPurchased ? context.textPrimary : context.onBrandAccent,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isPtPurchased ? 'Inquire Coach' : 'Upgrade to Personal Training',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isPtPurchased ? context.textPrimary : context.onBrandAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

    /// Frontdesk PT Upgrade Request Sheet (No prices shown, creates service request to frontdesk)
  void _showRequestPtUpgradeSheet() {
    String selectedFocus = 'Hypertrophy & Physique';
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: context.borderCol,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.brandAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.stars_rounded, color: context.brandAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Personal Training (1-on-1)',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            _assignedTrainer != null
                                ? 'High Priority • Assigned to ${_assignedTrainer!.fullName}'
                                : 'High Priority • Assigned to Incline Coaching Staff',
                            style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _assignedTrainer != null
                      ? 'Submit your 1-on-1 Personal Training purchase request. This directly creates a High Priority task assigned to ${_assignedTrainer!.fullName} and alerts the frontdesk to initiate your private onboarding.'
                      : 'Submit your 1-on-1 Personal Training purchase request. This directly creates a High Priority task assigned to the Incline Head Coach and alerts the frontdesk to initiate your private onboarding.',
                  style: GoogleFonts.outfit(fontSize: 12.5, color: context.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'PRIMARY TRAINING FOCUS',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Hypertrophy & Physique',
                    'Strength & Powerlifting',
                    'Fat Loss & Conditioning',
                    'Mobility & Longevity',
                  ].map((focus) {
                    final isSelected = selectedFocus == focus;
                    return ChoiceChip(
                      label: Text(
                        focus,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? context.onBrandAccent : context.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: context.brandAccent,
                      backgroundColor: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isSelected ? context.brandAccent : context.borderCol),
                      ),
                      onSelected: (val) {
                        if (val) setModalState(() => selectedFocus = focus);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'NOTES OR PREFERRED TIMES (OPTIONAL)',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g., Morning slots (07:00 AM) preferred, focus on shoulder rehab...',
                    hintStyle: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                    filled: true,
                    fillColor: context.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderCol)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.brandAccent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      String targetMemberId = widget.member?.id ?? '';
                      if (targetMemberId.isEmpty || targetMemberId == 'mem_default') {
                        final cur = SupabaseService.instance.cachedMember ?? await SupabaseService.instance.fetchCurrentMember();
                        targetMemberId = cur?.id ?? SupabaseService.instance.currentUser?.id ?? '';
                      }

                      final note = noteController.text.trim();
                      final curMember = widget.member ?? SupabaseService.instance.cachedMember;
                      final memberName = curMember?.fullName ?? 'Member';
                      final memberCode = curMember?.memberCode ?? '';
                      final phone = curMember?.profile?.phone ?? '';
                      final codeStr = memberCode.isNotEmpty ? ' ($memberCode)' : '';
                      final phoneStr = phone.isNotEmpty ? ' • Phone: $phone' : '';

                      final desc = 'Member: $memberName$codeStr$phoneStr\n'
                          'Primary Training Focus: $selectedFocus\n'
                          '${note.isNotEmpty ? "Preferred Timings / Notes: $note\n" : ""}'
                          'Flow: PT Purchase Initiated by Member (Task Created for Frontdesk / Coaching Team).\n'
                          'Action Required: Frontdesk team to initiate purchase billing, assign personal training package quota, and schedule 1-on-1 private onboarding session with coach.';

                      await SupabaseService.instance.submitServiceRequest(
                        memberId: targetMemberId,
                        title: 'PT Purchase: 1-on-1 Personal Training ($selectedFocus)',
                        description: desc,
                        category: 'pt_purchase',
                        priority: 'high',
                        metadata: {
                          'focus': selectedFocus,
                          'notes': note,
                          'member_code': memberCode,
                          'flow': 'backend_task_purchase',
                          'requested_program': '1-on-1 Personal Training',
                        },
                      );

                      if (mounted) {
                        _showPtPurchaseConfirmationDialog(selectedFocus);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandAccent,
                      foregroundColor: context.onBrandAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Submit PT Purchase Request',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
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

  /// Dialog shown after PT Purchase Request is created:
  /// Confirms High Priority backend task assignment to Coach Bhagirath
  /// and offers instant 1:1 message on WhatsApp or Direct Call.
  void _showPtPurchaseConfirmationDialog(String focus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, size: 36, color: AppTheme.emerald),
            ),
            const SizedBox(height: 14),
            Text(
              'PT Purchase Task Created',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                _assignedTrainer != null
                    ? 'HIGH PRIORITY DESK TASK • ASSIGNED TO ${_assignedTrainer!.fullName.toUpperCase()}'
                    : 'HIGH PRIORITY DESK TASK • ASSIGNED TO INCLINE TEAM',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: context.brandAccent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _assignedTrainer != null
                  ? 'Your 1-on-1 Personal Training purchase request has been submitted directly as a High Priority task for the Incline frontdesk and Coach ${_assignedTrainer!.fullName}. Our team will initiate billing and schedule your private onboarding.'
                  : 'Your 1-on-1 Personal Training purchase request has been submitted directly as a High Priority task for the Incline frontdesk and coaching staff. Our team will initiate billing and schedule your private onboarding.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Button 1: Send 1:1 Message
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final coachName = _assignedTrainer?.fullName ?? 'Coach';
                  final memberName = widget.member?.fullName ?? 'Incline Member';
                  final memberCode = widget.member?.memberCode ?? '';
                  final codeStr = memberCode.isNotEmpty ? ' ($memberCode)' : '';
                  final text = 'Hi $coachName, I ($memberName$codeStr) have submitted a PT Purchase Request for 1-on-1 Personal Training ($focus). Please confirm my onboarding!';
                  final coachPhone = _assignedTrainer?.phone?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (coachPhone.isNotEmpty) {
                    final uri = Uri.parse('https://wa.me/$coachPhone?text=${Uri.encodeComponent(text)}');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  }
                },
                icon: Icon(Icons.chat_outlined, size: 16, color: context.onBrandAccent),
                label: Text(
                  'Send 1:1 Message to ${_assignedTrainer?.fullName ?? "Coach"}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.onBrandAccent,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Button 2: Call Coach
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final coachPhone = _assignedTrainer?.phone ?? '';
                  if (coachPhone.isNotEmpty) {
                    _callTrainer(coachPhone);
                  }
                },
                icon: const Icon(Icons.call_rounded, size: 16, color: AppTheme.emerald),
                label: Text(
                  'Call ${_assignedTrainer?.fullName ?? "Coach"} Now',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 4),

            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders Coach Bhagirath Gurjar's avatar using local bundled asset with network/initials fallback
  Widget _buildTrainerAvatar(String? url) {
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/coach_bhagirath.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text('BG', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.brandAccent)),
          ),
        ),
      );
    }
    return Image.asset(
      'assets/images/coach_bhagirath.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(
        child: Text('BG', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.brandAccent)),
      ),
    );
  }

  void _openTrainerDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.support_agent_rounded, size: 20, color: AppTheme.emerald),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask Coach Bhagirath',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                  ),
                  Text(
                    'Lead Coach & Strength Specialist',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.emerald),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questions regarding machine setup, set tempo, or progressive overload on today’s split?',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Can we adjust hack squat depth for knee recovery?',
                hintStyle: GoogleFonts.outfit(color: context.textMuted, fontSize: 12),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.borderCol),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent to Coach Bhagirath Gurjar.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Send Query', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkoutView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Luxury Empty State Hero Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.cardElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.brandAccent.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: context.brandAccent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Workout Icon Badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.brandAccent.withValues(alpha: 0.15),
                    border: Border.all(color: context.brandAccent.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: context.brandAccent,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.brandAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.brandAccent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'AWAITING COACH PROGRAMMING',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: context.brandAccent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'No Active Workout Plan',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Request a personalised plan from your trainer to take the guesswork out of training.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: InclineScaleButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberRequestsScreen(
                          member: widget.member ?? SupabaseService.instance.cachedMember,
                          initialCategory: 'workout',
                        ),
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberRequestsScreen(
                            member: widget.member ?? SupabaseService.instance.cachedMember,
                            initialCategory: 'workout',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                      label: Text(
                        'Request Workout Plan',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandAccent,
                        foregroundColor: context.onBrandAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
