import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/bookings/bookings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = Member(
    id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
    branchId: '11111111-1111-1111-1111-111111111111',
    memberCode: 'INC-UDR-0042',
    status: 'active',
    profile: const Profile(
      id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      fullName: 'Mohit Gurjar',
      phone: '+918209887831',
      email: 'mohitgurjarawanaa@gmail.com',
    ),
  );

  testWidgets('BookingsScreen Suites tab verifies Cold Plunge terminology and zero RenderFlex overflow', (tester) async {
    // S10 display resolution
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BookingsScreen(
            member: testMember,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Suites tab toggle exists and tap it
    final suitesTab = find.text('Suites');
    expect(suitesTab, findsOneWidget);
    await tester.tap(suitesTab);
    await tester.pumpAndSettle();

    // 2. Verify terminology is Cold Plunge and NEVER Ice Bath
    expect(find.text('Cold Plunge'), findsWidgets);
    expect(find.textContaining('Ice Bath'), findsNothing);
    expect(find.textContaining('Ice Plunge'), findsNothing);

    // 3. Scroll to and tap Cold Plunge filter chip
    final coldPlungeFinder = find.widgetWithText(FilterChip, 'Cold Plunge');
    expect(coldPlungeFinder, findsOneWidget);
    await tester.ensureVisible(coldPlungeFinder);
    await tester.tap(coldPlungeFinder);
    await tester.pumpAndSettle();

    // 4. Verify Sub-Zero Cold Plunge is displayed in the list and "Ice Bath" is nowhere
    expect(find.text('Sub-Zero Cold Plunge'), findsWidgets);
    expect(find.textContaining('Ice Bath'), findsNothing);
    expect(find.textContaining('Ice Plunge'), findsNothing);

    // 5. Verify singleChildScrollView exists to prevent overflow
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
