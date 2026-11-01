import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/workout/workout_screen.dart';
import 'package:incline_app/features/workout/workout_execution_sheet.dart';

void main() {
  group('Workout Plan & Machine Architecture Tests', () {
    test('Advance Fitness Workout Program loads all 7 days with machines and rest periods', () {
      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      expect(plan.planName, equals('Advance Fitness Workout Program'));
      expect(plan.isPersonalTraining, isFalse);
      expect(plan.days.length, equals(7));

      // Day 1: Monday - Upper Body Strength
      final monday = plan.days[0];
      expect(monday.dayLabel, equals('Monday'));
      expect(monday.focus, equals('Upper Body Strength'));
      expect(monday.isRest, isFalse);
      expect(monday.warmUp, contains('dynamic stretching'));
      expect(monday.coolDown, contains('static stretching'));
      expect(monday.exercises.length, equals(6));

      // Verify specific machine names from PDF
      final chestPress = monday.exercises[0];
      expect(chestPress.name, equals('Chest Press'));
      expect(chestPress.machineName, equals('SUPER HORIZONTAL MULTI PRESS'));
      expect(chestPress.rest, equals('90s'));
      expect(chestPress.restSeconds, equals(90));
      expect(chestPress.coachCue, contains('Control the descent'));

      final latPulldown = monday.exercises[1];
      expect(latPulldown.name, equals('Lat Pulldown'));
      expect(latPulldown.machineName, equals('Lat pulldown'));
      expect(latPulldown.rest, equals('90s'));

      // Day 2: Tuesday - Lower Body & Core
      final tuesday = plan.days[1];
      expect(tuesday.dayLabel, equals('Tuesday'));
      expect(tuesday.exercises[0].name, equals('Leg Press'));
      expect(tuesday.exercises[0].machineName, equals('SUPER LEG PRESS 45°'));
      expect(tuesday.exercises[0].rest, equals('90s'));

      // Day 4: Thursday - Upper Body Strength with Pec Deck
      final thursday = plan.days[3];
      expect(thursday.exercises.any((e) => e.machineName == 'PEC DECK MACHINE'), isTrue);
      expect(thursday.exercises.any((e) => e.machineName == 'Super inclined bench press'), isTrue);

      // Day 5: Friday - Lower Body Strength with Hack Squat
      final friday = plan.days[4];
      expect(friday.exercises[0].machineName, equals('Hack Squat'));

      // Day 7: Sunday - Rest Day
      final sunday = plan.days[6];
      expect(sunday.isRest, isTrue);
    });

    testWidgets('WorkoutScreen renders General Program banner and exercises with machine names', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final generalPlan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: generalPlan,
              initialTab: 0,
              initialDayIndex: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Streamlined Workout Tab (Tab 0): Weekly Schedule rail, machine names, and Training Wisdom Collage
      expect(find.text('WEEKLY SCHEDULE'), findsOneWidget);
      expect(find.text('WARM-UP PROTOCOL'), findsOneWidget);
      expect(find.text('Chest Press'), findsOneWidget);
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);
      expect(find.text('Lat Pulldown'), findsOneWidget);
      expect(find.text('Lat pulldown'), findsOneWidget);
      expect(find.text('90s'), findsWidgets);
      expect(find.text('COOL-DOWN & MOBILITY FLUSH'), findsOneWidget);
      expect(find.text('TRAINING WISDOM & PROTOCOLS'), findsOneWidget);
      expect(find.text("DO'S"), findsOneWidget);
      expect(find.text("DON'TS"), findsOneWidget);

      // Now tap into the dedicated 4th Tab: "Coach" (Single Source of Truth)
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      // Verify Coach hero card, GENERAL badge, Call Coach, Upgrade
      expect(find.text('GENERAL TRAINING PROGRAM'), findsOneWidget);
      expect(find.text('INCLUDED WITH MEMBERSHIP'), findsOneWidget);
      expect(find.text('Call Coach'), findsOneWidget);
      expect(find.text('Upgrade to Personal Training'), findsOneWidget);
      // Verify random blueprints, PDFs, and tiers are completely removed from Coach tab
      expect(find.text('Advance Metabolic Fuel Program'), findsNothing);
      expect(find.text('OFFICIAL PROGRAM BLUEPRINTS & PDFS'), findsNothing);
      expect(find.text('MEMBERSHIP TIERS & INCLUSIONS'), findsNothing);
      expect(find.text('Request Custom Diet & Workout Plan'), findsNothing);
    });

    testWidgets('WorkoutScreen auto-populates custom assigned workout plan name from backend', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final customAssignedPlan = WorkoutPlan(
        id: 'plan_custom_mohit_99',
        planName: 'Bespoke Hypertrophy Split 2026',
        description: 'Bespoke plan assigned by Coach Bhagirath.',
        trainerName: 'Coach Bhagirath Gurjar',
        targetGoal: 'Hypertrophy & Physique Building',
        days: InclineGeneralPrograms.advanceFitnessWorkoutProgram.days,
        isCustomAssigned: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: customAssignedPlan,
              initialTab: 3,
              initialDayIndex: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify coach, call, and upgrade in Coach tab
      expect(find.text('Coach Bhagirath Gurjar'), findsOneWidget);
      expect(find.text('Call Coach'), findsOneWidget);
      expect(find.text('Upgrade to Personal Training'), findsOneWidget);

      // Switch to Tab 0 (Workout) to verify plan exercises are rendered
      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY SCHEDULE'), findsOneWidget);
      expect(find.text('Chest Press'), findsWidgets);
    });

    testWidgets('WorkoutScreen renders authentic empty state and Coach view when no plan is assigned', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: null,
              initialTab: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tab 0: Empty Workout View (Coach photo and Upgrade button shifted to Coach tab)
      expect(find.text('No Active Workout Plan'), findsOneWidget);
      expect(find.text('Request Workout Plan'), findsOneWidget);
      expect(find.text('Upgrade to 1:1 Personal Training'), findsNothing);

      // Tap Tab 3: Coach
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      // Tab 3: Coach View (Single Source of Truth)
      expect(find.text('GENERAL TRAINING PROGRAM'), findsOneWidget);
      expect(find.text('Coach Bhagirath Gurjar'), findsOneWidget);
      expect(find.text('Call Coach'), findsOneWidget);
      expect(find.text('Upgrade to Personal Training'), findsOneWidget);
      // Verify unassigned prompt, blueprints, and tiers are completely removed from Coach tab
      expect(find.text('NO ACTIVE PLAN ASSIGNED'), findsNothing);
      expect(find.text('Request Diet & Workout Plan'), findsNothing);
      expect(find.text('MEMBERSHIP TIERS & INCLUSIONS'), findsNothing);
      expect(find.text('OFFICIAL PROGRAM BLUEPRINTS & PDFS'), findsNothing);
    });

    testWidgets('WorkoutExecutionSheet shows exercise, machine name, and rest timer trigger', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final monday = InclineGeneralPrograms.advanceFitnessWorkoutProgram.days[0];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: monday,
              initialExerciseIndex: 0,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );

      // Pump frames (avoid pumpAndSettle due to repeating visualizer animation)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check exercise title and machine name in visualizer
      expect(find.text('Chest Press'), findsOneWidget);
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);

      // Check rest trigger pill in sets header
      expect(find.text('TRACK WORKING SETS'), findsOneWidget);
      expect(find.text('Rest (90s)'), findsOneWidget);

      // Ensure rest trigger pill is visible in scrollable sheet before tapping
      await tester.ensureVisible(find.text('Rest (90s)'));
      await tester.pump();

      // Tap rest trigger pill
      await tester.tap(find.text('Rest (90s)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Rest Period active banner appears
      expect(find.text('Rest Period Active'), findsOneWidget);
      expect(find.text('Skip Rest'), findsOneWidget);
    });

    test('WorkoutExercise.fromJson preserves all backend schema fields', () {
      final json = {
        'name': 'Incline Dumbbell Press',
        'sets': 4,
        'reps': '8-10',
        'rest_seconds': 90,
        'equipment': 'Incline Adjustable Bench',
        'form_tips': ['Keep shoulder blades retracted', 'Elbows at 45 degrees'],
        'weight': '32kg',
        'video_url': 'https://incline.fit/demos/incline_press.mp4',
        'notes': '3-1-1 tempo',
      };

      final exercise = WorkoutExercise.fromJson(json);
      expect(exercise.name, equals('Incline Dumbbell Press'));
      expect(exercise.sets, equals(4));
      expect(exercise.reps, equals('8-10'));
      expect(exercise.rest, equals('90s'));
      expect(exercise.restSeconds, equals(90));
      expect(exercise.machineName, equals('Incline Adjustable Bench'));
      expect(exercise.coachCue, equals('Keep shoulder blades retracted • Elbows at 45 degrees'));
      expect(exercise.load, equals('32kg'));
      expect(exercise.videoUrl, equals('https://incline.fit/demos/incline_press.mp4'));
      expect(exercise.notes, equals('3-1-1 tempo'));
    });

    testWidgets('Progress tab removes redundant Active Health Goals card and opens RecordMeasurementSheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: WorkoutScreen(
              initialTab: 2, // Progress tab
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify redundant Active Health Goals card is removed from Progress tab
      expect(find.text('Active Health Goals'), findsNothing);
      expect(find.text('Daily targets from Home'), findsNothing);

      // 2. Verify clean Progress view contains 3D Body Assessment & action buttons
      expect(find.text('Log Manual Body Measurements'), findsOneWidget);

      // 3. Tap Log Manual Body Measurements button and verify RecordMeasurementSheet opens
      await tester.tap(find.text('Log Manual Body Measurements'));
      await tester.pumpAndSettle();

      expect(find.text('Log Body Measurements'), findsOneWidget);
      expect(find.text('Track Weight, Body Fat & Circumferences'), findsOneWidget);
      expect(find.text('Current Weight (kg) *'), findsOneWidget);
      expect(find.text('Save Biometric Record'), findsOneWidget);
    });
  });
}
