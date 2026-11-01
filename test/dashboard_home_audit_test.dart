import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/core/widgets/floating_capsule_nav_bar.dart';
import 'package:incline_app/features/home/components/home_hero_card.dart';
import 'package:incline_app/features/home/components/weekly_momentum_card.dart';

void main() {
  group('Home Dashboard Audit & Nav Tests', () {
    testWidgets('HomeHeroCard has Diet quick action and no Check-in button', (tester) async {
      bool dietTapped = false;
      bool bookTapped = false;
      bool workoutTapped = false;
      bool waterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Mohit Gurjar',
                unreadNotifications: 3,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () => bookTapped = true,
                onWorkoutTap: () => workoutTapped = true,
                onWaterTap: () => waterTapped = true,
                onDietTap: () => dietTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Diet is present
      expect(find.text('Diet'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu_rounded), findsOneWidget);

      // Verify Check-in is NOT in the 4 circular buttons
      expect(find.text('Check-in'), findsNothing);

      // Verify other 3 buttons
      expect(find.text('Book'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Hydrate'), findsOneWidget);

      // Tap Diet
      await tester.tap(find.text('Diet'));
      await tester.pump();
      expect(dietTapped, isTrue);

      // Tap Book
      await tester.tap(find.text('Book'));
      await tester.pump();
      expect(bookTapped, isTrue);

      // Tap Workout
      await tester.tap(find.text('Workout'));
      await tester.pump();
      expect(workoutTapped, isTrue);

      // Tap Hydrate
      await tester.tap(find.text('Hydrate'));
      await tester.pump();
      expect(waterTapped, isTrue);
    });

    testWidgets('WeeklyMomentumCard renders 7-day momentum and action buttons', (tester) async {
      bool suiteTapped = false;

      final testAnalysis = MemberAttendanceAnalysis(
        streakDays: 5,
        bestStreakDays: 14,
        totalVisits: 22,
        monthlyVisits: 12,
        isVisitedToday: true,
        habitualTime: '6:00 PM',
        motivationTitle: 'Streak Protected!',
        motivationMessage: 'Good session today.',
        motivationUrgency: 'gentle',
        weekActivity: [true, true, false, true, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyMomentumCard(
                attendanceAnalysis: testAnalysis,
                onReserveSuiteTap: () => suiteTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY MOMENTUM'), findsOneWidget);
      expect(find.text('5 Days Streak 🔥'), findsOneWidget);
      expect(find.text('Book Contrast Suite (Cold Plunge & Sauna)'), findsOneWidget);

      // Tap Contrast Suites
      await tester.tap(find.text('Book Contrast Suite (Cold Plunge & Sauna)'));
      await tester.pump();
      expect(suiteTapped, isTrue);
    });

    testWidgets('FloatingCapsuleNavBar renders selected label without overflow', (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: FloatingCapsuleNavBar(
              selectedIndex: selectedIdx,
              onItemSelected: (idx) => selectedIdx = idx,
              items: const [
                CapsuleNavItem(
                  outlineIcon: Icons.hot_tub_outlined,
                  filledIcon: Icons.hot_tub_rounded,
                  label: 'Bookings',
                ),
                CapsuleNavItem(
                  outlineIcon: Icons.fitness_center_outlined,
                  filledIcon: Icons.fitness_center_rounded,
                  label: 'Workout',
                ),
                CapsuleNavItem(
                  outlineIcon: Icons.home_outlined,
                  filledIcon: Icons.home_rounded,
                  label: 'Home',
                  isCenterHero: true,
                ),
                CapsuleNavItem(
                  outlineIcon: Icons.shopping_bag_outlined,
                  filledIcon: Icons.shopping_bag_rounded,
                  label: 'Store',
                ),
                CapsuleNavItem(
                  outlineIcon: Icons.person_outline_rounded,
                  filledIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No exception or overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Bookings'), findsOneWidget);
    });
  });
}
