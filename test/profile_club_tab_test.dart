import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = Member(
    id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
    branchId: 'b1',
    memberCode: 'INC-UDR-0042',
    status: 'active',
    profile: const Profile(
      id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      fullName: 'Mohit Gurjar',
      phone: '+918209887831',
      email: 'mohitgurjarawanaa@gmail.com',
    ),
  );

  testWidgets('ProfileScreen renders redesigned 2026 profile adhering to all user specifications', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testMembership = Membership(
      id: 'm1',
      memberId: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      planName: "Essential Annual - Founder's Pass",
      status: 'active',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime.now().add(const Duration(days: 278)),
      daysRemaining: 278,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            member: testMember,
            initialMembership: testMembership,
            onSignOut: () {},
          ),
        ),
      ),
    );

    // Allow animations (plan bento counter) to settle
    await tester.pumpAndSettle();

    // 1. Verify Member Dossier Hero (Without Gate Pass)
    expect(find.text('Mohit Gurjar'), findsWidgets);
    expect(find.text('INC-UDR-0042'), findsWidgets);
    expect(find.text('TOUCHLESS GATE PASS'), findsNothing); // Gate pass removed

    // 2. Verify Animated "Your Plan" Bento Hero (Days left, Date of joining, nothing else)
    expect(find.text('YOUR PLAN'), findsOneWidget);
    expect(find.text("Essential Annual - Founder's Pass"), findsOneWidget);
    expect(find.text('278'), findsOneWidget);
    expect(find.text('DAYS LEFT'), findsOneWidget);
    expect(find.textContaining('Joined '), findsOneWidget);
    expect(find.text('Main Gym Floor Access'), findsNothing); // Extra chips removed

    // 3. Verify Personal Coach is NOT shown on Profile
    expect(find.text('PERSONAL COACH'), findsNothing);
    expect(find.text('Bhagirath Gurjar'), findsNothing);

    // 4. Verify Flagship store / concierge card is NOT shown on Profile
    expect(find.text('FLAGSHIP CLUB LOCATION'), findsNothing);

    // 5. Verify Referral Card (Invite & Track)
    expect(find.text('INVITE & TRACK'), findsOneWidget);
    expect(find.text('Refer Friends & Earn'), findsOneWidget);

    // 6. Verify 2x2 Services Bento Grid
    expect(find.text('MEMBER SERVICES & ACCOUNT'), findsOneWidget);
    expect(find.text('Invoices & Receipts'), findsOneWidget);
    expect(find.text('Turnstile Logs'), findsOneWidget);
    expect(find.text('Desk Requests'), findsOneWidget);
    expect(find.text('Club Feedback'), findsOneWidget);

    // 7. Verify KYC Dossier tab switching and official dossier elements
    await tester.tap(find.text('KYC Dossier'));
    await tester.pumpAndSettle();
    expect(find.text('OFFICIAL KYC DOSSIER'), findsOneWidget);

    // 8. Verify Security & Club tab switching, Google Maps, Call Club Buttons, and Sign Out
    await tester.tap(find.text('Security & Club'));
    await tester.pumpAndSettle();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Club Location'), findsOneWidget);
    expect(find.text('Call Club'), findsOneWidget);
    expect(find.text('Concierge Desk'), findsOneWidget);
    expect(find.text('Sign Out Active Session'), findsOneWidget);

    // 9. Verify Trademark Registered Brand Footer with Tagline
    expect(find.text('RISE • REFLECT • REPEAT'), findsWidgets);
    expect(find.textContaining('TRADE MARK REGISTERED'), findsOneWidget);

    // 10. Strict Invariant: Absolutely ZERO occurrences of "sanctuary", "Sanctuary", "VIP", "Sanctum"
    expect(find.textContaining('sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('sanctum', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctum', findRichText: true), findsNothing);
    expect(find.textContaining('VIP', findRichText: true), findsNothing);
  });
}
