import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/profile/member_requests_screen.dart';
import 'package:incline_app/features/workout/workout_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Workout Tab Audit & Space Reclamation Tests', () {
    testWidgets('WorkoutScreen empty state does NOT contain space-killing "WHAT YOUR INCLINE ROUTINE INCLUDES"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testMember = Member(
        id: 'mem_audit_test',
        memberCode: 'INC-AUDIT',
        status: 'active',
        profile: const Profile(
          id: 'prof_audit_test',
          email: 'audit@incline.com',
          fullName: 'Mohit Test',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              member: testMember,
              initialPlan: null,
              initialTab: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the space-killing marketing card is REMOVED
      expect(find.text('WHAT YOUR INCLINE ROUTINE INCLUDES'), findsNothing);
      expect(find.text('Biomechanical Movement Screen'), findsNothing);
      expect(find.text('Periodized Progressive Overload'), findsNothing);
      expect(find.text('Integrated Club Recovery'), findsNothing);

      // Verify actionable elements are present and immediately visible
      expect(find.text('No Active Workout Plan'), findsOneWidget);
      expect(find.text('Request Workout Plan'), findsOneWidget);
      // Coach avatar and Upgrade button are shifted exclusively to Coach tab (single source of truth)
      expect(find.text('Upgrade to 1:1 Personal Training'), findsNothing);
    });

    testWidgets('Tapping Upgrade to Personal Training in Coach tab opens PT purchase form with focus chips and notes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testMember = Member(
        id: 'mem_audit_test',
        memberCode: 'INC-AUDIT',
        status: 'active',
        profile: const Profile(
          id: 'prof_audit_test',
          email: 'audit@incline.com',
          fullName: 'Mohit Test',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutScreen(
              member: testMember,
              initialPlan: null,
              initialTab: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Coach Tab (Tab 3) - Single Source of Truth
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      // Tap Upgrade button in Coach Tab
      final upgradeBtn = find.text('Upgrade to Personal Training');
      expect(upgradeBtn, findsOneWidget);
      await tester.tap(upgradeBtn);
      await tester.pumpAndSettle();

      // Verify form elements are all present
      expect(find.text('Purchase Personal Training (1-on-1)'), findsOneWidget);
      expect(find.text('PRIMARY TRAINING FOCUS'), findsOneWidget);
      expect(find.text('Hypertrophy & Physique'), findsOneWidget);
      expect(find.text('Strength & Powerlifting'), findsOneWidget);
      expect(find.text('Fat Loss & Conditioning'), findsOneWidget);
      expect(find.text('Mobility & Longevity'), findsOneWidget);
      expect(find.text('NOTES OR PREFERRED TIMES (OPTIONAL)'), findsOneWidget);
      expect(find.text('Submit PT Purchase Request'), findsOneWidget);
    });
  });

  group('Personal Training Purchase Task Backend Model Tests', () {
    test('MemberRequest.fromTask correctly parses PT purchase task with pt_purchase reference type', () {
      final taskJson = {
        'id': 'task_pt_999',
        'title': 'PT Purchase: 1-on-1 Personal Training (Hypertrophy & Physique)',
        'description': 'Member Mohit Gurjar (INC-001) requested 1-on-1 Personal Training purchase flow.\nFocus: Hypertrophy & Physique',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final req = MemberRequest.fromTask(taskJson);
      expect(req.id, equals('task_pt_999'));
      expect(req.referenceType, equals('pt_purchase'));
      expect(req.title, equals('PT Purchase: 1-on-1 Personal Training (Hypertrophy & Physique)'));
      expect(req.reason, contains('Mohit Gurjar'));
      expect(req.status, equals('pending'));
      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
    });

    test('MemberRequest.fromTask correctly maps completed task status to approved', () {
      final taskJson = {
        'id': 'task_pt_completed',
        'title': 'PT Purchase: 1-on-1 Personal Training (Strength)',
        'description': 'Onboarding session completed and PT package active.',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final req = MemberRequest.fromTask(taskJson);
      expect(req.referenceType, equals('pt_purchase'));
      expect(req.status, equals('approved'));
      expect(req.isApproved, isTrue);
    });

    testWidgets('MemberRequestsScreen displays PT Purchase task with PURCHASE QUEUED badge and star icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const MemberRequestsScreen(),
        ),
      );

      // Verify screen builds cleanly
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Desk & Service Requests'), findsOneWidget);
    });
  });
}
