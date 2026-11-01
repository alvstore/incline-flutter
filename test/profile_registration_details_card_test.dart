import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/profile/widgets/profile_registration_details_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockMember = Member(
    id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
    branchId: 'b1',
    memberCode: 'INC-26-0025',
    status: 'active',
    profile: Profile(
      id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      fullName: 'Mohit Gurjar',
      phone: '+91 82098 87831',
      email: 'mohitgurjarawanaa@gmail.com',
      dateOfBirth: DateTime(1997, 7, 31),
      address: 'Plot 44-55, Near Kheda Circle, Hiran Magri Sector 14',
      city: 'Udaipur',
      state: 'Rajasthan',
      postalCode: '313001',
      governmentIdNumber: '820988783125',
      emergencyContactName: 'Bhagirath gurjar',
      emergencyContactPhone: '+91 7014492634',
    ),
  );

  group('ProfileRegistrationDetailsCard Widget Tests', () {
    testWidgets('Renders all dossier elements in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Identity
      expect(find.text('OFFICIAL KYC DOSSIER'), findsOneWidget);
      expect(find.text('Member Registration Dossier'), findsOneWidget);
      expect(find.text('Authoritative KYC & correspondence record'), findsOneWidget);
      expect(find.text('Mohit Gurjar'), findsOneWidget);
      expect(find.text('INC-26-0025'), findsOneWidget);
      expect(find.text('Verified Admission Identity'), findsOneWidget);

      // Official KYC section
      expect(find.text('OFFICIAL KYC RECORDS'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('+91 82098 87831'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('31 Jul 1997'), findsOneWidget);
      expect(find.textContaining('Years'), findsOneWidget);

      // Masked Aadhaar by default
      expect(find.text('XXXX  XXXX  3125'), findsOneWidget);

      // Emergency contact & call button
      expect(find.textContaining('Bhagirath gurjar'), findsOneWidget);
      expect(find.textContaining('+91 7014492634'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);

      // Correspondence section
      expect(find.text('RESIDENTIAL & CORRESPONDENCE'), findsOneWidget);
      expect(find.text('SELF-SERVICE'), findsOneWidget);
      expect(find.text('mohitgurjarawanaa@gmail.com'), findsOneWidget);
      expect(find.textContaining('Hiran Magri'), findsOneWidget);

      // Invariant: Zero QR codes
      expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
      expect(find.byIcon(Icons.qr_code), findsNothing);
    });

    testWidgets('Toggles Aadhaar visibility between masked and unmasked', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially masked
      expect(find.text('XXXX  XXXX  3125'), findsOneWidget);
      expect(find.text('8209 8878 3125'), findsNothing);

      // Tap reveal icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Full Aadhaar revealed
      expect(find.text('8209 8878 3125'), findsOneWidget);
      expect(find.text('XXXX  XXXX  3125'), findsNothing);

      // Tap mask icon again
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      // Masked again
      expect(find.text('XXXX  XXXX  3125'), findsOneWidget);
    });

    testWidgets('Renders properly in Light Mode without errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Member Registration Dossier'), findsOneWidget);
      expect(find.text('Mohit Gurjar'), findsOneWidget);
      expect(find.text('INC-26-0025'), findsOneWidget);
    });

    testWidgets('Copies member code, phone, Aadhaar, and emergency contact to clipboard with toast', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Copy member code
      await tester.tap(find.text('INC-26-0025'));
      await tester.pumpAndSettle();
      expect(find.text('Member code copied to clipboard'), findsOneWidget);

      // 2. Copy phone
      await tester.tap(find.byIcon(Icons.copy_rounded).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Phone number copied to clipboard'), findsOneWidget);

      // 3. Copy Aadhaar
      await tester.tap(find.byIcon(Icons.copy_rounded).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Aadhaar number copied to clipboard'), findsOneWidget);

      // 4. Copy Emergency Contact
      await tester.tap(find.byIcon(Icons.copy_rounded).at(3));
      await tester.pumpAndSettle();
      expect(find.text('Emergency contact copied to clipboard'), findsOneWidget);
    });

    testWidgets('Opens Edit Sheet and distinguishes locked KYC from editable fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Edit" button
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Verify sheet is open
      expect(find.text('MEMBER REGISTRATION DOSSIER'), findsOneWidget);
      expect(find.text('Update Registration Details'), findsOneWidget);
      expect(find.text('Authoritative KYC Protected'), findsOneWidget);

      // Verify locked official KYC section
      expect(find.text('Official KYC • Read Only'), findsOneWidget);
      expect(find.text('LEGAL FULL NAME'), findsOneWidget);
      expect(find.text('PRIMARY MOBILE'), findsOneWidget);
      expect(find.text('EMERGENCY NEXT OF KIN'), findsOneWidget);

      // Verify self-service editable section
      expect(find.text('SELF-SERVICE EDITABLE FIELDS'), findsOneWidget);
      expect(find.text('Direct Supabase Sync'), findsOneWidget);
      expect(find.text('PERSONAL EMAIL ADDRESS'), findsOneWidget);

      // Scroll further down to view bottom fields and save button
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('RESIDENTIAL STREET ADDRESS'), findsOneWidget);
      expect(find.text('CITY'), findsOneWidget);
      expect(find.text('STATE'), findsOneWidget);
      expect(find.text('PIN CODE'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify save button exists
      expect(find.text('Save & Synchronize Dossier'), findsOneWidget);
    });

    testWidgets('Updates correspondence fields via edit sheet and updates card immediately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      Profile? reportedProfile;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: mockMember,
                onProfileUpdated: (updated) {
                  reportedProfile = updated;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Edit" button
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Enter new email
      final emailFinder = find.widgetWithText(TextFormField, 'PERSONAL EMAIL ADDRESS');
      await tester.enterText(emailFinder, 'updated.member@incline.club');

      // Scroll down
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Enter new address
      final addressFinder = find.widgetWithText(TextFormField, 'RESIDENTIAL STREET ADDRESS');
      await tester.enterText(addressFinder, 'Penthouse 12, Skyline Tower');

      // Tap Save
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Synchronize Dossier'));
      await tester.pumpAndSettle();

      // Verify callback was invoked
      expect(reportedProfile, isNotNull);
      expect(reportedProfile!.email, equals('updated.member@incline.club'));
      expect(reportedProfile!.address, equals('Penthouse 12, Skyline Tower'));

      // Verify card in-place state was updated without parent rebuild
      expect(find.text('updated.member@incline.club'), findsOneWidget);
      expect(find.textContaining('Penthouse 12'), findsOneWidget);
    });

    testWidgets('Preserves data privacy for a member with null profile fields (no Mohit data leakage)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final memberWithNulls = Member(
        id: 'mem_jane_doe',
        memberCode: 'INC-2026-8888',
        status: 'active',
        profile: const Profile(
          id: 'mem_jane_doe',
          fullName: 'Jane Doe',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: memberWithNulls,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('INC-2026-8888'), findsOneWidget);

      // Verify 'Not Provided' is displayed instead of Mohit's personal data
      expect(find.text('+91 82098 87831'), findsNothing);
      expect(find.text('820988783125'), findsNothing);
      expect(find.text('Bhagirath gurjar'), findsNothing);
      expect(find.textContaining('Hiran Magri'), findsNothing);
      expect(find.text('Not Provided'), findsWidgets);
    });

    testWidgets('Preview builders execute without throwing', (tester) async {
      await tester.pumpWidget(previewProfileRegistrationDetailsCardDark());
      await tester.pumpAndSettle();
      expect(find.text('Member Registration Dossier'), findsOneWidget);

      await tester.pumpWidget(previewProfileRegistrationDetailsCardLight());
      await tester.pumpAndSettle();
      expect(find.text('Member Registration Dossier'), findsOneWidget);
    });

    testWidgets('Renders zero overflow errors on narrow screen with null member/profile', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileRegistrationDetailsCard(
                member: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Member Registration Dossier'), findsOneWidget);
      expect(find.text('Incline Member'), findsOneWidget);
      expect(find.text('INC-26-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

