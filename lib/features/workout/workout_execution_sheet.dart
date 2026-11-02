import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/models.dart';
import '../../core/services/watch_sync_service.dart';
import '../../core/theme/app_theme.dart';
import 'animated_exercise_visualizer.dart';
import 'detailed_exercise_sheet.dart';
import '../home/components/inbody_scan_sheet.dart';

/// State model for isolated rest timer updates without rebuilding parent widget tree.
class RestTimerState {
  final bool isResting;
  final int secondsLeft;
  final int totalSeconds;

  const RestTimerState({
    this.isResting = false,
    this.secondsLeft = 0,
    this.totalSeconds = 60,
  });

  RestTimerState copyWith({
    bool? isResting,
    int? secondsLeft,
    int? totalSeconds,
  }) {
    return RestTimerState(
      isResting: isResting ?? this.isResting,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }
}

/// Smart Interactive Workout Execution Player:
/// Allows members to select an exercise, smartly complete sets with rest timers,
/// automatically advance to the next exercise, and sync with their smartwatch.
/// Uses localized ValueNotifier and RepaintBoundary to eliminate 1-second parent rebuilds.
class WorkoutExecutionSheet extends StatefulWidget {
  final WorkoutDay day;
  final int initialExerciseIndex;
  final VoidCallback onExerciseUpdated;

  const WorkoutExecutionSheet({
    super.key,
    required this.day,
    this.initialExerciseIndex = 0,
    required this.onExerciseUpdated,
  });

  @override
  State<WorkoutExecutionSheet> createState() => _WorkoutExecutionSheetState();
}

class _WorkoutExecutionSheetState extends State<WorkoutExecutionSheet> {
  late int _currentExerciseIndex;
  late List<bool> _completedSets;

  // Localized Rest Timer Notifier to prevent rebuilding the entire sheet every second
  final ValueNotifier<RestTimerState> _restTimerNotifier = ValueNotifier(const RestTimerState());
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _currentExerciseIndex = widget.initialExerciseIndex;
    _initSetsForCurrentExercise();
  }

  void _initSetsForCurrentExercise() {
    final currentEx = widget.day.exercises[_currentExerciseIndex];
    _completedSets = List.generate(currentEx.sets, (index) => false);
    _cancelRestTimer();
  }

  @override
  void dispose() {
    _cancelRestTimer();
    _restTimerNotifier.dispose();
    super.dispose();
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restTimerNotifier.value = const RestTimerState(isResting: false, secondsLeft: 0, totalSeconds: 60);
  }

