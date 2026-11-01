import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/features/auth/welcome_login_screen.dart';

void main() {
  testWidgets('WelcomeLoginScreen renders precision machine, morphs to unified WhatsApp OTP & Password card with no sanctuary', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeLoginScreen(
          onLoginSuccess: () {},
        ),
      ),
    );

    // 1. Initial State: Machine is present & Telemetry initializing banner is displayed
    expect(find.text('INITIALIZING MEMBER ACCESS PROTOCOL'), findsOneWidget);

    // 2. Advance clock past 1.8 seconds to trigger morph
    await tester.pump(const Duration(milliseconds: 1900));
    // Advance morph animation duration (1200ms)
    await tester.pump(const Duration(milliseconds: 1300));

    // 3. Morphed State: Glassmorphic card is revealed
    expect(find.text('MEMBER ACCESS PORTAL'), findsOneWidget);
    expect(find.text('WhatsApp Member Access'), findsOneWidget);
    expect(find.text('Send WhatsApp Access Code'), findsOneWidget);
    expect(find.text('WhatsApp OTP'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // 4. Invariant: Absolutely NO mention of "sanctuary" on login screen
    expect(find.textContaining('sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctuary', findRichText: true), findsNothing);

    // 5. Test Unified Mode Switcher: Switch from WhatsApp OTP to Password
    await tester.tap(find.text('Password'));
    await tester.pump(const Duration(milliseconds: 400));

    // In Password Mode: Password inputs and CTA are visible on the SAME screen
    expect(find.text('EMAIL OR MOBILE NUMBER'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In with Password'), findsOneWidget);

    // 6. Switch back to WhatsApp OTP
    await tester.tap(find.text('WhatsApp OTP'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Send WhatsApp Access Code'), findsOneWidget);
  });
}
