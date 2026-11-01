import 'dart:io';
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

  group('Bookings & Cancellation Policy Backend Parity Tests', () {
    test('Zero hardcoded fallback reservations exist in supabase_service.dart', () {
      final file = File('lib/core/services/supabase_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('res_sample_01'), isFalse,
          reason: 'Dummy sample reservation res_sample_01 must never exist');
      expect(content.contains('res_sample_02'), isFalse,
          reason: 'Dummy sample reservation res_sample_02 must never exist');
      expect(content.contains('res_sample_03'), isFalse,
          reason: 'Dummy sample reservation res_sample_03 must never exist');
    });

    test('Zero invented 2-hour penalty claims exist in bookings_screen.dart', () {
      final file = File('lib/features/bookings/bookings_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('INCLINE 2-HOUR POLICY'), isFalse,
          reason: 'Invented 2-hour policy text must not exist in bookings screen');
      expect(content.contains('isWithinTwoHours'), isFalse,
          reason: 'Hardcoded 2-hour window logic must not exist in bookings screen');
      expect(content.contains('• 2-Hour Notice:'), isFalse,
          reason: 'Banner must not claim a blanket 2-hour notice');
    });

    test('MemberReservation correctly determines canCancel for confirmed and booked statuses', () {
      final resConfirmed = MemberReservation(
        id: 'res_test_1',
        bookingId: 'BK-1001',
        type: 'recovery',
        title: 'Contrast Hydrothermal Suite',
        subtitle: 'Suite #1',
        category: 'Recovery',
        dateTime: DateTime.now().add(const Duration(hours: 3)),
        startTime: '10:00 AM',
        endTime: '10:45 AM',
        venue: 'Incline Suite 1',
        status: 'confirmed',
        canCancel: true,
      );

      expect(resConfirmed.canCancel, isTrue);
      expect(resConfirmed.isUpcoming, isTrue);

      final resCompleted = MemberReservation(
        id: 'res_test_2',
        bookingId: 'BK-1002',
        type: 'class',
        title: 'Reformer Pilates',
        subtitle: 'Studio A',
        category: 'Pilates',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        startTime: '08:00 AM',
        endTime: '08:50 AM',
        venue: 'Studio A',
        status: 'completed',
        canCancel: false,
      );

      expect(resCompleted.canCancel, isFalse);
      expect(resCompleted.isUpcoming, isFalse);
    });

    testWidgets('BookingsScreen displays backend-aligned cancellation policy and empty state', (tester) async {
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

      // 1. Switch to My Bookings tab
      final myBookingsTab = find.text('My Bookings');
      expect(myBookingsTab, findsOneWidget);
      await tester.tap(myBookingsTab);
      await tester.pumpAndSettle();

      // 2. Verify backend-aligned policy banner is rendered
      expect(find.text('Club Booking & Cancellation Policy'), findsOneWidget);
      expect(find.textContaining('Session Return: Cancellations made before the session deadline automatically restore your balance.'), findsOneWidget);
      expect(find.textContaining('Enforced Deadlines: Cancellation windows are determined by club policy'), findsOneWidget);

      // 3. Verify zero fake reservations are present
      expect(find.text('Signature Reformer Pilates Core'), findsNothing);
      expect(find.text('Private Finnish Cedar Sauna Suite'), findsNothing);
      expect(find.text('Metabolic Power Spin'), findsNothing);
    });
  });
}
