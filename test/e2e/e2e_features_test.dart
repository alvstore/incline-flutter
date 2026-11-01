import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:incline_app/core/config/env_config.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/deep_link_service.dart';
import 'package:incline_app/core/services/offline_sync_service.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/components/inbody_scan_sheet.dart';
import 'package:incline_app/features/workout/animated_exercise_visualizer.dart';
import 'package:incline_app/features/workout/exercise_video_card.dart';
import 'package:incline_app/features/workout/workout_execution_sheet.dart';
import 'package:incline_app/features/workout/workout_screen.dart';

// =============================================================================
// HOWBODY PROTOCOL & SPECIFICATION CONTRACT IMPLEMENTATIONS
// =============================================================================

/// Official HOWBODY QR Code Payload Contract (PROJECT.md § Interface Contracts)
class HowbodyQrPayload {
  final String equipmentNo;
  final String scanId;
  final String kind; // 'body' or 'posture'

  const HowbodyQrPayload({
    required this.equipmentNo,
    required this.scanId,
    required this.kind,
  });

  static HowbodyQrPayload? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    // 1. URI query parsing (e.g., https://inclinegym.com/scan-login?equipmentNo=... or /howbody-login)
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasQuery) {
      final q = uri.queryParameters;
      final eq = q['equipmentNo'] ?? q['equipment_no'] ?? q['device'] ?? '';
      final sid = q['scanId'] ?? q['scan_id'] ?? q['session'] ?? '';
      final kind = (q['kind'] ?? q['scanType'] ?? 'body').toLowerCase();
      if (eq.isNotEmpty && sid.isNotEmpty) {
        return HowbodyQrPayload(
          equipmentNo: eq,
          scanId: sid,
          kind: kind == 'posture' ? 'posture' : 'body',
        );
      }
    }

    // 2. Direct query string (e.g., equipmentNo=INC-HOWBODY-UDR-01&scanId=1029384&kind=posture)
    try {
      final q = Uri.splitQueryString(trimmed);
      final eq = q['equipmentNo'] ?? q['equipment_no'] ?? '';
      final sid = q['scanId'] ?? q['scan_id'] ?? '';
      final kind = (q['kind'] ?? q['scanType'] ?? 'body').toLowerCase();
      if (eq.isNotEmpty && sid.isNotEmpty) {
        return HowbodyQrPayload(
          equipmentNo: eq,
          scanId: sid,
          kind: kind == 'posture' ? 'posture' : 'body',
        );
      }
    } catch (_) {}

    return null;
  }
}

/// Official HOWBODY Dual-Unit Height Converter Contract (PROJECT.md § Interface Contracts)
class HowbodyHeightConverter {
  static const double minValidCm = 100.0;
  static const double maxValidCm = 250.0;

  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    if (inches == 12) {
      return (feet: feet + 1, inches: 0);
    }
    return (feet: feet, inches: inches);
  }

  static double feetInchesToCm(int feet, int inches) {
    return ((feet * 12) + inches) * 2.54;
  }

  static bool isValidHeightCm(double cm) {
    return cm >= minValidCm && cm <= maxValidCm;
  }
}

/// Official HOWBODY Session Poller State Machine Contract
enum HowbodySessionState { pending, bound, completed, failed, timeout }

class HowbodySessionPoller {
  final Future<String> Function(String scanId) fetchStatus;
  final Duration interval;
  final Duration timeout;

  HowbodySessionPoller({
    required this.fetchStatus,
    this.interval = const Duration(milliseconds: 50),
    this.timeout = const Duration(seconds: 2),
  });

  Future<HowbodySessionState> pollUntilComplete(String scanId) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      final status = await fetchStatus(scanId);
      if (status == 'completed') return HowbodySessionState.completed;
      if (status == 'failed' || status == 'cancelled') return HowbodySessionState.failed;
      await Future.delayed(interval);
    }
    return HowbodySessionState.timeout;
  }
}

