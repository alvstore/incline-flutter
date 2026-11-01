import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/offline_sync_service.dart';
import 'package:incline_app/features/workout/animated_exercise_visualizer.dart';
import 'package:incline_app/features/workout/exercise_video_card.dart';
import 'package:incline_app/features/workout/workout_execution_sheet.dart';
import 'package:incline_app/features/workout/workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // 1. COLD START PERSISTENCE & SHARED PREFERENCES HYDRATION
  // =========================================================================
  group('Challenger Stress: Cold Start Persistence & SharedPreferences Hydration', () {
    testWidgets('Cold Start 1: Clean fresh install (no prefs key) defaults to false across all components', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Service verification
      final defaultPref = await OfflineSyncService.instance.getExerciseVideoDemosEnabled();
      expect(defaultPref, isFalse);

      // WorkoutScreen cold start
      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: plan,
              initialTab: 0,
              initialDayIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Demos switch does not exist in member app
      expect(find.text('Demos'), findsNothing);
      expect(find.byType(Switch), findsNothing);

      // WorkoutExecutionSheet cold start
      final day = plan.days[0];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: day,
              initialExerciseIndex: 0,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies AppBar close button is present and member toggle icons are absent
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.image_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    });

    testWidgets('Cold Start 2: Backend-driven video badges render correctly in WorkoutScreen', (tester) async {
      final plan = WorkoutPlan(
        id: 'test_plan',
        planName: 'Test Split',
        description: 'Test',
        trainerName: 'Coach Incline',
        targetGoal: 'Hypertrophy',
        days: [
          WorkoutDay(
            id: 'd1',
            dayLabel: 'Push',
            weekLabel: 'W1',
            focus: 'Chest',
            weekdayIndex: 1,
            warmUp: '',
            coolDown: '',
            exercises: [
              WorkoutExercise(
                name: 'Bench Press',
                sets: 3,
                reps: '10',
                videoUrl: 'https://inclinegym.com/demo.mp4',
                showVideo: true,
              ),
              WorkoutExercise(
                name: 'Push Up',
                sets: 3,
                reps: '15',
                imageUrl: 'https://inclinegym.com/guide.jpg',
                showVideo: false,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: plan,
              initialTab: 0,
              initialDayIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Demos member switch must not exist
      expect(find.byType(Switch), findsNothing);
      // Backend badges (Video / Guide) appear according to exercise.showVideo
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
    });

    testWidgets('Cold Start 3: Backend showVideo: true mounts ExerciseVideoCard in WorkoutExecutionSheet', (tester) async {
      final dayWithVideo = WorkoutDay(
        id: 'adv_day_1',
        dayLabel: 'Monday',
        weekLabel: 'Week 1',
        focus: 'Upper Body Strength',
        weekdayIndex: 1,
        warmUp: '',
        coolDown: '',
        exercises: [
          WorkoutExercise(
            name: 'Chest Press',
            machineName: 'SUPER HORIZONTAL MULTI PRESS',
            sets: 3,
            reps: '10-12',
            rest: '90s',
            videoUrl: 'https://inclinegym.com/demo.mp4',
            showVideo: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: dayWithVideo,
              initialExerciseIndex: 0,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // ExerciseVideoCard is mounted inline, no member toggle in AppBar
      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      expect(find.byIcon(Icons.image_rounded), findsNothing);
    });

    testWidgets('Cold Start 4: Backend showVideo: false renders guide only and omits ExerciseVideoCard', (tester) async {
      final dayNoVideo = WorkoutDay(
        id: 'adv_day_2',
        dayLabel: 'Tuesday',
        weekLabel: 'Week 1',
        focus: 'Lower Body',
        weekdayIndex: 2,
        warmUp: '',
        coolDown: '',
        exercises: [
          WorkoutExercise(
            name: 'Leg Press',
            machineName: 'LEG PRESS 45',
            sets: 4,
            reps: '12',
            rest: '60s',
            videoUrl: 'https://inclinegym.com/demo.mp4',
            showVideo: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: dayNoVideo,
              initialExerciseIndex: 0,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // When showVideo is false, ExerciseVideoCard is omitted
      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    test('Cold Start 5: Corrupted SharedPreferences data does not crash service', () async {
      // Set an invalid non-boolean type in prefs mock
      SharedPreferences.setMockInitialValues({
        'incline_exercise_video_demos_enabled': 'corrupted_string_value',
      });

      // SharedPreferences getBool will throw a TypeError, but OfflineSyncService catches it
      final result = await OfflineSyncService.instance.getExerciseVideoDemosEnabled();
      expect(result, isFalse);
    });
  });

  // =========================================================================
  // 2. EXTREME CONSTRAINT ENVIRONMENTS & SMALL SCREEN LAYOUTS
  // =========================================================================
  group('Challenger Stress: Extreme Constraint Environments & Layout Stress', () {
    final complexExercise = WorkoutExercise(
      name: 'Unilateral Dumbbell Incline Bench Press Extended Contraction',
      sets: 4,
      reps: '12-15 reps (to failure)',
      rest: '90s',
      machineName: 'SUPER LATERAL DUAL-AXIS INCLINE ISO-CHEST MACHINE',
      videoUrl: 'https://inclinegym.com/videos/chest.mp4',
      imageUrl: 'https://inclinegym.com/images/chest.jpg',
    );

    testWidgets('Layout Stress 1: AnimatedExerciseVisualizer under ultra-narrow 280px width (Galaxy Fold outer)', (tester) async {
      tester.view.physicalSize = const Size(280 * 2.0, 650 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: complexExercise,
                exerciseIndex: 0,
                totalExercises: 6,
                showVideo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No overflow exceptions occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(ExerciseVideoCard), findsOneWidget);
    });

    testWidgets('Layout Stress 2: AnimatedExerciseVisualizer under 320x480px with 1.8x text scaler', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 480 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedExerciseVisualizer(
                  exercise: complexExercise,
                  exerciseIndex: 0,
                  totalExercises: 6,
                  showVideo: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('TARGET MUSCLE ACTIVATION'), findsOneWidget);
    });

    testWidgets('Layout Stress 3: ExerciseVideoCard with 2.0x text scale and long title', (tester) async {
      tester.view.physicalSize = const Size(300 * 2.0, 400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 400),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const Scaffold(
              body: Center(
                child: ExerciseVideoCard(
                  videoUrl: 'https://inclinegym.com/demo.mp4',
                  title: 'Extremely Long Exercise Name With Multiple Words That Exceeds Single Line',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('0.75× SLOW-MO'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Layout Stress 4: WorkoutScreen Demos toggle row under tight 320px width', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: plan,
              initialTab: 0,
              initialDayIndex: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Demos'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Layout Stress 5: WorkoutExecutionSheet AppBar under tight 320x480px with 1.8x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 480 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final day = InclineGeneralPrograms.advanceFitnessWorkoutProgram.days[0];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: WorkoutExecutionSheet(
                day: day,
                initialExerciseIndex: 0,
                onExerciseUpdated: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check if AppBar actions render cleanly without member toggle
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.image_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    });
  });

  // =========================================================================
  // 3. MISSING, EMPTY, AND ADVERSARIAL FIELDS ROBUSTNESS
  // =========================================================================
  group('Challenger Stress: Missing, Empty & Malformed Fields Handling', () {
    testWidgets('Missing Fields 1: AnimatedExerciseVisualizer with completely empty strings and nulls', (tester) async {
      final blankExercise = WorkoutExercise(
        name: '', // Empty name
        sets: 0,
        reps: '',
        rest: null,
        machineName: null,
        coachCue: null,
        notes: null,
        videoUrl: null,
        imageUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: blankExercise,
                exerciseIndex: 0,
                totalExercises: 1,
                showVideo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify no video card rendered when videoUrl is null
      expect(find.byType(ExerciseVideoCard), findsNothing);

      // Verify machine badge is omitted when machineName is null
      expect(find.byIcon(Icons.precision_manufacturing_rounded), findsNothing);

      // Verify fallback biomechanics profile displayed
      expect(find.text('TARGET MUSCLE ACTIVATION'), findsOneWidget);
    });

    testWidgets('Missing Fields 2: Exercise with empty string machineName omits badge', (tester) async {
      final emptyMachineExercise = WorkoutExercise(
        name: 'Standing Calf Raise',
        sets: 3,
        reps: '15',
        machineName: '', // Empty string
        videoUrl: 'https://inclinegym.com/demo.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: emptyMachineExercise,
                exerciseIndex: 0,
                totalExercises: 1,
                showVideo: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.precision_manufacturing_rounded), findsNothing);
    });

    testWidgets('Missing Fields 3: ExerciseVideoCard handles null title and empty videoUrl gracefully on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseVideoCard(
              videoUrl: '', // empty
              title: null,  // null title
              thumbnailUrl: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title fallback
      expect(find.text('Form video · 0.75×'), findsOneWidget);

      // Tapping play button on empty videoUrl shows SnackBar instead of throwing
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Video demo URL is unavailable'), findsOneWidget);
    });

    testWidgets('Missing Fields 4: ExerciseVideoCard handles invalid malformed URI string without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseVideoCard(
              videoUrl: 'ht tp://invalid uri with spaces',
              title: 'Invalid URL Test',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap play button
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should not throw unhandled exception
      expect(tester.takeException(), isNull);
    });

    test('Missing Fields 5: WorkoutExercise.fromJson with completely empty or malformed map', () {
      final emptyJson = <String, dynamic>{};
      final ex = WorkoutExercise.fromJson(emptyJson);

      expect(ex.name, equals('Exercise'));
      expect(ex.sets, equals(3));
      expect(ex.reps, equals('10-12'));
      expect(ex.rest, equals('60s'));
      expect(ex.videoUrl, isNull);
      expect(ex.imageUrl, isNull);
      expect(ex.machineName, isNull);
      expect(ex.isCompleted, isFalse);

      final weirdTypesJson = {
        'name': 12345.toString(),
        'sets': '5',
        'reps': 15,
        'video_url': '   ',
        'image_url': null,
      };
      final exWeird = WorkoutExercise.fromJson(weirdTypesJson);
      expect(exWeird.name, equals('12345'));
      expect(exWeird.videoUrl, isNull); // whitespace trimmed to null
    });
  });
}
