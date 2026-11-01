import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/schema_models.dart';

void main() {
  group('Supabase Schema Models Serialization & Null-Safety Tests', () {
    test('InclineMember serializes and deserializes accurately matching Postgres schema', () {
      final now = DateTime.now();
      final memberJson = {
        'id': 'd83c913f-9bd0-4389-a877-0918cb28c6d7',
        'user_id': '88888888-8888-8888-8888-888888888888',
        'branch_id': '11111111-1111-1111-1111-111111111111',
        'member_code': 'INC-26-0025',
        'status': 'active',
        'source': 'vip_invite',
        'fitness_goals': 'Hypertrophy & Longevity',
        'workout_activities': ['strength', 'contrast_therapy', 'pilates'],
        'reward_points': 450,
        'bot_active': true,
        'joined_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final member = InclineMember.fromJson(memberJson);
      expect(member.id, 'd83c913f-9bd0-4389-a877-0918cb28c6d7');
      expect(member.memberCode, 'INC-26-0025');
      expect(member.workoutActivities.length, 3);
      expect(member.rewardPoints, 450);
      expect(member.botActive, isTrue);

      final outJson = member.toJson();
      expect(outJson['member_code'], 'INC-26-0025');
      expect(outJson['reward_points'], 450);
    });

    test('PtSessionSettlement serializes and deserializes accurately', () {
      final settlementJson = {
        'id': 'a1111111-2222-3333-4444-555555555555',
        'commission_id': 'b1111111-2222-3333-4444-555555555555',
        'trainer_id': 'c1111111-2222-3333-4444-555555555555',
        'payout_month': '2026-10-01',
        'installment_index': 2,
        'installment_amount': 14500.0,
        'status': 'paid',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final settlement = PtSessionSettlement.fromJson(settlementJson);
      expect(settlement.id, 'a1111111-2222-3333-4444-555555555555');
      expect(settlement.installmentIndex, 2);
      expect(settlement.installmentAmount, 14500.0);
      expect(settlement.status, 'paid');
    });

    test('ClassBookingRecord and BenefitBookingRecord serialize and deserialize accurately', () {
      final classBookingJson = {
        'id': 'bk-001',
        'class_id': 'cls-001',
        'member_id': 'mem-001',
        'status': 'booked',
        'booked_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final classBooking = ClassBookingRecord.fromJson(classBookingJson);
      expect(classBooking.id, 'bk-001');
      expect(classBooking.status, 'booked');

      final benefitBookingJson = {
        'id': 'bbk-001',
        'slot_id': 'slt-001',
        'member_id': 'mem-001',
        'membership_id': 'mms-001',
        'status': 'booked',
        'booked_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final benefitBooking = BenefitBookingRecord.fromJson(benefitBookingJson);
      expect(benefitBooking.id, 'bbk-001');
      expect(benefitBooking.status, 'booked');
    });
  });
}