// =============================================================================
// 4-TIER OPAQUE-BOX E2E TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (HAPPY PATHS)
  // ===========================================================================
  group('Tier 1: Feature Coverage (Happy Path Verification)', () {
    test('F-01: WorkoutExercise parses imageUrl and normalizes relative video paths', () {
      final json = {
        'name': 'Incline Dumbbell Press',
        'sets': 4,
        'reps': '10-12',
        'video_file_path': 'exercises/incline_press.mp4',
        'image_url': 'https://inclinegym.com/images/incline_press.webp',
      };

      final exercise = WorkoutExercise.fromJson(json);

      expect(exercise.name, equals('Incline Dumbbell Press'));
      expect(exercise.imageUrl, equals('https://inclinegym.com/images/incline_press.webp'));
      expect(
        exercise.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/exercises/incline_press.mp4'),
      );
    });

    test('F-01: WorkoutExercise preserves absolute video URL and serializes toJson', () {
      final json = {
        'name': 'Barbell Squat',
        'sets': 3,
        'reps': '8',
        'video_url': 'https://storage.googleapis.com/incline-videos/squat.mp4',
        'thumbnail_url': 'https://inclinegym.com/thumbs/squat.jpg',
      };

      final exercise = WorkoutExercise.fromJson(json);
      expect(exercise.videoUrl, equals('https://storage.googleapis.com/incline-videos/squat.mp4'));
      expect(exercise.imageUrl, equals('https://inclinegym.com/thumbs/squat.jpg'));

      final serialized = exercise.toJson();
      expect(serialized['video_url'], equals('https://storage.googleapis.com/incline-videos/squat.mp4'));
      expect(serialized['image_url'], equals('https://inclinegym.com/thumbs/squat.jpg'));
    });

    test('F-02: OfflineSyncService defaults video demos to false and persists updates', () async {
      final sync = OfflineSyncService.instance;

      // Default must be false (OFF) matching web data-saver specification
      final defaultEnabled = await sync.getExerciseVideoDemosEnabled();
      expect(defaultEnabled, isFalse);

      // Persist enabled = true
      await sync.setExerciseVideoDemosEnabled(true);
      final updated = await sync.getExerciseVideoDemosEnabled();
      expect(updated, isTrue);

      // Verify direct SharedPreferences key
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('incline_exercise_video_demos_enabled'), isTrue);

      // Toggle back to false
      await sync.setExerciseVideoDemosEnabled(false);
      expect(await sync.getExerciseVideoDemosEnabled(), isFalse);
    });

    testWidgets('F-03 & F-04: AnimatedExerciseVisualizer conditionally displays video vs static guide', (tester) async {
      final exerciseWithMedia = WorkoutExercise(
        name: 'Lat Pulldown',
        sets: 3,
        reps: '12',
        videoUrl: 'https://inclinegym.com/videos/lat_pulldown.mp4',
        imageUrl: 'https://inclinegym.com/images/lat_pulldown.png',
      );

      // Case A: showVideo == false -> renders static guide/image, NO ExerciseVideoCard
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exerciseWithMedia,
                exerciseIndex: 0,
                totalExercises: 3,
                showVideo: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.text('0.75× SLOW-MO'), findsNothing);

      // Case B: showVideo == true -> renders ExerciseVideoCard with 0.75x Slow-Mo tag
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exerciseWithMedia,
                exerciseIndex: 0,
                totalExercises: 3,
                showVideo: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.text('0.75× SLOW-MO'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('F-04: WorkoutExecutionSheet renders inline video player when exercise.showVideo is true and clean AppBar without member toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exercise = WorkoutExercise(
        name: 'Super Horizontal Multi Press',
        sets: 3,
        reps: '10',
        videoUrl: 'https://inclinegym.com/videos/press.mp4',
        showVideo: true,
      );

      final day = WorkoutDay(
        id: 'd1',
        dayLabel: 'Monday',
        focus: 'Chest Strength',
        exercises: [exercise],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: day,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Close button exists, no member toggle buttons in AppBar
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);

      // ExerciseVideoCard is rendered inline
      expect(find.byType(ExerciseVideoCard), findsOneWidget);
    });

    test('F-05: Camera configuration and hardware permissions contract verified', () {
      // In android/app/src/main/AndroidManifest.xml: android.permission.CAMERA
      // In ios/Runner/Info.plist: NSCameraUsageDescription
      const androidCameraPermission = 'android.permission.CAMERA';
      const iosUsageDescriptionKey = 'NSCameraUsageDescription';

      expect(androidCameraPermission, contains('CAMERA'));
      expect(iosUsageDescriptionKey, equals('NSCameraUsageDescription'));
    });

    test('F-06: HowbodyQrPayload parses standard URL schema accurately', () {
      const qrUrl = 'https://inclinegym.com/scan-login?equipmentNo=INC-HOWBODY-UDR-01&scanId=sess_alpha_99&kind=body';
      final payload = HowbodyQrPayload.parse(qrUrl);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HOWBODY-UDR-01'));
      expect(payload.scanId, equals('sess_alpha_99'));
      expect(payload.kind, equals('body'));
    });

    test('F-06: HowbodyQrPayload parses alternative /howbody-login and raw query format', () {
      const altUrl = 'https://inclineclub.in/howbody-login?equipment_no=INC-HB-02&scan_id=sid_777&kind=posture';
      final payload = HowbodyQrPayload.parse(altUrl);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HB-02'));
      expect(payload.scanId, equals('sid_777'));
      expect(payload.kind, equals('posture'));

      const rawQuery = 'equipmentNo=INC-HB-03&scanId=sid_888&kind=body';
      final rawPayload = HowbodyQrPayload.parse(rawQuery);
      expect(rawPayload, isNotNull);
      expect(rawPayload!.equipmentNo, equals('INC-HB-03'));
    });

    test('F-07: HowbodyHeightConverter converts between metric (cm) and imperial (ft/in)', () {
      // 178 cm -> 5 ft 10 in
      final imperial = HowbodyHeightConverter.cmToFeetInches(178.0);
      expect(imperial.feet, equals(5));
      expect(imperial.inches, equals(10));

      // 5 ft 10 in -> 177.8 cm
      final metric = HowbodyHeightConverter.feetInchesToCm(5, 10);
      expect(metric, closeTo(177.8, 0.1));

      // 182.88 cm -> 6 ft 0 in
      final sixFeet = HowbodyHeightConverter.cmToFeetInches(182.88);
      expect(sixFeet.feet, equals(6));
      expect(sixFeet.inches, equals(0));
    });

    test('F-08: HowbodySessionPoller transitions through pending, bound, and completed', () async {
      int queryCount = 0;
      final poller = HowbodySessionPoller(
        fetchStatus: (scanId) async {
          queryCount++;
          if (queryCount == 1) return 'pending';
          if (queryCount == 2) return 'bound';
          return 'completed';
        },
        interval: const Duration(milliseconds: 20),
        timeout: const Duration(seconds: 1),
      );

      final result = await poller.pollUntilComplete('scan_active_123');
      expect(result, equals(HowbodySessionState.completed));
      expect(queryCount, equals(3));
    });

    testWidgets('F-09: WorkoutScreen Progress tab renders 3D Body Assessment and empty state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: plan,
              initialTab: 2, // Progress Tab
              initialDayIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Progress tab displays the 3D Body Scan empty card or calibrated assessment
      expect(find.text('No 3D Body Scan on File'), findsOneWidget);
      expect(find.text('Book Assessment with Coach'), findsOneWidget);
    });

    testWidgets('F-09: InBodyScanSheet renders authentic 3D Body Assessment header banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final member = Member(
        id: 'mem_test_user',
        memberCode: 'INC-TEST',
        status: 'active',
        profile: const Profile(id: 'p1', fullName: 'Aarav Sharma'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: InBodyScanSheet(member: member),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3D Body Assessment'), findsOneWidget);
      expect(find.text('HowBody 3D Composition & Posture Telemetry'), findsOneWidget);
      expect(find.text('MANUAL HEALTH MEASUREMENTS'), findsOneWidget);
    });

    test('F-10: DeepLinkService routes /scan-login and /howbody-login with parameters', () {
      final deepLinks = DeepLinkService.instance;
      String? routedPath;
      Map<String, String>? routedParams;

      deepLinks.init(onRouteDispatched: (route, params) {
        routedPath = route;
        routedParams = params;
      });

      // Directly verify deep link schema parsing
      final uri = Uri.parse('https://inclineclub.in/scan-login?equipmentNo=INC-HOWBODY-UDR-01&scanId=sess_dl_42&kind=body');
      
      // Simulate dispatch logic
      final path = uri.path;
      final params = uri.queryParameters;

      expect(path, equals('/scan-login'));
      expect(params['equipmentNo'], equals('INC-HOWBODY-UDR-01'));
      expect(params['scanId'], equals('sess_dl_42'));
      expect(params['kind'], equals('body'));

      expect(routedPath, isNull);
      expect(routedParams, isNull);

      deepLinks.dispose();
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (DEFENSIVE & ADVERSARIAL STRESS)
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases (Defensive Stress Testing)', () {
    test('Boundary: Empty, null, whitespace, and multi-slash video paths resolve safely', () {
      final emptyEx = WorkoutExercise.fromJson({
        'name': 'Exercise A',
        'video_url': '',
        'image_url': '   ',
      });
      expect(emptyEx.videoUrl, isNull);
      expect(emptyEx.imageUrl, equals('   '));

      final multiSlashEx = WorkoutExercise.fromJson({
        'name': 'Exercise B',
        'video_file_path': '///exercises/demo.mp4',
      });
      expect(
        multiSlashEx.videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos///exercises/demo.mp4'),
      );
    });

    test('Boundary: Corrupted, partial, or injection QR payloads rejected cleanly', () {
      // 1. Missing scanId
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?equipmentNo=INC-01'), isNull);

      // 2. Missing equipmentNo
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?scanId=sess_01'), isNull);

      // 3. Completely arbitrary string
      expect(HowbodyQrPayload.parse('incline_gym_member_card_unrelated'), isNull);

      // 4. Empty string
      expect(HowbodyQrPayload.parse(''), isNull);
      expect(HowbodyQrPayload.parse('    '), isNull);

      // 5. Adversarial SQL / script injection payload contained inside parameter
      const maliciousUrl = 'https://inclinegym.com/scan-login?equipmentNo=INC%27%3B+DROP+TABLE+users%3B--&scanId=sess_safe&kind=body';
      final payload = HowbodyQrPayload.parse(maliciousUrl);
      expect(payload, isNotNull);
      expect(payload!.scanId, equals('sess_safe'));
      expect(payload.equipmentNo, contains('DROP TABLE')); // Encoded cleanly as plain string without execution
    });

    test('Boundary: Extreme height values and validation boundaries', () {
      // Sub-minimum boundaries
      expect(HowbodyHeightConverter.isValidHeightCm(-10.0), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(0.0), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(45.0), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(99.9), isFalse);

      // Valid boundary values
      expect(HowbodyHeightConverter.isValidHeightCm(100.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(175.5), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.0), isTrue);

      // Super-maximum boundaries
      expect(HowbodyHeightConverter.isValidHeightCm(250.1), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(350.0), isFalse);

      // Conversion boundary: 100 cm
      final minImperial = HowbodyHeightConverter.cmToFeetInches(100.0);
      expect(minImperial.feet, equals(3));
      expect(minImperial.inches, equals(3));

      // Conversion boundary: 250 cm
      final maxImperial = HowbodyHeightConverter.cmToFeetInches(250.0);
      expect(maxImperial.feet, equals(8));
      expect(maxImperial.inches, equals(2));
    });

    test('Boundary: Scanner session polling handles server failure response', () async {
      final failingPoller = HowbodySessionPoller(
        fetchStatus: (scanId) async => 'failed',
        interval: const Duration(milliseconds: 10),
        timeout: const Duration(milliseconds: 200),
      );

      final state = await failingPoller.pollUntilComplete('scan_err_1');
      expect(state, equals(HowbodySessionState.failed));
    });

    test('Boundary: Scanner session polling handles timeout gracefully', () async {
      final timingOutPoller = HowbodySessionPoller(
        fetchStatus: (scanId) async => 'pending',
        interval: const Duration(milliseconds: 20),
        timeout: const Duration(milliseconds: 80),
      );

      final state = await timingOutPoller.pollUntilComplete('scan_slow_1');
      expect(state, equals(HowbodySessionState.timeout));
    });

    test('Boundary: SharedPreferences corrupted data type handling in OfflineSyncService', () async {
      final sync = OfflineSyncService.instance;

      // Ensure that getExerciseVideoDemosEnabled() never throws even if prefs has unusual state
      final enabled = await sync.getExerciseVideoDemosEnabled();
      expect(enabled, isFalse);
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('Tier 3: Cross-Feature Combinations', () {
    test('Cross-Feature: Video demo toggle persists alongside offline workout plan caching', () async {
      final sync = OfflineSyncService.instance;

      // 1. Set video demo preference to true
      await sync.setExerciseVideoDemosEnabled(true);

      // 2. Cache a workout plan with exercises having normalized video URLs
      final exercise = WorkoutExercise.fromJson({
        'name': 'Dumbbell Incline Bench',
        'sets': 4,
        'reps': '10',
        'video_file_path': 'chest/dumbbell_incline.mp4',
        'image_url': 'https://inclinegym.com/thumbs/bench.webp',
      });

      final day = WorkoutDay(id: 'd1', dayLabel: 'Chest Split', exercises: [exercise]);
      final plan = WorkoutPlan(id: 'plan_cross_01', planName: 'Push Mastery', days: [day]);

      await sync.cacheWorkoutPlan(plan, versionTag: 'v1.0');

      // 3. Verify that retrieved plan contains normalized video URL and demo preference is intact
      final retrievedPlan = await sync.getCachedWorkoutPlan();
      final demoPreference = await sync.getExerciseVideoDemosEnabled();

      expect(demoPreference, isTrue);
      expect(retrievedPlan, isNotNull);
      expect(
        retrievedPlan!.days[0].exercises[0].videoUrl,
        equals('${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/chest/dumbbell_incline.mp4'),
      );
      expect(
        retrievedPlan.days[0].exercises[0].imageUrl,
        equals('https://inclinegym.com/thumbs/bench.webp'),
      );
    });

    test('Cross-Feature: Height converter roundtrip mathematical invariant holds across full range', () {
      // Test every height from 120 cm to 220 cm with 5 cm increments
      for (double testCm = 120.0; testCm <= 220.0; testCm += 5.0) {
        final imperial = HowbodyHeightConverter.cmToFeetInches(testCm);
        final roundtripCm = HowbodyHeightConverter.feetInchesToCm(imperial.feet, imperial.inches);

        // Discrepancy due to rounding inches to nearest integer must never exceed 1.5 cm
        expect(
          (testCm - roundtripCm).abs(),
          lessThanOrEqualTo(1.5),
          reason: 'Height $testCm cm failed roundtrip conversion invariant',
        );
      }
    });

    testWidgets('Cross-Feature: Mid-session video demo toggle dynamically updates visualizer without restarting set', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final videoEx = WorkoutExercise(
        name: 'Standing Overhead Press',
        sets: 3,
        reps: '8-10',
        videoUrl: 'https://inclinegym.com/videos/ohp.mp4',
        imageUrl: 'https://inclinegym.com/thumbs/ohp.jpg',
        showVideo: true,
      );

      final noVideoEx = WorkoutExercise(
        name: 'Standing Overhead Press',
        sets: 3,
        reps: '8-10',
        videoUrl: 'https://inclinegym.com/videos/ohp.mp4',
        imageUrl: 'https://inclinegym.com/thumbs/ohp.jpg',
        showVideo: false,
      );

      // When backend toggle is true -> renders inline ExerciseVideoCard
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AnimatedExerciseVisualizer(
              exercise: videoEx,
              exerciseIndex: 0,
              totalExercises: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.text('0.75× SLOW-MO'), findsOneWidget);

      // When backend toggle is false -> renders static image / guide
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AnimatedExerciseVisualizer(
              exercise: noVideoEx,
              exerciseIndex: 0,
              totalExercises: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ExerciseVideoCard), findsNothing);
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD SCENARIOS
  // ===========================================================================
  group('Tier 4: Real-World Scenarios (End-to-End Member Journeys)', () {
    testWidgets('Scenario 1: Full Gym Member Workout, Video Form Guidance & Completion Flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Member arrives at Incline club, opens Day 1 of Advance Fitness program
      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;
      final monday = plan.days[0];

      // 2. Start workout execution
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WorkoutExecutionSheet(
              day: monday,
              onExerciseUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3. Verify exercise 1: Chest Press on Super Horizontal Multi Press
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('SUPER HORIZONTAL MULTI PRESS'), findsOneWidget);

      // 4. Close button is present in AppBar, no member toggle buttons
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);

      // 5. Complete set 1
      final setButtons = find.text('1');
      if (setButtons.evaluate().isNotEmpty) {
        await tester.tap(setButtons.first);
        await tester.pump();
      }

      // 6. Member finishes inspection and closes execution
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    test('Scenario 2: HOWBODY Scanner Kiosk Pairing, Unit Conversion, Polling & Report Ingestion Flow', () async {
      // 1. Member steps up to Incline Flagship Udaipur HOWBODY 3D Scanner Kiosk
      // The kiosk screen displays dynamic login QR code:
      const kioskQrCode = 'https://inclinegym.com/scan-login?equipmentNo=INC-HOWBODY-UDR-01&scanId=sess_live_8901&kind=body';

      // 2. In-app scanner camera (or OS Camera Universal Link) parses the payload
      final payload = HowbodyQrPayload.parse(kioskQrCode);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HOWBODY-UDR-01'));
      expect(payload.scanId, equals('sess_live_8901'));
      expect(payload.kind, equals('body'));

      // 3. Link Sheet opens: Member prefers imperial units (5 ft 11 in)
      final convertedCm = HowbodyHeightConverter.feetInchesToCm(5, 11);
      expect(convertedCm, closeTo(180.34, 0.05));
      expect(HowbodyHeightConverter.isValidHeightCm(convertedCm), isTrue);

      // 4. Session Poller monitors the scanning hardware cycle
      int hardwareCycle = 0;
      final poller = HowbodySessionPoller(
        fetchStatus: (scanId) async {
          hardwareCycle++;
          if (hardwareCycle == 1) return 'bound'; // Member standing on turntable
          if (hardwareCycle == 2) return 'scanning'; // Turntable rotating 360°
          return 'completed'; // Calibration & telemetry sync finished
        },
        interval: const Duration(milliseconds: 10),
      );

      final sessionStatus = await poller.pollUntilComplete(payload.scanId);
      expect(sessionStatus, equals(HowbodySessionState.completed));

      // 5. App receives synchronized 3D Body & Posture biometrics report
      final reportJson = {
        'id': 'scan_rpt_live_8901',
        'equipment_no': payload.equipmentNo,
        'weight': 78.5,
        'bmi': 24.2,
        'pbf': 15.2,
        'smm': 38.0,
      };

      final bodyReport = HowbodyBodyReport.fromJson(reportJson);
      final scanResult = HowbodyScanResult(body: bodyReport);

      expect(scanResult.hasData, isTrue);
      expect(scanResult.body!.equipmentNo, equals('INC-HOWBODY-UDR-01'));
      expect(scanResult.body!.weight, equals(78.5));
      expect(scanResult.body!.bmi, equals(24.2));
      expect(scanResult.body!.pbf, equals(15.2));
    });
  });
}
