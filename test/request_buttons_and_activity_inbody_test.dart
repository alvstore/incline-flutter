import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/activity/activity_screen.dart';
import 'package:incline_app/features/profile/member_requests_screen.dart';

void main() {
  group('Member Requests & Category Mapping Tests', () {
    testWidgets('MemberRequestsScreen accepts initialCategory workout_plan without DropdownButton assertion crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MemberRequestsScreen(
            initialCategory: 'workout_plan',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet should be rendered without any assertion failure
      expect(find.text('Submit Service Request'), findsOneWidget);
      expect(find.text('Personalised Workout Split Request'), findsWidgets);
      expect(
        find.text('Requesting an updated personalized workout split and training plan from coach.'),
        findsOneWidget,
      );
    });

    testWidgets('MemberRequestsScreen accepts initialCategory diet_plan without DropdownButton assertion crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MemberRequestsScreen(
            initialCategory: 'diet_plan',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Submit Service Request'), findsOneWidget);
      expect(find.text('Personalised Diet Plan Request'), findsWidgets);
      expect(
        find.text('Requesting an updated personalized nutrition and macro-calculated diet plan.'),
        findsOneWidget,
      );
    });
  });

  group('Activity Screen Daily Telemetry & Biometrics Tests', () {
    testWidgets('ActivityScreen displays Supported Frameworks and removes duplicate 3D BMI and mock telemetry', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dummyMember = Member(
        id: 'mem_test',
        memberCode: 'INC-TEST',
        status: 'active',
        fitnessGoals: 'Hypertrophy',
        profile: const Profile(
          id: 'prof_test',
          email: 'test@incline.com',
          fullName: 'Mohit Gurjar',
          avatarUrl: null,
          gender: 'male',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ActivityScreen(member: dummyMember),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify redundant 3D BMI with Posture Assessment is REMOVED from Activity Screen
      expect(find.text('3D BMI with Posture Assessment'), findsNothing);
      expect(find.text('HowBody volumetric contouring, muscle mass & posture scan'), findsNothing);
      expect(find.text('View Scan'), findsNothing);

      // Verify ALL mock/unverifiable telemetry is REMOVED
      expect(find.text('Recovery & Readiness'), findsNothing);
      expect(find.text('Heart Rate Zones & VO2 Max'), findsNothing);
      expect(find.text('Sleep Architecture & Restoration'), findsNothing);
      expect(find.text('Cellular Hydration & Telemetry'), findsNothing);
      expect(find.text('68 ms'), findsNothing);
      expect(find.text('48.5 mL/kg/min'), findsNothing);
      expect(find.text('92% EFFICIENCY'), findsNothing);
      expect(find.text('88% PRIME'), findsNothing);

      // Verify redundant text area for supported sensor telemetry is REMOVED
      expect(find.text('Android: Android Health Connect & Google Fit'), findsNothing);
      expect(find.text('iOS: Apple HealthKit'), findsNothing);
      expect(find.text('Syncing from Galaxy Watch, Pixel Watch, Garmin, Fitbit'), findsNothing);
      expect(find.text('Syncing from Apple Watch, Oura, Whoop'), findsNothing);

      // Verify Sync button after Target in top header is REMOVED from ActivityScreen
      expect(find.text('Targets'), findsOneWidget);
      expect(find.text('Sync'), findsNothing);

      // Verify dedicated Sync button AFTER widgets and ABOVE supported sensor box
      expect(find.text('Sync Wearable Telemetry'), findsOneWidget);

      // Verify collapsible "What These Devices Actually Provide" button/card is present (initially collapsed)
      expect(find.text('What These Devices Actually Provide'), findsOneWidget);
      expect(find.text('Tap to view verified sensor metrics'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('What These Devices Actually Provide'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to collapse'), findsOneWidget);

      // Verify authentic data source contract is shown when expanded
      expect(find.textContaining('Steps'), findsWidgets);
      expect(find.textContaining('Active Calories'), findsWidgets);
      expect(find.textContaining('Workout Minutes'), findsWidgets);
      expect(find.textContaining('Heart Rate'), findsWidgets);
      expect(find.textContaining('Sleep Duration'), findsWidgets);

      // Verify platform-specific badges (Health Connect, HealthKit) are REMOVED for clean platform neutrality
      expect(find.text('Health Connect & Google Fit'), findsNothing);
      expect(find.text('Apple HealthKit'), findsNothing);

      // Verify redundant Edit Targets is removed
      expect(find.text('Edit Targets'), findsNothing);

      // Verify fake Device Linked / Link Tracker badge in AppBar is removed
      expect(find.text('Device Linked'), findsNothing);
      expect(find.text('Link Tracker'), findsNothing);

      // Verify genuine No Sensor state in Bento Grid
      expect(find.text('-- BPM'), findsOneWidget);
      expect(find.text('• No Sensor'), findsOneWidget);
    });
  });
}
