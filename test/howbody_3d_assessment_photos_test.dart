import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/components/inbody_scan_sheet.dart';

void main() {
  group('HowBody 3D Scan Models Serialization Tests', () {
    test('HowbodyBodyReport parses all clinical metrics correctly from Supabase json', () {
      final json = {
        'id': 'body_scan_01',
        'member_id': 'mem_01',
        'data_key': 'key_body_01',
        'test_time': '2026-10-27T10:30:00Z',
        'weight': 76.4,
        'bmi': 23.8,
        'pbf': 14.8,
        'fat': 11.3,
        'smm': 37.2,
        'tbw': 48.5,
        'bmr': 1780,
        'vfr': 4,
        'metabolic_age': 25,
        'whr': 0.82,
        'health_score': 91,
        'target_weight': 75.0,
        'weight_control': -1.4,
        'fat_control': -1.8,
        'muscle_control': 0.4,
        'equipment_no': 'INC-HOWBODY-UDR-01',
      };

      final report = HowbodyBodyReport.fromJson(json);

      expect(report.id, 'body_scan_01');
      expect(report.weight, 76.4);
      expect(report.bmi, 23.8);
      expect(report.pbf, 14.8);
      expect(report.smm, 37.2);
      expect(report.bmr, 1780.0);
      expect(report.vfr, 4);
      expect(report.metabolicAge, 25);
      expect(report.healthScore, 91);
      expect(report.targetWeight, 75.0);
      expect(report.equipmentNo, 'INC-HOWBODY-UDR-01');
    });

    test('HowbodyPostureReport parses deviations, circumferences and multi-angle photos', () {
      final json = {
        'id': 'posture_scan_01',
        'member_id': 'mem_01',
        'data_key': 'key_posture_01',
        'test_time': '2026-10-27T10:35:00Z',
        'score': 88,
        'body_slope': 1.2,
        'head_forward': 2.4,
        'head_slant': -0.8,
        'shoulder_left': 0.5,
        'shoulder_right': -0.5,
        'high_low_shoulder': 1.0,
        'pelvis_forward': 3.1,
        'knee_left': 0.4,
        'knee_right': -0.2,
        'bust': 98.5,
        'waist': 81.2,
        'hip': 97.4,
        'left_thigh': 57.0,
        'right_thigh': 56.8,
        'calf_left': 38.5,
        'calf_right': 38.2,
        'up_arm_left': 34.2,
        'up_arm_right': 34.5,
        'front_img': 'https://incline.co/scans/front.jpg',
        'left_img': 'https://incline.co/scans/left.jpg',
        'right_img': 'https://incline.co/scans/right.jpg',
        'back_img': 'https://incline.co/scans/back.jpg',
        'model_url': 'https://incline.co/scans/avatar3d.glb',
        'equipment_no': 'INC-HOWBODY-UDR-01',
        'posture_type': 'Neutral Athletic',
      };

      final report = HowbodyPostureReport.fromJson(json);

      expect(report.id, 'posture_scan_01');
      expect(report.score, 88);
      expect(report.bust, 98.5);
      expect(report.waist, 81.2);
      expect(report.hip, 97.4);
      expect(report.headForward, 2.4);
      expect(report.highLowShoulder, 1.0);
      expect(report.frontImg, 'https://incline.co/scans/front.jpg');
      expect(report.modelUrl, 'https://incline.co/scans/avatar3d.glb');

      // Verify photos getter extracts all 4 multi-angle views
      final photos = report.photos;
      expect(photos.length, 4);
      expect(photos[0].label, 'Front View');
      expect(photos[0].url, 'https://incline.co/scans/front.jpg');
      expect(photos[1].label, 'Left Profile');
      expect(photos[2].label, 'Right Profile');
      expect(photos[3].label, 'Back View');
    });

    test('HowbodyScanResult combines body, posture and photos cleanly', () {
      final body = HowbodyBodyReport(id: 'b1', weight: 75.0, bmi: 23.1);
      final posture = HowbodyPostureReport(
        id: 'p1',
        score: 90,
        frontImg: 'https://incline.co/f.jpg',
      );

      final result = HowbodyScanResult(
        body: body,
        posture: posture,
        pdfUrl: 'https://incline.co/scans/report.pdf',
      );

      expect(result.hasData, isTrue);
      expect(result.photos.length, 1);
      expect(result.photos.first.angle, 'Front');
      expect(result.pdfUrl, 'https://incline.co/scans/report.pdf');
    });
  });

  group('InBodyScanSheet UI Rendering & Zero-Mock Baseline Tests', () {
    testWidgets('InBodyScanSheet renders header and handles empty state without mock data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testMember = Member(
        id: 'mem_test_empty',
        memberCode: 'INC-EMPTY',
        status: 'active',
        profile: const Profile(id: 'p1', fullName: 'Test Member'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: InBodyScanSheet(member: testMember),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header should always be rendered
      expect(find.text('3D Body Assessment'), findsOneWidget);
      expect(find.textContaining('Composition & Posture Telemetry'), findsOneWidget);

      // Verify no fake 14.5% body fat or fake 88 score is displayed in empty state
      expect(find.text('14.5%'), findsNothing);
      expect(find.text('88/100'), findsNothing);

      // Verify Manual Measurements section is present
      expect(find.text('MANUAL HEALTH MEASUREMENTS'), findsOneWidget);
      expect(find.text('Record Now'), findsOneWidget);
    });
  });
}
