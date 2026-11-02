import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/supabase_service.dart';
import 'package:incline_app/core/services/watch_sync_service.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/components/activity_bento_grid.dart';
import 'package:incline_app/features/home/components/health_goals_sheet.dart';
import 'package:incline_app/features/activity/activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Health Telemetry & Target Customization Tests', () {
    test('WatchSyncData calculates progress accurately without hardcoded values', () {
      final data = WatchSyncData(
        steps: 7500,
        goalSteps: 10000,
        activeCalories: 600,
        goalCalories: 800,
        heartRate: 75,
        sleepHours: 7.0,
        goalSleepHours: 8.0,
        workoutMinutes: 45,
        goalWorkoutMinutes: 60,
        lastSyncTime: DateTime(2026, 10, 21),
      );

      expect(data.stepProgress, closeTo(0.75, 0.01));
      expect(data.caloriesProgress, closeTo(0.75, 0.01));
      expect(data.sleepProgress, closeTo(0.875, 0.01));
      expect(data.workoutProgress, closeTo(0.75, 0.01));
      expect(data.hasSyncedToday, isFalse);
    });

    test('WatchSyncService persists and updates goals in SharedPreferences', () async {
      final service = WatchSyncService.instance;
      await service.updateGoals(
        steps: 12500,
        calories: 900,
        sleepHours: 8.5,
        workoutMinutes: 75,
      );

      expect(service.data.goalSteps, 12500);
      expect(service.data.goalCalories, 900);
      expect(service.data.goalSleepHours, 8.5);
      expect(service.data.goalWorkoutMinutes, 75);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('health_goal_steps'), 12500);
      expect(prefs.getInt('health_goal_calories'), 900);
      expect(prefs.getDouble('health_goal_sleep'), 8.5);
      expect(prefs.getInt('health_goal_workout_min'), 75);
    });

    test('WatchSyncService logs sleep duration and marks synced', () async {
      final service = WatchSyncService.instance;
      await service.logSleep(hours: 7.8);

      expect(service.data.sleepHours, 7.8);
      expect(service.data.isManualSleep, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('health_today_sleep'), 7.8);
    });

    test('WatchSyncService syncNow is safe and completes without errors', () async {
      final service = WatchSyncService.instance;
      await service.syncNow();

      expect(service.isSyncing, isFalse);
    });
  });

  group('Smart Attendance Routine & Motivational Reminder Tests', () {
    test('analyzeMemberAttendance calculates consecutive streak and habitual time', () async {
      final analysis = await SupabaseService.instance.analyzeMemberAttendance('test_member');

      expect(analysis.habitualTime, isNotEmpty);
      expect(analysis.weekActivity.length, 7);
      expect(analysis.motivationTitle, isNotEmpty);
      expect(analysis.motivationMessage, isNotEmpty);
      expect(analysis.motivationUrgency, anyOf('gentle', 'habitual', 'urgent_evening', 'completed'));
    });

    test('recordCheckIn immediately protects streak and updates attendance', () async {
      final success = await SupabaseService.instance.recordCheckIn('test_member');
      expect(success, isTrue);

      final analysis = await SupabaseService.instance.analyzeMemberAttendance('test_member');
      expect(analysis.isVisitedToday, isTrue);
      expect(analysis.motivationUrgency, 'completed');
      expect(analysis.motivationTitle, contains('Streak Protected'));
    });

    test('fetchNotifications adheres to zero-mock policy and returns empty list when no notifications exist', () async {
      final notifs = await SupabaseService.instance.fetchNotifications('test_member');
      expect(notifs, isEmpty);
    });
  });

  group('Widget UI/UX Tests', () {
    testWidgets('ActivityBentoGrid displays 4 tiles: Kcal, Steps, Workout, Sleep', (tester) async {
      const metrics = DailyActivityMetrics(
        activeCalories: 520,
        targetCalories: 800,
        stepCount: 9200,
        targetSteps: 12000,
        workoutMinutes: 50,
        targetMinutes: 60,
        sleepHours: 7.2,
        targetSleepHours: 8.0,
        heartRateBpm: 76,
        heartRateZone: 'Resting Focus',
        hasSyncedToday: true,
      );

      bool setGoalsTapped = false;
      bool syncTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ActivityBentoGrid(
              metrics: metrics,
              onSetGoalsTap: () => setGoalsTapped = true,
              onSyncTap: () => syncTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE CALORIES'), findsOneWidget);
      expect(find.text('520'), findsOneWidget);
      expect(find.text('DAILY STEPS'), findsOneWidget);
      expect(find.text('9.2k'), findsOneWidget);
      expect(find.text('WORKOUT TIME'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('SLEEP & RECOVERY'), findsOneWidget);
      expect(find.text('7.2'), findsOneWidget);
      expect(find.textContaining('Sleep tracked'), findsOneWidget);

      // Verify Set Goals and Sync action controls
      expect(find.text('Targets'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);

      await tester.tap(find.text('Targets'));
      expect(setGoalsTapped, isTrue);

      await tester.tap(find.text('Sync'));
      expect(syncTapped, isTrue);
    });

    testWidgets('HealthGoalsSheet allows target adjustments and sleep logging', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => HealthGoalsSheet.show(ctx),
                child: const Text('Open Goals'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Goals'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Targets & Goals'), findsOneWidget);
      expect(find.text('DAILY STEP TARGET'), findsOneWidget);
      expect(find.text('ACTIVE CALORIES BURN'), findsOneWidget);
      expect(find.text('REST & SLEEP TARGET'), findsOneWidget);
      expect(find.text('DAILY WORKOUT TIME'), findsOneWidget);

      // Tap preset pill 12k for steps
      await tester.tap(find.text('12k'));
      await tester.pump();
      expect(find.text('12000 steps'), findsOneWidget);

      // Scroll to and tap Log Sleep button
      final logSleepFinder = find.text('Log Sleep');
      await tester.scrollUntilVisible(logSleepFinder, 100);
      await tester.pumpAndSettle();
      await tester.tap(logSleepFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(WatchSyncService.instance.data.isManualSleep, isTrue);
      expect(WatchSyncService.instance.data.sleepHours, 7.8);
    });

    testWidgets('ActivityScreen renders without crashing and shows activity grid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ActivityScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Activity screen and bento grid are present
      expect(find.byType(ActivityBentoGrid), findsOneWidget);
      expect(find.text('DAILY TELEMETRY & BIOMETRICS'), findsOneWidget);
    });
  });
}
