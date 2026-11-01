import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/services/deep_link_service.dart';
import 'package:incline_app/core/services/supabase_service.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/progress/components/howbody_link_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('HowbodyLinkSheet Initial State & Mock Parameters', () {
    testWidgets('Renders initial state with mock parameters and dynamic device label', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? queriedEquipmentNo;
      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-HOWBODY-TEST-01',
            scanId: 'sess_test_123',
            initialKind: 'posture',
            onFetchDeviceLabel: (eq) async {
              queriedEquipmentNo = eq;
              return 'Incline Flagship Udaipur — Scanner 1';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(queriedEquipmentNo, equals('INC-HOWBODY-TEST-01'));
      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
      expect(find.text('Incline Flagship Udaipur — Scanner 1'), findsOneWidget);
      expect(find.text('Posture Analysis'), findsOneWidget);
      expect(find.text('Body Assessment'), findsOneWidget);
      expect(find.text('Metric (cm)'), findsOneWidget);
      expect(find.text('Imperial (ft/in)'), findsOneWidget);
      expect(find.text('Link Scanner to Profile'), findsOneWidget);
    });

    testWidgets('Defaults to body assessment when initialKind is body or unrecognized', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: const HowbodyLinkSheet(
            equipmentNo: 'INC-01',
            scanId: 'sess_01',
            initialKind: 'unknown_kind_foo',
            onFetchDeviceLabel: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Posture Analysis then switch back to Body Assessment
      await tester.tap(find.text('Posture Analysis'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Body Assessment'));
      await tester.pumpAndSettle();

      expect(find.text('Link Scanner to Profile'), findsOneWidget);
    });

    testWidgets('Validates height boundary and prevents binding when height is out of bounds', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool bindCalled = false;
      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-01',
            scanId: 'sess_01',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async {
              bindCalled = true;
              return HowbodyBindResult.ok();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter an invalid height < 100 cm
      final cmField = find.byType(TextField);
      await tester.enterText(cmField, '50.0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pumpAndSettle();

      expect(bindCalled, isFalse);
      expect(find.text("Height must be between 100 cm and 250 cm (3'3\" – 8'2\")"), findsOneWidget);

      // Enter an invalid height > 250 cm
      await tester.enterText(cmField, '310.0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pumpAndSettle();

      expect(bindCalled, isFalse);
      expect(find.text("Height must be between 100 cm and 250 cm (3'3\" – 8'2\")"), findsOneWidget);

      // Enter valid height: error clears and bind proceeds
      await tester.enterText(cmField, '182.0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bindCalled, isTrue);
      expect(find.text('Step onto the Turntable'), findsOneWidget);
    });
  });

  group('Rapid Multi-Tap Race Condition & Concurrency Prevention', () {
    testWidgets('Prevents duplicate network requests during in-flight bind operation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int bindCallCount = 0;
      final bindCompleter = Completer<HowbodyBindResult>();

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-STRESS-TAP',
            scanId: 'sess_tap_01',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) {
              bindCallCount++;
              return bindCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linkButton = find.text('Link Scanner to Profile');
      expect(linkButton, findsOneWidget);

      // Initial tap
      await tester.tap(linkButton);
      await tester.pump(); // Start async operation & update isLoading

      expect(bindCallCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Rapidly fire multiple taps while network request is in-flight
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Assert only 1 request was sent to the backend
      expect(bindCallCount, equals(1));

      // Resolve the in-flight future
      bindCompleter.complete(HowbodyBindResult.ok());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies successful transition to polling
      expect(find.text('Step onto the Turntable'), findsOneWidget);
    });
  });

  group('Edge Function Error Response & Network Resiliency', () {
    testWidgets('Handles HTTP 400 bad request without crash and allows retry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int bindAttempts = 0;

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-ERR-400',
            scanId: 'sess_400',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async {
              bindAttempts++;
              if (bindAttempts == 1) {
                return HowbodyBindResult.failed(
                  'Invalid session token or kiosk ID (HTTP 400)',
                  code: 'bad_request',
                );
              }
              return HowbodyBindResult.ok();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First attempt fails with 400
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bindAttempts, equals(1));
      expect(find.text('Invalid session token or kiosk ID (HTTP 400)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Step onto the Turntable'), findsNothing);

      // Retry attempt succeeds
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bindAttempts, equals(2));
      expect(find.text('Step onto the Turntable'), findsOneWidget);
    });

    testWidgets('Handles HTTP 500 internal server error gracefully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-ERR-500',
            scanId: 'sess_500',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async {
              return HowbodyBindResult.failed(
                'Unexpected response from scanner server (500)',
                code: 'server_error',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Unexpected response from scanner server (500)'), findsOneWidget);
      expect(find.text('Link Scanner to Profile'), findsOneWidget);
    });

    testWidgets('Catches TimeoutException and SocketException network offline errors cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int attempt = 0;

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-ERR-NET',
            scanId: 'sess_net',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async {
              attempt++;
              if (attempt == 1) {
                throw TimeoutException('Supabase Edge Function timeout after 10000ms');
              } else {
                throw const SocketException('Network offline: Failed host lookup');
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt 1: Timeout
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TimeoutException: Supabase Edge Function timeout after 10000ms'), findsOneWidget);

      // Attempt 2: SocketException
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SocketException: Network offline: Failed host lookup'), findsOneWidget);
    });
  });

  group('Polling State Machine Transitions', () {
    testWidgets('Transitions through pending -> bound -> completed states cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int pollIndex = 0;
      final statuses = [
        HowbodySessionStatus.pending,
        HowbodySessionStatus.bound,
        HowbodySessionStatus.completed,
      ];

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-POLL-01',
            scanId: 'sess_poll_success',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async =>
                HowbodyBindResult.ok(),
            onCheckStatus: (scanId) async {
              final status = statuses[pollIndex.clamp(0, statuses.length - 1)];
              pollIndex++;
              return status;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap link button to enter polling state
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Tick 1 (3 seconds) -> pending
      await tester.pump(const Duration(seconds: 3));
      expect(pollIndex, equals(1));
      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Tick 2 (6 seconds) -> bound
      await tester.pump(const Duration(seconds: 3));
      expect(pollIndex, equals(2));
      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Tick 3 (9 seconds) -> completed
      await tester.pump(const Duration(seconds: 3));
      expect(pollIndex, equals(3));

      // Sheet should be popped and SnackBar displayed
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3D Body Scan Complete! Your clinical report is ready.'), findsOneWidget);
    });

    testWidgets('Tolerates intermittent network errors during polling loop without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int pollIndex = 0;

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-POLL-GLITCH',
            scanId: 'sess_poll_glitch',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async =>
                HowbodyBindResult.ok(),
            onCheckStatus: (scanId) async {
              pollIndex++;
              if (pollIndex == 1) {
                throw Exception('Temporary network blip during polling');
              }
              return HowbodySessionStatus.completed;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tick 1 throws exception -> caught internally, polling keeps ticking
      await tester.pump(const Duration(seconds: 3));
      expect(pollIndex, equals(1));
      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Tick 2 completes -> finishes gracefully
      await tester.pump(const Duration(seconds: 3));
      expect(pollIndex, equals(2));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('3D Body Scan Complete! Your clinical report is ready.'), findsOneWidget);
    });

    testWidgets('Transitions to failed state on status failure and supports retry polling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      int checkCount = 0;
      bool failOnce = true;

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-POLL-FAIL',
            scanId: 'sess_poll_fail',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async =>
                HowbodyBindResult.ok(),
            onCheckStatus: (scanId) async {
              checkCount++;
              if (failOnce) {
                failOnce = false;
                return HowbodySessionStatus.failed;
              }
              return HowbodySessionStatus.completed;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tick 1 -> fails
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Scanner Session Failed'), findsOneWidget);
      expect(find.text('Scan session failed or cancelled at the kiosk.'), findsOneWidget);
      expect(find.text('Retry Polling'), findsOneWidget);

      // Tap Retry Polling
      await tester.tap(find.text('Retry Polling'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Tick 2 -> completes
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3D Body Scan Complete! Your clinical report is ready.'), findsOneWidget);
      expect(checkCount, equals(2));
    });

    testWidgets('Transitions to timeout state after 100 failed polling iterations', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: HowbodyLinkSheet(
            equipmentNo: 'INC-TIMEOUT-01',
            scanId: 'sess_timeout_01',
            onBindScanner: ({
              required equipmentNo,
              required scanId,
              required kind,
              required heightCm,
              memberId,
            }) async =>
                HowbodyBindResult.ok(),
            onCheckStatus: (scanId) async => HowbodySessionStatus.bound,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Advance 101 ticks (303 seconds)
      for (int i = 0; i <= 101; i++) {
        await tester.pump(const Duration(seconds: 3));
      }

      expect(find.text('Scanning Timeout'), findsOneWidget);
      expect(find.text('Acknowledge & Close'), findsOneWidget);

      await tester.tap(find.text('Acknowledge & Close'));
      await tester.pump();
    });
  });

  group('Sheet Disposal & Memory Leak Prevention During Active Timers', () {
    testWidgets('Sheet disposal during active 3s timer does not cause setState after dispose', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  HowbodyLinkSheet.show(
                    context,
                    equipmentNo: 'INC-DISPOSE-01',
                    scanId: 'sess_dispose_01',
                    onBindScanner: ({
                      required equipmentNo,
                      required scanId,
                      required kind,
                      required heightCm,
                      memberId,
                    }) async =>
                        HowbodyBindResult.ok(),
                    onCheckStatus: (scanId) async => HowbodySessionStatus.bound,
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap link button to start 3s periodic timer
      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step onto the Turntable'), findsOneWidget);

      // Advance 1.5 seconds (in the middle of polling interval)
      await tester.pump(const Duration(milliseconds: 1500));

      // Tap Cancel Scan (disposes sheet and cancels timer)
      await tester.tap(find.text('Cancel Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Step onto the Turntable'), findsNothing);

      // Advance time by 30 seconds - verify no pending timer exception or memory leak
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sheet disposal while async status check is in flight does not throw', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final checkCompleter = Completer<HowbodySessionStatus>();

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  HowbodyLinkSheet.show(
                    context,
                    equipmentNo: 'INC-DISPOSE-ASYNC',
                    scanId: 'sess_dispose_async',
                    onBindScanner: ({
                      required equipmentNo,
                      required scanId,
                      required kind,
                      required heightCm,
                      memberId,
                    }) async =>
                        HowbodyBindResult.ok(),
                    onCheckStatus: (scanId) => checkCompleter.future,
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Scanner to Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger first poll tick
      await tester.pump(const Duration(seconds: 3));

      // Dismiss the modal while checkCompleter is in flight
      Navigator.of(tester.element(find.text('Step onto the Turntable'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Step onto the Turntable'), findsNothing);

      // Now resolve the in-flight network call
      checkCompleter.complete(HowbodySessionStatus.completed);
      await tester.pump(const Duration(milliseconds: 100));

      // Assert mounted check prevented any unhandled exception
      expect(tester.takeException(), isNull);
    });
  });

  group('Deep Link Routing & Query String Edge Cases', () {
    testWidgets('Valid /scan-login query string opens HowbodyLinkSheet with posture kind', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('https://inclinegym.com/scan-login?equipmentNo=EQ123&scanId=SC456&kind=posture');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
      expect(find.text('Posture Analysis'), findsOneWidget);
    });

    testWidgets('Valid /howbody-login query string opens HowbodyLinkSheet with body kind', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('https://inclinegym.com/howbody-login?equipmentNo=EQ789&scanId=SC999&kind=body');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
      expect(find.text('Body Assessment'), findsOneWidget);
    });

    testWidgets('Parses alternative query parameter aliases: equipment_no, scan_id, scanType', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('https://inclinegym.com/scan-login?equipment_no=EQ_ALT_1&scan_id=SC_ALT_2&scanType=posture');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
      expect(find.text('Posture Analysis'), findsOneWidget);
    });

    testWidgets('Parses device and session query parameter aliases', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('incline://scan-login?device=EQ_DEV_9&session=SC_SESS_9');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
    });

    testWidgets('Normalizes URL with trailing slash (/scan-login/) and launches sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('https://inclinegym.com/scan-login/?equipmentNo=EQ_SLASH&scanId=SC_SLASH');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
    });

    testWidgets('Missing query string or parameters does not open sheet and does not crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Missing equipmentNo
      DeepLinkService.instance.handleUri(Uri.parse('https://inclinegym.com/scan-login?scanId=SC123'), testContext);
      await tester.pumpAndSettle();
      expect(find.text('Link to Incline 3D Scanner'), findsNothing);

      // 2. Missing scanId
      DeepLinkService.instance.handleUri(Uri.parse('https://inclinegym.com/scan-login?equipmentNo=EQ123'), testContext);
      await tester.pumpAndSettle();
      expect(find.text('Link to Incline 3D Scanner'), findsNothing);

      // 3. Completely empty query string
      DeepLinkService.instance.handleUri(Uri.parse('https://inclinegym.com/scan-login'), testContext);
      await tester.pumpAndSettle();
      expect(find.text('Link to Incline 3D Scanner'), findsNothing);

      // 4. Empty parameters
      DeepLinkService.instance.handleUri(Uri.parse('https://inclinegym.com/scan-login?equipmentNo=&scanId='), testContext);
      await tester.pumpAndSettle();
      expect(find.text('Link to Incline 3D Scanner'), findsNothing);

      // 5. Malformed garbage query string
      DeepLinkService.instance.handleUri(Uri.parse('https://inclinegym.com/scan-login?&&&=&=&unknown=true'), testContext);
      await tester.pumpAndSettle();
      expect(find.text('Link to Incline 3D Scanner'), findsNothing);
    });

    testWidgets('Parses URL with URL-encoded parameters cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      BuildContext? testContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Text('Deep Link Host Screen');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uri = Uri.parse('https://inclinegym.com/scan-login?equipmentNo=EQ%20SPECIAL%201&scanId=SC%20SPECIAL%202');
      DeepLinkService.instance.handleUri(uri, testContext);
      await tester.pumpAndSettle();

      expect(find.text('Link to Incline 3D Scanner'), findsOneWidget);
    });
  });
}
