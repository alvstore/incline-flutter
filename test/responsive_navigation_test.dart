import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/core/widgets/floating_capsule_nav_bar.dart';
import 'package:incline_app/features/home/components/home_hero_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget navHarness({required double width, required double textScale}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          bottomNavigationBar: FloatingCapsuleNavBar(
            selectedIndex: 0,
            onItemSelected: (_) {},
            items: const [
              CapsuleNavItem(
                outlineIcon: Icons.event_outlined,
                filledIcon: Icons.event,
                label: 'Bookings',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.fitness_center_outlined,
                filledIcon: Icons.fitness_center,
                label: 'Workout',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.home_outlined,
                filledIcon: Icons.home,
                label: 'Home',
                isCenterHero: true,
              ),
              CapsuleNavItem(
                outlineIcon: Icons.store_outlined,
                filledIcon: Icons.store,
                label: 'Store',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.person_outline,
                filledIcon: Icons.person,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('capsule navigation fits narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(navHarness(width: 320, textScale: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingCapsuleNavBar), findsOneWidget);
  });

  testWidgets('capsule navigation fits large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(navHarness(width: 390, textScale: 1.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('home hero fits narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Alexandria Verylonglastname',
                unreadNotifications: 120,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
                onDietTap: () {},
                onCheckInTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('99+'), findsOneWidget);
  });
}
