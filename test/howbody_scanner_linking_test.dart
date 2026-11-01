import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/deep_link_service.dart';
import 'package:incline_app/core/services/supabase_service.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/activity/activity_screen.dart';
import 'package:incline_app/features/home/components/inbody_scan_sheet.dart';
import 'package:incline_app/features/progress/components/howbody_link_sheet.dart';
import 'package:incline_app/features/progress/components/howbody_qr_scanner_sheet.dart';
import 'package:incline_app/features/workout/workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HOWBODY QR Code Payload Parser Tests', () {
    test('Parses standard HTTPS URL schema with query parameters', () {
      const url =
          'https://inclinegym.com/scan-login?equipmentNo=INC-HOWBODY-UDR-01&scanId=sess_alpha_101&kind=body';
      final payload = HowbodyQrPayload.parse(url);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HOWBODY-UDR-01'));
      expect(payload.scanId, equals('sess_alpha_101'));
      expect(payload.kind, equals('body'));
    });

    test('Parses alternative /howbody-login schema with snake_case parameters', () {
      const url =
          'https://inclinegym.com/howbody-login?equipment_no=INC-HOWBODY-02&scan_id=sess_beta_202&kind=posture';
      final payload = HowbodyQrPayload.parse(url);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HOWBODY-02'));
      expect(payload.scanId, equals('sess_beta_202'));
      expect(payload.kind, equals('posture'));
    });

    test('Parses custom app scheme URI (incline://scan-login)', () {
      const uri = 'incline://scan-login?equipmentNo=INC-UDR-03&scanId=sess_gamma_303';
      final payload = HowbodyQrPayload.parse(uri);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-UDR-03'));
      expect(payload.scanId, equals('sess_gamma_303'));
      expect(payload.kind, equals('body')); // default fallback
    });

    test('Parses raw query string without scheme or host', () {
      const raw = 'equipmentNo=INC-HOWBODY-RAW-04&scanId=sess_delta_404&kind=posture';
      final payload = HowbodyQrPayload.parse(raw);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-HOWBODY-RAW-04'));
      expect(payload.scanId, equals('sess_delta_404'));
      expect(payload.kind, equals('posture'));
    });

    test('Parses JSON string payload format', () {
      const jsonStr = '{"equipmentNo":"INC-JSON-05","scanId":"sess_epsilon_505","kind":"body"}';
      final payload = HowbodyQrPayload.parse(jsonStr);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-JSON-05'));
      expect(payload.scanId, equals('sess_epsilon_505'));
      expect(payload.kind, equals('body'));
    });

    test('Rejects invalid, empty, or incomplete payloads cleanly', () {
      expect(HowbodyQrPayload.parse(''), isNull);
      expect(HowbodyQrPayload.parse('   '), isNull);
      expect(HowbodyQrPayload.parse('just_a_random_unrelated_barcode'), isNull);
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?equipmentNo=INC-01'), isNull); // missing scanId
      expect(HowbodyQrPayload.parse('https://inclinegym.com/scan-login?scanId=sess_01'), isNull); // missing equipmentNo
    });
  });

  group('HOWBODY Dual-Unit Height Converter Tests', () {
    test('cmToFeetInches converts metric cm to feet and inches accurately', () {
      // 175.0 cm -> 5 ft 9 in
      final h175 = HowbodyHeightConverter.cmToFeetInches(175.0);
      expect(h175.feet, equals(5));
      expect(h175.inches, equals(9));

      // 180.0 cm -> 5 ft 11 in
      final h180 = HowbodyHeightConverter.cmToFeetInches(180.0);
      expect(h180.feet, equals(5));
      expect(h180.inches, equals(11));

      // 182.88 cm -> 6 ft 0 in
      final h183 = HowbodyHeightConverter.cmToFeetInches(182.88);
      expect(h183.feet, equals(6));
      expect(h183.inches, equals(0));

      // 152.4 cm -> 5 ft 0 in
      final h152 = HowbodyHeightConverter.cmToFeetInches(152.4);
      expect(h152.feet, equals(5));
      expect(h152.inches, equals(0));
    });

    test('feetInchesToCm converts imperial to metric cm accurately', () {
      expect(HowbodyHeightConverter.feetInchesToCm(5, 9), closeTo(175.26, 0.05));
      expect(HowbodyHeightConverter.feetInchesToCm(6, 0), closeTo(182.88, 0.05));
      expect(HowbodyHeightConverter.feetInchesToCm(5, 11), closeTo(180.34, 0.05));
    });

    test('isValidHeightCm enforces 100.0 cm to 250.0 cm boundaries', () {
      expect(HowbodyHeightConverter.isValidHeightCm(99.9), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(100.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(175.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.1), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(-15.0), isFalse);
    });
  });

  group('SupabaseService HOWBODY Types & Status Mapping Tests', () {
    test('HowbodyBindResult correctly serializes and provides getters', () {
      final successResult = HowbodyBindResult.ok(kind: 'body');
      expect(successResult.success, isTrue);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.kind, equals('body'));

      final failedResult = HowbodyBindResult.failed('Session expired', code: 'session_expired');
      expect(failedResult.success, isFalse);
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.error, equals('Session expired'));
      expect(failedResult.code, equals('session_expired'));

      final fromJsonSuccess = HowbodyBindResult.fromJson({'ok': true, 'kind': 'posture'});
      expect(fromJsonSuccess.success, isTrue);
      expect(fromJsonSuccess.kind, equals('posture'));

      final fromJsonFailure = HowbodyBindResult.fromJson({
        'ok': false,
        'error': 'Quota exceeded',
        'code': 'no_entitlement',
      });
      expect(fromJsonFailure.success, isFalse);
      expect(fromJsonFailure.error, equals('Quota exceeded'));
    });

    test('HowbodySessionStatus maps status strings and helpers correctly', () {
      expect(HowbodySessionStatus.fromString('pending'), equals(HowbodySessionStatus.pending));
      expect(HowbodySessionStatus.fromString('bound'), equals(HowbodySessionStatus.bound));
      expect(HowbodySessionStatus.fromString('scanning'), equals(HowbodySessionStatus.bound));
      expect(HowbodySessionStatus.fromString('completed'), equals(HowbodySessionStatus.completed));
      expect(HowbodySessionStatus.fromString('failed'), equals(HowbodySessionStatus.failed));
      expect(HowbodySessionStatus.fromString('cancelled'), equals(HowbodySessionStatus.failed));
      expect(HowbodySessionStatus.fromString(null), equals(HowbodySessionStatus.unknown));
      expect(HowbodySessionStatus.fromString('unknown_status'), equals(HowbodySessionStatus.unknown));

      expect(HowbodySessionStatus.completed.isCompleted, isTrue);
      expect(HowbodySessionStatus.failed.isFailed, isTrue);
      expect(HowbodySessionStatus.bound.isBound, isTrue);
      expect(HowbodySessionStatus.pending.isPending, isTrue);
    });
  });

  group('HOWBODY Link Sheet Widget Tests', () {
    testWidgets('Renders header with equipmentNo, unit converter, and scan kind selector', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HowbodyLinkSheet(
              equipmentNo: 'INC-HOWBODY-UDR-01',
              scanId: 'sess_widget_01',
              onFetchDeviceLabel: (eq) async => 'Incline Flagship Udaipur — Unit 1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
      expect(find.text('Incline Flagship Udaipur — Unit 1'), findsOneWidget);
      expect(find.text('3D Volumetric & Posture Assessment'), findsOneWidget);
      expect(find.text('Metric (cm)'), findsOneWidget);
      expect(find.text('Imperial (ft/in)'), findsOneWidget);
      expect(find.text('Link Scanner to Profile'), findsOneWidget);
    });

    testWidgets('Toggles unit converter between metric (cm) and imperial (ft/in)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HowbodyLinkSheet(
              equipmentNo: 'INC-01',
              scanId: 'sess_unit_test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in Metric (cm) mode
      expect(find.text('Height in Centimeters'), findsOneWidget);
      expect(find.text('Feet'), findsNothing);

      // Switch to Imperial
      await tester.tap(find.text('Imperial (ft/in)'));
      await tester.pumpAndSettle();

      expect(find.text('Feet'), findsOneWidget);
      expect(find.text('Inches'), findsOneWidget);
      expect(find.text('Height in Centimeters'), findsNothing);

      // Switch back to Metric
      await tester.tap(find.text('Metric (cm)'));
      await tester.pumpAndSettle();

      expect(find.text('Height in Centimeters'), findsOneWidget);
    });

    testWidgets('Binding transition to Step on the Scanner polling state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool bindCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HowbodyLinkSheet(
              equipmentNo: 'INC-01',
              scanId: 'sess_poll_test',
              onBindScanner: ({
                required equipmentNo,
                required scanId,
                required kind,
                required heightCm,
                memberId,
              }) async {
                bindCalled = true;
                return HowbodyBindResult.ok(kind: kind);
              },
              onCheckStatus: (scanId) async => HowbodySessionStatus.bound,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Link button
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bindCalled, isTrue);
      // Transitions to "Step onto the Turntable" polling state
      expect(find.text('Step onto the Turntable'), findsOneWidget);
      expect(find.text('Cancel Scan'), findsOneWidget);

      // Tap Cancel Scan to cancel active polling timer
      await tester.tap(find.text('Cancel Scan'));
      await tester.pump();
    });
  });

  group('Progress View & InBodyScanSheet Scanner Integration Tests', () {
    testWidgets('WorkoutScreen Progress view empty card renders Link 3D Scanner (QR) button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final member = Member(
        id: 'mem_test',
        memberCode: 'INC-M-01',
        status: 'active',
        profile: const Profile(id: 'p1', fullName: 'Test Member'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ActivityScreen(
              member: member,
              initialSubTab: 1, // Body & 3D Progress sub-tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3D Body Progress'), findsWidgets);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    });

    testWidgets('WorkoutScreen tabs are strictly Workout, Nutrition, Coach without redundant progress', (tester) async {
      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WorkoutScreen(
              initialPlan: plan,
              initialTab: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);
      expect(find.text('Progress'), findsNothing);
    });

    testWidgets('InBodyScanSheet empty state renders Link Incline 3D Scanner (QR) button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final member = Member(
        id: 'mem_test',
        memberCode: 'INC-M-01',
        status: 'active',
        profile: const Profile(id: 'p1', fullName: 'Test Member'),
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

      expect(find.text('Link Incline 3D Scanner (QR)'), findsOneWidget);
      expect(find.text('Record Manual Measurements'), findsOneWidget);
    });
  });

  group('DeepLinkService Scanner Universal Link Routing Tests', () {
    test('Routes /scan-login and parses scanner parameters', () {
      final deepLinks = DeepLinkService.instance;
      String? routedPath;
      Map<String, String>? routedParams;

      deepLinks.init(onRouteDispatched: (route, params) {
        routedPath = route;
        routedParams = params;
      });

      final uri = Uri.parse(
        'https://inclinegym.com/scan-login?equipmentNo=INC-HOWBODY-UDR-01&scanId=sess_universal_42&kind=body',
      );
      deepLinks.handleUri(uri);

      expect(routedPath, equals('/scan-login'));
      expect(routedParams!['equipmentNo'], equals('INC-HOWBODY-UDR-01'));
      expect(routedParams!['scanId'], equals('sess_universal_42'));
      expect(routedParams!['kind'], equals('body'));

      deepLinks.dispose();
    });

    test('Routes /howbody-login and parses posture kind', () {
      final deepLinks = DeepLinkService.instance;
      String? routedPath;
      Map<String, String>? routedParams;

      deepLinks.init(onRouteDispatched: (route, params) {
        routedPath = route;
        routedParams = params;
      });

      final uri = Uri.parse(
        'https://inclineclub.in/howbody-login?equipmentNo=INC-HOWBODY-02&scanId=sess_universal_88&kind=posture',
      );
      deepLinks.handleUri(uri);

      expect(routedPath, equals('/howbody-login'));
      expect(routedParams!['equipmentNo'], equals('INC-HOWBODY-02'));
      expect(routedParams!['scanId'], equals('sess_universal_88'));
      expect(routedParams!['kind'], equals('posture'));

      deepLinks.dispose();
    });
  });
}
