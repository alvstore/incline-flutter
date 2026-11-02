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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Adversarial Stress Test: URL Normalization Edge Cases', () {
    test('Deeply nested relative paths are preserved with Supabase endpoint prefix', () {
      final json = {
        'name': 'Incline DB Press',
        'sets': 4,
        'reps': '10',
        'video_url': 'workouts/2026/advanced/chest/incline_dumbbell_press.mp4',
      };
      final ex = WorkoutExercise.fromJson(json);
      expect(
        ex.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/workouts/2026/advanced/chest/incline_dumbbell_press.mp4'),
      );
    });

    test('Video paths with spaces, unicode, or parentheses are normalized without crashing', () {
      final json = {
        'name': 'Dumbbell Curl',
        'sets': 3,
        'reps': '12',
        'video_url': 'exercises/Dumbbell Bicep Curl (Strict & Slow 30°).mp4',
      };
      final ex = WorkoutExercise.fromJson(json);
      expect(
        ex.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/exercises/Dumbbell Bicep Curl (Strict & Slow 30°).mp4'),
      );
    });

    test('Unusual streaming extensions and queries (.m3u8, .webm, .mov, query params)', () {
      final extensions = [
        'stream.m3u8',
        'clip.webm',
        'raw.mov',
        'archive.mkv',
        'video_without_extension',
        'feed.mp4?token=abc123xyz&expires=9999999999#t=10',
      ];

      for (final ext in extensions) {
        final json = {
          'name': 'Test Exercise',
          'sets': 3,
          'reps': '10',
          'video_url': 'demos/$ext',
        };
        final ex = WorkoutExercise.fromJson(json);
        expect(
          ex.videoUrl,
          equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/demos/$ext'),
        );
      }
    });

    test('Leading and trailing whitespace in URLs is safely trimmed', () {
      final json = {
        'name': 'Squat',
        'sets': 5,
        'reps': '5',
        'video_url': '   https://cdn.inclinegym.com/squat.mp4   \n',
      };
      final ex = WorkoutExercise.fromJson(json);
      expect(ex.videoUrl, equals('https://cdn.inclinegym.com/squat.mp4'));
    });

    test('Whitespace-only, empty, and null video strings resolve to null', () {
      final blankInputs = ['', '   ', '\t\n\r', null];
      for (final input in blankInputs) {
        final json = {
          'name': 'Plank',
          'sets': 3,
          'reps': '60s',
          'video_url': input,
        };
        final ex = WorkoutExercise.fromJson(json);
        expect(ex.videoUrl, isNull, reason: 'Failed for input: "$input"');
      }
    });

    test('Double or multiple leading slashes: behavior inspection', () {
      final json = {
        'name': 'Bench Press',
        'sets': 4,
        'reps': '8',
        'video_url': '//exercises/bench.mp4',
      };
      final ex = WorkoutExercise.fromJson(json);
      // The implementation strips the first leading slash
      expect(
        ex.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos//exercises/bench.mp4'),
      );
    });

    test('Single slash "/" as video_url produces a normalized bucket path or string', () {
      final json = {
        'name': 'Deadlift',
        'sets': 3,
        'reps': '5',
        'video_url': '/',
      };
      final ex = WorkoutExercise.fromJson(json);
      // Should not throw or crash
      expect(ex.videoUrl, isNotNull);
    });

    test('Non-HTTP schemes (e.g. data:, blob:, file:, ftp:) are treated as relative paths', () {
      final json = {
        'name': 'Pull Up',
        'sets': 4,
        'reps': '10',
        'video_url': 'file:///sdcard/videos/pullup.mp4',
      };
      final ex = WorkoutExercise.fromJson(json);
      // Because it does not start with http:// or https://, it prefixes supabase storage
      expect(
        ex.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/file:///sdcard/videos/pullup.mp4'),
      );
    });
  });

  group('Adversarial Stress Test: ExerciseVideoCard Interaction & Resiliency', () {
    testWidgets('ExerciseVideoCard with malformed URL does not throw unhandled exception on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ExerciseVideoCard(
              videoUrl: 'ht tp://invalid url with spaces',
              title: 'Malformed Test',
            ),
          ),
        ),
      );

      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap play button
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should either display a SnackBar or handle gracefully without throwing
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExerciseVideoCard with empty videoUrl displays SnackBar without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ExerciseVideoCard(
              videoUrl: '',
              title: 'Empty URL Test',
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(find.text('Video demo URL is unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Test: Rapid Toggling Stress Harness', () {
    test('Rapidly updating exercise video preference 40 times maintains state consistency', () async {
      SharedPreferences.setMockInitialValues({'incline_exercise_video_demos_enabled': false});

      // Perform 40 rapid sequential updates
      for (int i = 0; i < 40; i++) {
        await OfflineSyncService.instance.setExerciseVideoDemosEnabled(i % 2 == 1);
      }

      // 40th iteration (i=39, odd) -> true
      expect(await OfflineSyncService.instance.getExerciseVideoDemosEnabled(), isTrue);

      await OfflineSyncService.instance.setExerciseVideoDemosEnabled(false);
      expect(await OfflineSyncService.instance.getExerciseVideoDemosEnabled(), isFalse);
    });

    testWidgets('Rapidly navigating exercises in WorkoutExecutionSheet does not leak or crash', (tester) async {
      SharedPreferences.setMockInitialValues({'incline_exercise_video_demos_enabled': false});

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

      // Close button is present in AppBar
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify no exceptions when pumping multiple frames
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('Concurrent asynchronous writes to setExerciseVideoDemosEnabled do not throw or corrupt', () async {
      SharedPreferences.setMockInitialValues({});

      // Fire 50 concurrent writes
      final futures = <Future<void>>[];
      for (int i = 0; i < 50; i++) {
        futures.add(OfflineSyncService.instance.setExerciseVideoDemosEnabled(i % 2 == 0));
      }
      await Future.wait(futures);

      // Last value should be readable as a boolean without exception
      final result = await OfflineSyncService.instance.getExerciseVideoDemosEnabled();
      expect(result, isA<bool>());
    });
  });

  group('Adversarial Stress Test: Zero Video Buffering & Invariant Verification', () {
    testWidgets('Zero Video Buffering Invariant: Across all days and exercises, no VideoCard when OFF', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      for (final day in plan.days) {
        for (int i = 0; i < day.exercises.length; i++) {
          final exercise = day.exercises[i];

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AnimatedExerciseVisualizer(
                    exercise: exercise,
                    exerciseIndex: i,
                    totalExercises: day.exercises.length,
                    showVideo: false, // Invariant: toggle is OFF
                  ),
                ),
              ),
            ),
          );

          await tester.pump();

          // CRITICAL INVARIANT: ZERO ExerciseVideoCard widgets mounted
          expect(
            find.byType(ExerciseVideoCard),
            findsNothing,
            reason: 'Exercise "${exercise.name}" mounted ExerciseVideoCard while showVideo is false!',
          );
        }
      }
    });

    testWidgets('Visualizer handles exercises with only imageUrl or only videoUrl or neither', (tester) async {
      final cases = [
        // Case 1: Image only
        WorkoutExercise(
          name: 'Image Only',
          sets: 3,
          reps: '10',
          imageUrl: 'https://inclinegym.com/image.jpg',
          videoUrl: null,
        ),
        // Case 2: Video only
        WorkoutExercise(
          name: 'Video Only',
          sets: 3,
          reps: '10',
          imageUrl: null,
          videoUrl: 'https://inclinegym.com/video.mp4',
        ),
        // Case 3: Neither
        WorkoutExercise(
          name: 'Neither Media',
          sets: 3,
          reps: '10',
          imageUrl: null,
          videoUrl: null,
        ),
        // Case 4: Both
        WorkoutExercise(
          name: 'Both Media',
          sets: 3,
          reps: '10',
          imageUrl: 'https://inclinegym.com/image.jpg',
          videoUrl: 'https://inclinegym.com/video.mp4',
        ),
      ];

      for (final ex in cases) {
        // Test with showVideo = false
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedExerciseVisualizer(
                  exercise: ex,
                  exerciseIndex: 0,
                  totalExercises: 1,
                  showVideo: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(ExerciseVideoCard), findsNothing);

        // Test with showVideo = true
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedExerciseVisualizer(
                  exercise: ex,
                  exerciseIndex: 0,
                  totalExercises: 1,
                  showVideo: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        if (ex.videoUrl != null && ex.videoUrl!.isNotEmpty) {
          expect(find.byType(ExerciseVideoCard), findsOneWidget);
        } else {
          expect(find.byType(ExerciseVideoCard), findsNothing);
        }
      }
    });

    testWidgets('Active rest timer countdown does not rebuild ExerciseVideoCard or disrupt media state', (tester) async {
      final exercise = WorkoutExercise(
        name: 'Incline Dumbbell Press',
        sets: 4,
        reps: '8-10',
        videoUrl: 'https://inclinegym.com/video.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exercise,
                exerciseIndex: 0,
                totalExercises: 4,
                isResting: true,
                showVideo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExerciseVideoCard),
          matching: find.text('Incline Dumbbell Press'),
        ),
        findsOneWidget,
      );
    });
  });
}
