import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/features/onboarding/permissions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppPermissionsScreen renders luxury launch permission screen with zero sanctuary text', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AppPermissionsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header & Titles
    expect(find.text('Member Telemetry & Permissions'), findsOneWidget);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);

    // 2. Verify 4 Permission Cards
    expect(find.text('Turnstile & Proximity'), findsOneWidget);
    expect(find.text('Biometrics & Wearables'), findsOneWidget);
    expect(find.text('Club & Suite Alerts'), findsOneWidget);
    expect(find.text('Camera & Body Scans'), findsOneWidget);

    // 3. Verify CTAs
    expect(find.text('ACTIVATE TELEMETRY & ENTER CLUB'), findsOneWidget);
    expect(find.text('Review Later in Settings'), findsOneWidget);

    // 4. Strict Invariant: Absolutely ZERO occurrences of "sanctuary", "Sanctuary", "VIP", "Sanctum"
    expect(find.textContaining('sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('sanctum', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctum', findRichText: true), findsNothing);
    expect(find.textContaining('VIP', findRichText: true), findsNothing);
  });
}
