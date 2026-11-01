import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/profile/widgets/profile_referral_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Referral Link & Registration URI Tests', () {
    test('Referral link conforms to authoritative format with url-encoded member code', () {
      const memberCode = 'INC-26-0015';
      final encoded = Uri.encodeComponent(memberCode);
      final inviteLink = 'https://theincline.in/register?ref=$encoded';

      expect(inviteLink, equals('https://theincline.in/register?ref=INC-26-0015'));
      expect(Uri.parse(inviteLink).queryParameters['ref'], equals('INC-26-0015'));
    });

    test('Referral link correctly encodes special characters in member code', () {
      const complexCode = 'INC/26+0015#VIP';
      final encoded = Uri.encodeComponent(complexCode);
      final inviteLink = 'https://theincline.in/register?ref=$encoded';

      expect(inviteLink, contains('INC%2F26%2B0015%23VIP'));
      expect(Uri.parse(inviteLink).queryParameters['ref'], equals('INC/26+0015#VIP'));
    });
  });

  group('ReferralReward Model & Status Tests', () {
    test('ReferralReward parses database JSON and computes getters accurately', () {
      final jsonPending = {
        'id': 'rew_001',
        'member_id': 'mem_123',
        'referral_id': 'ref_456',
        'reward_type': 'wallet_credit',
        'reward_value': 500.0,
        'claim_status': 'pending_approval',
        'description': 'Referral bonus for Rahul S.',
        'created_at': '2026-10-25T10:00:00Z',
      };

      final rewardPending = ReferralReward.fromJson(jsonPending);
      expect(rewardPending.id, equals('rew_001'));
      expect(rewardPending.rewardValue, equals(500.0));
      expect(rewardPending.claimStatus, equals('pending_approval'));
      expect(rewardPending.isAwaitingApproval, isTrue);
      expect(rewardPending.isClaimed, isFalse);

      final jsonClaimed = {
        'id': 'rew_002',
        'member_id': 'mem_123',
        'reward_value': 250,
        'claim_status': 'claimed',
        'claimed_at': '2026-10-26T12:00:00Z',
        'created_at': '2026-10-20T10:00:00Z',
      };

      final rewardClaimed = ReferralReward.fromJson(jsonClaimed);
      expect(rewardClaimed.rewardValue, equals(250.0));
      expect(rewardClaimed.isAwaitingApproval, isFalse);
      expect(rewardClaimed.isClaimed, isTrue);
    });
  });

  group('ProfileReferralCard Widget & Accessibility Tests', () {
    final testMember = Member(
      id: 'mem_audit_001',
      memberCode: 'INC-26-0015',
      branchId: 'branch_indiranagar',
      profile: Profile(
        id: 'prof_001',
        fullName: 'Vikram Malhotra',
        email: 'vikram@example.com',
        phone: '+919876543210',
      ),
    );

    testWidgets('ProfileReferralCard renders with accessible 44px touch target and semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileReferralCard(
              member: testMember,
              rewardsEnabled: true,
            ),
          ),
        ),
      );

      // Verify card elements
      expect(find.text('INVITE & TRACK'), findsOneWidget);
      expect(find.text('Refer Friends & Earn'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);

      // Verify Semantics label
      expect(
        find.bySemanticsLabel('Open Refer and Earn privileges'),
        findsOneWidget,
      );

      // Verify touch target is at least 44x44
      final inviteBtnFinder = find.widgetWithText(ElevatedButton, 'Invite');
      final renderBox = tester.renderObject<RenderBox>(inviteBtnFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
    });

    testWidgets('ProfileReferralCard reflects rewards paused state subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileReferralCard(
              member: testMember,
              rewardsEnabled: false,
            ),
          ),
        ),
      );

      expect(find.text('Priority guest passes • Verified access'), findsOneWidget);
    });
  });
}
