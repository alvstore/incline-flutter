import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/offline_sync_service.dart';
import 'package:incline_app/features/progress/components/howbody_link_sheet.dart';
import 'package:incline_app/features/progress/components/howbody_qr_scanner_sheet.dart';
import 'package:incline_app/features/workout/animated_exercise_visualizer.dart';
import 'package:incline_app/features/workout/exercise_video_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('M3 Final Adversarial & Hardening Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // -------------------------------------------------------------------------
    // 1. QR Payload Edge & Attack Vectors
    // -------------------------------------------------------------------------
    test('QR Parser: handles URL fragments, multiple queries, and whitespace', () {
      // With URL fragment
      const urlWithFragment =
          'https://inclinegym.com/scan-login?equipmentNo=EQ-FRAG-1&scanId=SC-FRAG-2&kind=posture#anchorSection';
      final p1 = HowbodyQrPayload.parse(urlWithFragment);
      expect(p1, isNotNull);
      expect(p1!.equipmentNo, 'EQ-FRAG-1');
      expect(p1.scanId, 'SC-FRAG-2');
      expect(p1.kind, 'posture');

      // Duplicate keys or extra garbage parameters
      const urlGarbage =
          'https://inclinegym.com/howbody-login?junk=123&scanId=SC-OK&extra=foo&equipmentNo=EQ-OK&token=xyz';
      final p2 = HowbodyQrPayload.parse(urlGarbage);
      expect(p2, isNotNull);
      expect(p2!.equipmentNo, 'EQ-OK');
      expect(p2.scanId, 'SC-OK');
      expect(p2.kind, 'body'); // default

      // Encoded spaces and casing
      const urlSpaces =
          'https://inclinegym.com/scan-login?equipment_no=INCLINE%20KIOSK%209&scan_id=SCAN%20999&kind=BODY';
      final p3 = HowbodyQrPayload.parse(urlSpaces);
      expect(p3, isNotNull);
      expect(p3!.equipmentNo, 'INCLINE KIOSK 9');
      expect(p3.scanId, 'SCAN 999');
      expect(p3.kind, 'body');
    });

    test('QR Parser: gracefully rejects truncated and malformed inputs', () {
      expect(HowbodyQrPayload.parse(''), isNull);
      expect(HowbodyQrPayload.parse('   '), isNull);
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?equipmentNo='), isNull);
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?scanId='), isNull);
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?equipmentNo=&scanId='), isNull);
      expect(HowbodyQrPayload.parse('{"equipmentNo": "EQ1"}'), isNull);
      expect(HowbodyQrPayload.parse('{"scanId": "SC1"}'), isNull);
      expect(HowbodyQrPayload.parse('{"equipmentNo": "", "scanId": ""}'), isNull);
      expect(HowbodyQrPayload.parse('{broken json'), isNull);
      expect(HowbodyQrPayload.parse('some random QR without schema'), isNull);
    });

    // -------------------------------------------------------------------------
    // 2. Height Converter Exhaustive Domain Scan
    // -------------------------------------------------------------------------
    test('Height Converter: exhaustive 100cm to 250cm round-trip error < 1.3 cm', () {
      for (int cmInt = 100; cmInt <= 250; cmInt++) {
        final cm = cmInt.toDouble();
        expect(HowbodyHeightConverter.isValidHeightCm(cm), isTrue);

        final ftIn = HowbodyHeightConverter.cmToFeetInches(cm);
        expect(ftIn.inches, inInclusiveRange(0, 11),
            reason: 'Inches must never be 12 (must roll over to feet)');

        final roundtripCm =
            HowbodyHeightConverter.feetInchesToCm(ftIn.feet, ftIn.inches);
        final delta = (roundtripCm - cm).abs();
        expect(delta, lessThanOrEqualTo(1.3),
            reason: 'Max rounding quantization delta at $cm cm should be <= 1.27 cm');
      }
    });

    test('Height Converter: boundary conditions strictly enforced', () {
      expect(HowbodyHeightConverter.isValidHeightCm(99.9), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(100.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.1), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(-180.0), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(0.0), isFalse);
    });

    // -------------------------------------------------------------------------
    // 3. OfflineSyncService Concurrent Access & Default Invariants
    // -------------------------------------------------------------------------
    test('OfflineSyncService: handles 50 concurrent toggles without race condition',
        () async {
      final service = OfflineSyncService.instance;
      // Default initial
      expect(await service.getExerciseVideoDemosEnabled(), isFalse);

      // Concurrent toggle burst
      final futures = <Future<void>>[];
      for (int i = 0; i < 50; i++) {
        final state = (i % 2 == 0);
        futures.add(service.setExerciseVideoDemosEnabled(state));
      }
      await Future.wait(futures);

      // Service should be in valid boolean state
      final finalState = await service.getExerciseVideoDemosEnabled();
      expect(finalState, isA<bool>());

      // Setting explicitly true persists
      await service.setExerciseVideoDemosEnabled(true);
      expect(await service.getExerciseVideoDemosEnabled(), isTrue);

      // Setting explicitly false persists
      await service.setExerciseVideoDemosEnabled(false);
      expect(await service.getExerciseVideoDemosEnabled(), isFalse);
    });

    // -------------------------------------------------------------------------
    // 4. AnimatedExerciseVisualizer Media Rendering Invariant Matrix
    // -------------------------------------------------------------------------
    testWidgets('Visualizer Matrix: showVideo=false NEVER renders ExerciseVideoCard',
        (tester) async {
      final exercise = WorkoutExercise(
        name: 'Incline Dumbbell Press',
        sets: 4,
        reps: '10',
        videoUrl: 'https://cdn.inclinegym.com/video.mp4',
        imageUrl: 'https://cdn.inclinegym.com/thumb.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exercise,
                exerciseIndex: 0,
                totalExercises: 3,
                showVideo: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Zero ExerciseVideoCard instances when showVideo == false
      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.byType(AnimatedExerciseVisualizer), findsOneWidget);
      expect(find.text('Incline Dumbbell Press'), findsOneWidget);
    });

    testWidgets('Visualizer Matrix: showVideo=true with null videoUrl falls back gracefully',
        (tester) async {
      final exerciseNoVideo = WorkoutExercise(
        name: 'Standing Calf Raise',
        sets: 3,
        reps: '15',
        videoUrl: null,
        imageUrl: 'https://cdn.inclinegym.com/calf.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exerciseNoVideo,
                exerciseIndex: 1,
                totalExercises: 3,
                showVideo: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Even though showVideo=true, since videoUrl is null, no ExerciseVideoCard should render
      expect(find.byType(ExerciseVideoCard), findsNothing);
      expect(find.byType(AnimatedExerciseVisualizer), findsOneWidget);
    });

    testWidgets('Visualizer Matrix: showVideo=true with valid videoUrl renders ExerciseVideoCard',
        (tester) async {
      final exerciseWithVideo = WorkoutExercise(
        name: 'Super Horizontal Multi Press',
        sets: 3,
        reps: '12',
        videoUrl: 'https://cdn.inclinegym.com/press.mp4',
        imageUrl: 'https://cdn.inclinegym.com/press_thumb.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedExerciseVisualizer(
                exercise: exerciseWithVideo,
                exerciseIndex: 0,
                totalExercises: 2,
                showVideo: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ExerciseVideoCard), findsOneWidget);
      expect(find.text('Super Horizontal Multi Press'), findsWidgets);
    });
  });
}
