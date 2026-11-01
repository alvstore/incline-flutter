import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/views/home_screen.dart';
import 'package:incline_app/features/profile/widgets/profile_registration_details_card.dart';
import 'package:incline_app/features/workout/workout_screen.dart';
import 'package:incline_app/features/diet/diet_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outputDir = '/Users/admin/.gemini/antigravity/brain/8f8ead74-2c22-450e-afbe-89f3cc338119';

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String fileName) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final file = File('$outputDir/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
      }
    });
  }

  testWidgets('Render and capture S10 Home Screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await saveScreenshot(tester, key, 's10_home_redesigned.png');
  });

  testWidgets('Render and capture S10 Profile Dossier', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final dummyMember = Member(
      id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      memberCode: 'INC-2026-0842',
      profile: Profile(
        id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
        fullName: 'Mohit Gurjar',
        email: 'mohit.gurjar@incline.club',
        phone: '+91 98290 12345',
        emergencyContactPhone: '+91 94140 54321',
        emergencyContactName: 'Rajesh Gurjar (Father)',
        address: 'Villa 14, Royal Palm Estates, Vaishali Nagar',
        city: 'Jaipur',
        state: 'Rajasthan',
        postalCode: '302021',
        gender: 'Male',
        governmentIdNumber: '5421 8902 4312',
        dateOfBirth: DateTime(1996, 8, 14),
      ),
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: ProfileRegistrationDetailsCard(
                member: dummyMember,
                onProfileUpdated: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await saveScreenshot(tester, key, 's10_profile_dossier.png');
  });

  testWidgets('Render and capture S10 Empty Workout Routine', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const WorkoutScreen(
              initialPlan: null,
              initialTab: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await saveScreenshot(tester, key, 's10_empty_workout.png');
  });

  testWidgets('Render and capture S10 Empty Diet & Nutrition Tab', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const DietView(
              initialPlan: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await saveScreenshot(tester, key, 's10_empty_diet.png');
  });

  testWidgets('Render and capture S10 General Program Tab (No Plan Assigned)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const WorkoutScreen(
              initialPlan: null,
              initialTab: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await saveScreenshot(tester, key, 's10_empty_program.png');
  });
}
