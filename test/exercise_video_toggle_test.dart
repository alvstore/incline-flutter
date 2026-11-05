import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/config/env_config.dart';
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

  group('Exercise Video & Media Model Normalization Tests', () {
    test('WorkoutExercise normalizes relative video paths to Supabase storage endpoint', () {
      final jsonRelative = {
        'name': 'Chest Press',
        'sets': 3,
        'reps': '10-12',
        'video_url': 'exercises/chest_press.mp4',
        'image_url': 'https://inclinegym.com/images/chest_press.jpg',
      };

      final exercise = WorkoutExercise.fromJson(jsonRelative);
      expect(
        exercise.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/exercises/chest_press.mp4'),
      );
      expect(exercise.imageUrl, equals('https://inclinegym.com/images/chest_press.jpg'));
    });

    test('WorkoutExercise normalizes relative paths with leading slash and supports video_file_path', () {
      final jsonLeadingSlash = {
        'name': 'Lat Pulldown',
        'sets': 4,
        'reps': '10',
        'video_file_path': '/exercises/lat_pulldown.mp4',
        'photo_url': 'https://inclinegym.com/photos/lat_pulldown.jpg',
      };

      final exercise = WorkoutExercise.fromJson(jsonLeadingSlash);
      expect(
        exercise.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/exercises/lat_pulldown.mp4'),
      );
      expect(exercise.imageUrl, equals('https://inclinegym.com/photos/lat_pulldown.jpg'));
    });

    test('WorkoutExercise preserves absolute HTTP/HTTPS video URLs', () {
      final jsonAbsolute = {
        'name': 'Barbell Squat',
        'sets': 5,
        'reps': '5',
        'video_url': 'https://cdn.inclinegym.com/videos/squat_075x.mp4',
        'thumbnail_url': 'https://cdn.inclinegym.com/thumbnails/squat.jpg',
      };

      final exercise = WorkoutExercise.fromJson(jsonAbsolute);
      expect(exercise.videoUrl, equals('https://cdn.inclinegym.com/videos/squat_075x.mp4'));
      expect(exercise.imageUrl, equals('https://cdn.inclinegym.com/thumbnails/squat.jpg'));
    });

    test('WorkoutExercise handles null or empty video and image gracefully and serializes toJson', () {
      final jsonEmpty = {
        'name': 'Plank',
        'sets': 3,
        'reps': '60s',
      };

      final exercise = WorkoutExercise.fromJson(jsonEmpty);
      expect(exercise.videoUrl, isNull);
      expect(exercise.imageUrl, isNull);

      final serialized = exercise.toJson();
      expect(serialized['video_url'], isNull);
      expect(serialized['image_url'], isNull);
      expect(serialized['name'], equals('Plank'));

      // Roundtrip test with values
      final exerciseWithMedia = WorkoutExercise(
        name: 'Incline Dumbbell Press',
        sets: 4,
        reps: '8-10',
        videoUrl: 'https://inclinegym.com/demo.mp4',
        imageUrl: 'https://inclinegym.com/thumb.jpg',
      );
      final roundtripMap = exerciseWithMedia.toJson();
      expect(roundtripMap['video_url'], equals('https://inclinegym.com/demo.mp4'));
      expect(roundtripMap['image_url'], equals('https://inclinegym.com/thumb.jpg'));

      final restored = WorkoutExercise.fromJson(roundtripMap);
      expect(restored.name, equals('Incline Dumbbell Press'));
      expect(restored.videoUrl, equals('https://inclinegym.com/demo.mp4'));
      expect(restored.imageUrl, equals('https://inclinegym.com/thumb.jpg'));
    });
  });

  group('OfflineSyncService Exercise Video Demos Preference Tests', () {
    test('Preference is false (OFF) by default matching web specification', () async {
      SharedPreferences.setMockInitialValues({});
      final enabled = await OfflineSyncService.instance.getExerciseVideoDemosEnabled();
      expect(enabled, isFalse);
    });

    test('Preference toggles and persists to SharedPreferences key incline_exercise_video_demos_enabled', () async {
      SharedPreferences.setMockInitialValues({});

      await OfflineSyncService.instance.setExerciseVideoDemosEnabled(true);
      expect(await OfflineSyncService.instance.getExerciseVideoDemosEnabled(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('incline_exercise_video_demos_enabled'), isTrue);

      await OfflineSyncService.instance.setExerciseVideoDemosEnabled(false);
      expect(await OfflineSyncService.instance.getExerciseVideoDemosEnabled(), isFalse);
      expect(prefs.getBool('incline_exercise_video_demos_enabled'), isFalse);
    });
  });

  group('AnimatedExerciseVisualizer Video Toggle Behavior Tests', () {
    final testExerciseWithVideo = WorkoutExercise(
      name: 'Chest Press',
      sets: 3,
      reps: '10-12',
      rest: '90s',
      machineName: 'SUPER HORIZONTAL MULTI PRESS',
      videoUrl: 'https://inclinegym.com/videos/chest_press.mp4',
      imageUrl: 'https://inclinegym.com/images/chest_press.jpg',
    );

    testWidgets('When showVideo is false, loads NO video player card and displays static biomechanics guide', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: testExerciseWithVideo,
                exerciseIndex: 0,
                totalExercises: 5,
                showVideo: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero video player card bytes / widget loaded
      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.text('0.75× SLOW-MO'), findsNothing);

      // Static biomechanics & protocol elements rendered
      expect(find.text('Chest Press'), findsOneWidget);
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);
      expect(find.text('TARGET MUSCLE ACTIVATION'), findsOneWidget);
      expect(find.text('COACH BHAGIRATH PROTOCOL'), findsOneWidget);
    });

    testWidgets('When showVideo is true and videoUrl is present, renders luxury ExerciseVideoCard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: testExerciseWithVideo,
                exerciseIndex: 0,
                totalExercises: 5,
                showVideo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // ExerciseVideoCard is displayed
      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.text('Chest Press'), findsWidgets);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Biomechanics guide is still present below the video player
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);
    });

    testWidgets('When showVideo is true but exercise has no videoUrl, does not render ExerciseVideoCard', (tester) async {
      final noVideoExercise = WorkoutExercise(
        name: 'Standing Calf Raise',
        sets: 4,
        reps: '15',
        videoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: noVideoExercise,
                exerciseIndex: 0,
                totalExercises: 1,
                showVideo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.text('Standing Calf Raise'), findsOneWidget);
    });
  });

  group('WorkoutScreen & WorkoutExecutionSheet Backend Toggle Tests', () {
    testWidgets('WorkoutScreen does not display member-facing Demos switch and respects backend exercise state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
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

      // No member-facing Demos switch exists (toggle belongs to backend/admin UI)
      expect(find.text('Demos'), findsNothing);
      expect(find.byType(Switch), findsNothing);

      // Exercise list displays accurately
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);
    });

    testWidgets('WorkoutExecutionSheet has clean AppBar without member toggle button', (tester) async {
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No member-facing media toggle buttons in AppBar
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      // Close button is present
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    test('WorkoutExercise respects backend explicit show_video toggle', () {
      final offJson = {
        'name': 'Barbell Squat',
        'sets': 4,
        'reps': '8',
        'video_url': 'https://example.com/squat.mp4',
        'show_video': false,
      };
      final offEx = WorkoutExercise.fromJson(offJson);
      expect(offEx.showVideo, isFalse);

      final onJson = {
        'name': 'Barbell Squat',
        'sets': 4,
        'reps': '8',
        'video_url': 'https://example.com/squat.mp4',
        'show_video': true,
      };
      final onEx = WorkoutExercise.fromJson(onJson);
      expect(onEx.showVideo, isTrue);
    });

    test('WorkoutExercise respects planVideoToggle false even if exercise has valid video_url', () {
      final json = {
        'name': 'Leg Press',
        'sets': 4,
        'reps': '12',
        'video_url': 'https://example.com/leg_press.mp4',
      };
      final ex = WorkoutExercise.fromJson(json, planVideoToggle: false);
      expect(ex.showVideo, isFalse);
    });

    test('WorkoutPlan serializes and deserializes show_video toggle accurately', () {
      final planOff = WorkoutPlan(
        id: 'p1',
        planName: 'Strength Split',
        days: const [],
        showVideo: false,
      );
      final jsonOff = planOff.toJson();
      expect(jsonOff['show_video'], isFalse);

      final restoredOff = WorkoutPlan.fromJson(jsonOff);
      expect(restoredOff.showVideo, isFalse);

      final planOn = WorkoutPlan(
        id: 'p2',
        planName: 'Hypertrophy Split',
        days: const [],
        showVideo: true,
      );
      final restoredOn = WorkoutPlan.fromJson(planOn.toJson());
      expect(restoredOn.showVideo, isTrue);
    });
  });
}