  void _startRestTimer(int seconds) {
    _cancelRestTimer();
    _restTimerNotifier.value = RestTimerState(
      isResting: true,
      totalSeconds: seconds,
      secondsLeft: seconds,
    );

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = _restTimerNotifier.value;
      if (current.secondsLeft <= 1) {
        _cancelRestTimer();
        HapticFeedback.mediumImpact();
      } else {
        _restTimerNotifier.value = current.copyWith(
          secondsLeft: current.secondsLeft - 1,
        );
      }
    });
  }

  void _completeSet(int setIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      _completedSets[setIndex] = true;
    });

    final currentEx = widget.day.exercises[_currentExerciseIndex];

    // If all sets are now completed, mark the exercise as finished
    if (_completedSets.every((s) => s)) {
      currentEx.isCompleted = true;
      widget.onExerciseUpdated();
      HapticFeedback.mediumImpact();
    }

    // Parse rest duration (e.g. "60s", "90s")
    int restSec = 60;
    if (currentEx.rest != null) {
      final parsed = int.tryParse(currentEx.rest!.replaceAll(RegExp(r'\D'), ''));
      if (parsed != null && parsed > 0) restSec = parsed;
    }

    // Auto-trigger smart rest timer
    _startRestTimer(restSec);
  }

  void _nextExercise() {
    HapticFeedback.lightImpact();
    if (_currentExerciseIndex < widget.day.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _initSetsForCurrentExercise();
      });
    } else {
      _showWorkoutCompleteSheet();
    }
  }

  void _prevExercise() {
    HapticFeedback.lightImpact();
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
        _initSetsForCurrentExercise();
      });
    }
  }

  void _showWorkoutCompleteSheet() {
    HapticFeedback.heavyImpact();

    // Persist workout session to verified on-device storage
    SharedPreferences.getInstance().then((prefs) {
      final now = DateTime.now();
      final logEntry = '${now.toIso8601String()}|${widget.day.dayLabel}|${widget.day.focus ?? 'Workout'}|${widget.day.exercises.length}';
      final existing = prefs.getStringList('incline_completed_workouts_log') ?? [];
      existing.insert(0, logEntry);
      if (existing.length > 50) existing.removeLast();
      prefs.setStringList('incline_completed_workouts_log', existing);
    }).catchError((_) {});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
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
                    child: Icon(Icons.stars_rounded, color: context.brandAccent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Session Complete!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Phenomenal work! You completed all exercises in today’s ${widget.day.focus ?? 'session'}.',
                style: GoogleFonts.outfit(color: context.textSecondary, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(WatchSyncService.instance.watchIcon, color: AppTheme.cyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved to local session history. Completed sets do not create wearable health samples.',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.cyan, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    InBodyScanSheet.show(context);
                  },
                  icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                  label: Text('Record 3D Assessment & Body Metrics', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brandAccent,
                    side: BorderSide(color: context.brandAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandAccent,
                    foregroundColor: context.onBrandAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Return to Schedule',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.day.exercises;
    final currentEx = exercises[_currentExerciseIndex];
    final isLastExercise = _currentExerciseIndex == exercises.length - 1;
    final allSetsDone = _completedSets.every((s) => s);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.day.dayLabel,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.brandAccent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.day.focus ?? 'Workout Session'} • Exercise ${_currentExerciseIndex + 1} of ${exercises.length}',
              style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Exercise Progress Line
            LinearProgressIndicator(
              value: (_currentExerciseIndex + 1) / exercises.length,
              backgroundColor: context.borderCol,
              valueColor: AlwaysStoppedAnimation<Color>(context.brandAccent),
              minHeight: 3,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Isolated Animated Exercise Visualizer in RepaintBoundary
                    RepaintBoundary(
                      child: AnimatedExerciseVisualizer(
                        exercise: currentEx,
                        exerciseIndex: _currentExerciseIndex,
                        totalExercises: exercises.length,
                        isResting: _restTimerNotifier.value.isResting,
                        showProtocol: false, // Moved to bottom below sets to prevent cutting off video view
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Localized Rest Timer Display via ValueListenableBuilder (No parent rebuilds)
                    ValueListenableBuilder<RestTimerState>(
                      valueListenable: _restTimerNotifier,
                      builder: (context, restState, _) {
                        if (!restState.isResting) return const SizedBox.shrink();

                        final progress = restState.totalSeconds > 0
                            ? (restState.secondsLeft / restState.totalSeconds).clamp(0.0, 1.0)
                            : 0.0;

                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 38,
                                    width: 38,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 3.5,
                                          backgroundColor: context.borderCol,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.amber),
                                        ),
                                        Text(
                                          '${restState.secondsLeft}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AppTheme.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rest Period Active',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Recover breath and hydrate before set.',
                                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _cancelRestTimer();
                                    },
                                    child: const Text('Skip Rest'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Interactive Sets Table Header with Manual Rest Launcher
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'TRACK WORKING SETS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: context.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                DetailedExerciseSheet.show(context, currentEx);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.brandAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.brandAccent.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 12, color: context.brandAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Guide',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.brandAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                int restSec = currentEx.restSeconds;
                                _startRestTimer(restSec);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 12, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rest (${currentEx.rest ?? "60s"})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentEx.sets,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final isDone = _completedSets[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.emerald.withValues(alpha: 0.08)
                                : context.cardElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDone
                                  ? AppTheme.emerald.withValues(alpha: 0.4)
                                  : context.borderCol,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? AppTheme.emerald
                                      : context.cardBg,
                                  shape: BoxShape.circle,
                                ),
                                child: isDone
                                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                                    : Text(
                                        '${idx + 1}',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: context.textSecondary,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Set ${idx + 1}',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: context.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Target: ${currentEx.reps} reps',
                                      style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: isDone ? null : () => _completeSet(idx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDone ? context.cardBg : context.brandAccent,
                                  foregroundColor: isDone ? AppTheme.emerald : context.onBrandAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  isDone ? 'Done ✓' : 'Complete',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Coach Bhagirath Protocol Card - Placed at the bottom so it does not obstruct the video demo and working sets
                    CoachProtocolCard(exercise: currentEx),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Footer (Luxury Dark Action Bar)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: context.cardElevated,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Previous Exercise Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _currentExerciseIndex > 0 ? _prevExercise : null,
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: _currentExerciseIndex > 0
                                    ? context.cardBg
                                    : context.cardBg.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _currentExerciseIndex > 0
                                      ? context.borderCol
                                      : context.borderCol.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                    color: _currentExerciseIndex > 0
                                        ? context.textPrimary
                                        : context.textMuted.withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Previous',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: _currentExerciseIndex > 0
                                            ? context.textPrimary
                                            : context.textMuted.withValues(alpha: 0.35),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Next Exercise / Finish Workout Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _nextExercise,
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                gradient: allSetsDone
                                    ? LinearGradient(
                                        colors: [
                                          context.brandAccent,
                                          context.brandAccent.withValues(alpha: 0.88),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: allSetsDone ? null : context.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: allSetsDone
                                      ? context.brandAccent
                                      : context.brandAccent.withValues(alpha: 0.6),
                                  width: allSetsDone ? 1.5 : 1.2,
                                ),
                                boxShadow: allSetsDone
                                    ? [
                                        BoxShadow(
                                          color: context.brandAccent.withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isLastExercise ? 'Finish Workout' : 'Next Exercise',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: allSetsDone
                                            ? context.onBrandAccent
                                            : context.textPrimary,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLastExercise
                                        ? Icons.check_circle_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: allSetsDone
                                        ? context.onBrandAccent
                                        : context.brandAccent,
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
            ),
          ],
        ),
      ),
    );
  }
}
