import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';
import 'package:incline_app/features/progress/components/body_assessment_3d_sheet.dart';
import 'package:incline_app/features/workout/workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = Member(
    id: 'mem_test_01',
    memberCode: 'INC-TEST',
    status: 'active',
    profile: const Profile(id: 'p1', fullName: 'Rajiv Sharma'),
  );

  group('3D Progress Tab Buttons Tests', () {
    testWidgets('Renders icon-only Link Scanner and Export PDF buttons with tooltips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BodyAssessment3DSheet(
              member: testMember,
              isEmbeddedView: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Link scanner icon button exists at the banner
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
      expect(find.byTooltip('Link Scanner'), findsOneWidget);

      // Export PDF icon button exists at the banner
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byTooltip('Export PDF'), findsOneWidget);
    });

    testWidgets('Renders properly in Light Theme without contrast failure or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BodyAssessment3DSheet(
              member: testMember,
              isEmbeddedView: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Link Scanner'), findsOneWidget);
      expect(find.byTooltip('Export PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Coach Tab Audit & UI Verification Tests', () {
    testWidgets('Coach tab renders assigned coach, verified badge, and full-width action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WorkoutScreen(
              member: testMember,
              initialTab: 2, // Coach Tab
              initialPlan: InclineGeneralPrograms.advanceFitnessWorkoutProgram,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Coach Tab Segment Header
      expect(find.text('Coach'), findsWidgets);

      // Coach Verified Badge
      expect(find.byIcon(Icons.verified_rounded), findsWidgets);

      // Status badges
      expect(find.text('GENERAL TRAINING PROGRAM'), findsOneWidget);
      expect(find.text('INCLUDED WITH MEMBERSHIP'), findsOneWidget);

      // Action buttons
      expect(find.text('Upgrade to Personal Training'), findsOneWidget);
      expect(find.text('Call Coach'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Coach tab renders flawlessly in Light Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WorkoutScreen(
              member: testMember,
              initialTab: 2, // Coach Tab
              initialPlan: InclineGeneralPrograms.advanceFitnessWorkoutProgram,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Upgrade to Personal Training'), findsOneWidget);
      expect(find.text('Call Coach'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
