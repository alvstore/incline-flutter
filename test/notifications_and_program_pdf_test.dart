import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/program_pdf_downloader.dart';
import 'package:incline_app/features/workout/workout_execution_sheet.dart';
import 'package:incline_app/features/workout/animated_exercise_visualizer.dart';
import 'package:incline_app/features/notifications/notifications_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Program PDF Downloader & In-App Synthesis Tests', () {
    test('generateAuthoritativePdf generates valid PDF bytes for workout plan without web redirects', () async {
      final workoutPlan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      final Uint8List pdfBytes = await ProgramPdfDownloader.generateAuthoritativePdf(
        title: workoutPlan.planName,
        docId: workoutPlan.docId,
        workoutPlan: workoutPlan,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF header magic bytes %PDF
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('generateAuthoritativePdf generates valid PDF bytes for diet plan', () async {
      final dietPlan = MemberDietPlan(
        id: 'diet_test_01',
        planName: 'Elite Hypertrophy Clean Fuel',
        description: 'High-protein whole-food nutrition protocol',
        nutritionistName: 'Coach Bhagirath Gurjar',
        days: [
          DietDayPlan(
            dayLabel: 'Monday',
            weekdayIndex: 1,
            targetCalories: 2850,
            targetProtein: 210,
            targetCarbs: 310,
            targetFats: 70,
            meals: [
              DietMeal(
                id: 'm1',
                name: 'Pre-Workout Fuel',
                time: '07:30 AM',
                targetCalories: 520,
                targetProtein: 42,
                targetCarbs: 65,
                targetFats: 10,
                items: [
                  MealFoodItem(
                    name: 'Oats with Whey',
                    quantity: '80g oats, 1 scoop whey',
                    calories: 520,
                    protein: 42,
                    carbs: 65,
                    fats: 10,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final Uint8List pdfBytes = await ProgramPdfDownloader.generateAuthoritativePdf(
        title: dietPlan.planName,
        docId: dietPlan.id,
        dietPlan: dietPlan,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });
  });

  group('Workout Execution Visualizer - Static High-End BentoCard Tests', () {
    testWidgets('AnimatedExerciseVisualizer renders static protocol cards without animation loops', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final chestPress = InclineGeneralPrograms.advanceFitnessWorkoutProgram.days[0].exercises[0];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedExerciseVisualizer(
                  exercise: chestPress,
                  exerciseIndex: 0,
                  totalExercises: 6,
                  isResting: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify static elements
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);
      expect(find.text('Chest Press'), findsOneWidget);
      expect(find.text('REST: 90s'), findsOneWidget);
      expect(find.text('TARGET MUSCLE ACTIVATION'), findsOneWidget);
      expect(find.text('Clavicular Pectoralis (Upper Chest)'), findsOneWidget);
      expect(find.text('COACH BHAGIRATH PROTOCOL'), findsOneWidget);

      // Verify that pumpAndSettle completes without timing out (no infinite tickers!)
      await tester.pumpAndSettle();
    });

    testWidgets('WorkoutExecutionSheet settles instantly with zero ticker animations', (tester) async {
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

      // pumpAndSettle now works cleanly because infinite stick-figure animation is eliminated
      await tester.pumpAndSettle();

      expect(find.text('Chest Press'), findsOneWidget);
      expect(find.text('COACH BHAGIRATH PROTOCOL'), findsOneWidget);
      expect(find.text('TRACK WORKING SETS'), findsOneWidget);
    });
  });

  group('Notifications Feed & Category Filter Tests', () {
    testWidgets('NotificationsScreen renders authentic filters and zero-mock empty state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify filter chips exist matching authentic categories
      expect(find.textContaining('All'), findsOneWidget);
      expect(find.text('Club News'), findsOneWidget);
      expect(find.text('Reservations'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      // Verify zero-mock empty state is rendered cleanly without fake quotes
      expect(find.text('Your Inbox is Clear'), findsOneWidget);
      expect(find.textContaining('No notifications or club announcements right now'), findsOneWidget);

      // Tap 'Club News' filter chip (visible in horizontal bar)
      await tester.tap(find.text('Club News'));
      await tester.pumpAndSettle();

      // Verify category-specific zero-mock empty state
      expect(find.text('No Bulletins in this Category'), findsOneWidget);
    });
  });
}
