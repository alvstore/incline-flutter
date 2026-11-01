import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/offline_sync_service.dart';
import 'package:incline_app/core/services/push_notification_service.dart';
import 'package:incline_app/features/diet/widgets/water_intake_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Sync & Persistent Device Caching Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('OfflineSyncService stores and retrieves WorkoutPlan with versionTag', () async {
      final sync = OfflineSyncService.instance;

      final exercise = WorkoutExercise(
        name: 'Incline Dumbbell Press',
        sets: 4,
        reps: '8-10',
        rest: '90s',
        machineName: 'Olympic Incline Bench',
      );

      final day = WorkoutDay(
        id: 'day_1',
        dayLabel: 'Chest Hypertrophy',
        exercises: [exercise],
      );

      final plan = WorkoutPlan(
        id: 'plan_abc123',
        planName: 'Elite Push Focus',
        trainerName: 'Coach Vikram',
        days: [day],
      );

      await sync.cacheWorkoutPlan(plan, versionTag: 'plan_abc123_20261029');

      final cached = await sync.getCachedWorkoutPlan();
      final version = await sync.getWorkoutPlanVersion();

      expect(cached, isNotNull);
      expect(cached!.id, equals('plan_abc123'));
      expect(cached.planName, equals('Elite Push Focus'));
      expect(cached.days.length, equals(1));
      expect(cached.days[0].exercises[0].name, equals('Incline Dumbbell Press'));
      expect(version, equals('plan_abc123_20261029'));
    });

    test('OfflineSyncService stores and retrieves MemberDietPlan with versionTag', () async {
      final sync = OfflineSyncService.instance;

      const food = MealFoodItem(
        name: 'Grass-Fed Whey & Oats',
        quantity: '1 Bowl',
        calories: 380,
        protein: 36,
        carbs: 45,
        fats: 6,
      );

      final meal = DietMeal(
        id: 'm_postworkout',
        name: 'Post-Workout Fuel',
        time: '10:30 AM',
        targetCalories: 380,
        targetProtein: 36,
        targetCarbs: 45,
        targetFats: 6,
        items: const [food],
      );

      final dayPlan = DietDayPlan(
        dayLabel: 'High Fuel Day',
        weekdayIndex: 1,
        targetCalories: 2600,
        targetProtein: 190,
        targetCarbs: 280,
        targetFats: 70,
        meals: [meal],
      );

      final dietPlan = MemberDietPlan(
        id: 'diet_xyz789',
        planName: 'Lean Hypertrophy Fuel',
        nutritionistName: 'Lead Sports Nutritionist',
        days: [dayPlan],
      );

      await sync.cacheDietPlan(dietPlan, versionTag: 'diet_xyz789_v2');

      final cached = await sync.getCachedDietPlan();
      final version = await sync.getDietPlanVersion();

      expect(cached, isNotNull);
      expect(cached!.id, equals('diet_xyz789'));
      expect(cached.planName, equals('Lean Hypertrophy Fuel'));
      expect(cached.days.length, equals(1));
      expect(cached.days[0].meals[0].items[0].name, equals('Grass-Fed Whey & Oats'));
      expect(version, equals('diet_xyz789_v2'));
    });

    test('OfflineSyncService persists daily water intake per member and IST date', () async {
      final sync = OfflineSyncService.instance;

      await sync.cacheWaterIntake('mem_999', '2026-10-29', 1750);
      final logged = await sync.getCachedWaterIntake('mem_999', '2026-10-29');

      expect(logged, equals(1750));
    });

    test('OfflineSyncService caches and restores Member profile for instant startup', () async {
      final sync = OfflineSyncService.instance;

      const profile = Profile(
        id: 'usr_001',
        fullName: 'Arjun Singhania',
        email: 'arjun@incline.club',
      );

      const member = Member(
        id: 'mem_001',
        memberCode: 'INC-2026-VIP',
        profile: profile,
      );

      await sync.cacheCurrentMember(member);
      final cachedMember = await sync.getCachedCurrentMember();

      expect(cachedMember, isNotNull);
      expect(cachedMember!.memberCode, equals('INC-2026-VIP'));
      expect(cachedMember.fullName, equals('Arjun Singhania'));
    });
  });

  group('Hydration Push Reminders & WaterIntakeCard UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PushNotificationService manages hydration notification preferences', () async {
      final push = PushNotificationService.instance;

      // Default should be enabled
      expect(await push.isHydrationRemindersEnabled(), isTrue);

      await push.setHydrationRemindersEnabled(false);
      expect(await push.isHydrationRemindersEnabled(), isFalse);

      await push.setHydrationRemindersEnabled(true);
      expect(await push.isHydrationRemindersEnabled(), isTrue);
    });

    testWidgets('WaterIntakeCard renders reminders bar and triggers quick logging', (tester) async {
      int recordedDelta = 0;
      bool wasReset = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaterIntakeCard(
              currentMl: 1250,
              targetMl: 3500,
              onAddWater: (delta) => recordedDelta = delta,
              onReset: () => wasReset = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Metrics
      expect(find.text('DAILY HYDRATION'), findsOneWidget);
      expect(find.text('1.3'), findsOneWidget); // 1250 / 1000 = 1.3 L
      expect(find.text(' / 3.5 L'), findsOneWidget);

      // Verify Hydration Push Notification Bar
      expect(find.text('Hydration Push Reminders'), findsOneWidget);
      expect(find.text('Test Alert'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Test +250ml Tap
      await tester.tap(find.text('+250 ml (Glass)'));
      expect(recordedDelta, equals(250));

      // Test +500ml Tap
      await tester.tap(find.text('+500 ml (Shaker)'));
      expect(recordedDelta, equals(500));

      // Test Reset Button Tap
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(wasReset, isTrue);
    });
  });
}
