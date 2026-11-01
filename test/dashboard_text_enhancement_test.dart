import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/components/home_hero_card.dart';

void main() {
  group('Incline Fitness Dashboard Text Enhancement Tests', () {
    testWidgets('Streak section displays YOUR STREAK, dynamic plural/singular, and motivational copy', (tester) async {
      // 1. Streak >= 7: ONE WEEK STRONG and "7 Days"
      final analysis7 = MemberAttendanceAnalysis(
        streakDays: 7,
        bestStreakDays: 14,
        totalVisits: 30,
        monthlyVisits: 14,
        isVisitedToday: false,
        habitualTime: '7:00 AM',
        motivationTitle: 'Unstoppable',
        motivationMessage: 'Keep going!',
        motivationUrgency: 'gentle',
        weekActivity: const [true, true, false, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                attendanceAnalysis: analysis7,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Eyebrow
      expect(find.text('YOUR STREAK'), findsOneWidget);
      // Metric
      expect(find.text('7 Days'), findsOneWidget);
      // Motivational trend pill
      expect(find.text('ONE WEEK STRONG'), findsOneWidget);
      // Floor check-in available
      expect(find.text('Floor Check-In Ready'), findsOneWidget);
      // Subtitle without streak repeat
      expect(find.text('2 of 7 days completed'), findsOneWidget);
      // Percentage & Weekly Activity label
      expect(find.text('28%'), findsOneWidget);
      expect(find.text('WEEKLY ACTIVITY'), findsOneWidget);
    });

    testWidgets('Streak singular 1 Day and BUILDING MOMENTUM', (tester) async {
      final analysis1 = MemberAttendanceAnalysis(
        streakDays: 1,
        bestStreakDays: 5,
        totalVisits: 10,
        monthlyVisits: 4,
        isVisitedToday: false,
        habitualTime: '6:00 PM',
        motivationTitle: 'Great start',
        motivationMessage: 'Building up',
        motivationUrgency: 'gentle',
        weekActivity: const [true, false, false, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                attendanceAnalysis: analysis1,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR STREAK'), findsOneWidget);
      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('BUILDING MOMENTUM'), findsOneWidget);
      expect(find.text('1 of 7 days completed'), findsOneWidget);
      expect(find.text('WEEKLY ACTIVITY'), findsOneWidget);
    });

    testWidgets('Streak 4..6 displays KEEP IT GOING', (tester) async {
      final analysis4 = MemberAttendanceAnalysis(
        streakDays: 4,
        bestStreakDays: 10,
        totalVisits: 20,
        monthlyVisits: 8,
        isVisitedToday: false,
        habitualTime: '6:00 PM',
        motivationTitle: 'On track',
        motivationMessage: 'Keep it going',
        motivationUrgency: 'gentle',
        weekActivity: const [true, true, true, true, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                attendanceAnalysis: analysis4,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 Days'), findsOneWidget);
      expect(find.text('KEEP IT GOING'), findsOneWidget);
      expect(find.text('4 of 7 days completed'), findsOneWidget);
    });

    testWidgets('Zero streak displays START YOUR STREAK with no false celebration', (tester) async {
      final analysis0 = MemberAttendanceAnalysis(
        streakDays: 0,
        bestStreakDays: 10,
        totalVisits: 20,
        monthlyVisits: 0,
        isVisitedToday: false,
        habitualTime: '6:00 PM',
        motivationTitle: 'New start',
        motivationMessage: 'Start streak',
        motivationUrgency: 'gentle',
        weekActivity: const [false, false, false, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                streakDays: 0,
                attendanceAnalysis: analysis0,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 Days'), findsOneWidget);
      expect(find.text('START YOUR STREAK'), findsOneWidget);
      expect(find.text('0 of 7 days completed'), findsOneWidget);
    });

    testWidgets('Session status shows Today\'s Session Logged ✓ when isVisitedToday is true', (tester) async {
      final analysisLogged = MemberAttendanceAnalysis(
        streakDays: 5,
        bestStreakDays: 14,
        totalVisits: 25,
        monthlyVisits: 10,
        isVisitedToday: true,
        habitualTime: '7:00 AM',
        motivationTitle: 'Logged',
        motivationMessage: 'Done',
        motivationUrgency: 'completed',
        weekActivity: const [true, true, true, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                attendanceAnalysis: analysisLogged,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Session Logged ✓"), findsOneWidget);
      expect(find.text('3 of 7 days completed'), findsOneWidget);
    });

    testWidgets('Session status shows Your Session Is Underway when todayCheckIn exists but not completed', (tester) async {
      final analysisUnderway = MemberAttendanceAnalysis(
        streakDays: 5,
        bestStreakDays: 14,
        totalVisits: 25,
        monthlyVisits: 10,
        isVisitedToday: false,
        todayCheckIn: DateTime.now().subtract(const Duration(minutes: 30)),
        habitualTime: '7:00 AM',
        motivationTitle: 'In progress',
        motivationMessage: 'Work hard',
        motivationUrgency: 'gentle',
        weekActivity: const [true, true, false, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                attendanceAnalysis: analysisUnderway,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Session Is Underway'), findsOneWidget);
    });

    testWidgets('Session status shows Ready for Your Next Session when membership is inactive', (tester) async {
      final analysisInactive = MemberAttendanceAnalysis(
        streakDays: 0,
        bestStreakDays: 14,
        totalVisits: 25,
        monthlyVisits: 0,
        isVisitedToday: false,
        habitualTime: '7:00 AM',
        motivationTitle: 'Renew',
        motivationMessage: 'See you soon',
        motivationUrgency: 'gentle',
        weekActivity: const [false, false, false, false, false, false, false],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeHeroCard(
                memberName: 'Test Athlete',
                membershipStatus: 'EXPIRED',
                attendanceAnalysis: analysisInactive,
                unreadNotifications: 0,
                onNotificationTap: () {},
                onProfileTap: () {},
                onBookTap: () {},
                onWorkoutTap: () {},
                onWaterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready for Your Next Session'), findsOneWidget);
    });
  });
}
