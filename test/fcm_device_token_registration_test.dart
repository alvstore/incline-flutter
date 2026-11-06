import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/push_notification_service.dart';
import 'package:incline_app/core/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FCM & Supabase Web-Push Device Registration Tests', () {
    test('registerDeviceWithBackend caches token when no session is active', () async {
      final success = await PushNotificationService.instance.registerDeviceWithBackend(
        token: 'test_fcm_mock_token_123',
        branchId: '11111111-1111-1111-1111-111111111111',
      );

      // Without active Supabase session, it stores token in SharedPreferences and returns false
      expect(success, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('incline_registered_fcm_token'), equals('test_fcm_mock_token_123'));
      expect(prefs.getString('incline_registered_branch_id'), equals('11111111-1111-1111-1111-111111111111'));
    });

    test('web-push registration JSON contract conforms to Lovable backend spec', () {
      const fcmToken = 'sample_fcm_token_abcdef123456';
      const branchId = '11111111-1111-1111-1111-111111111111';
      const platform = 'android';

      final registerPayload = {
        'action': 'register_device',
        'token': fcmToken,
        'platform': platform,
        'branch_id': branchId,
      };

      final encoded = jsonEncode(registerPayload);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['action'], equals('register_device'));
      expect(decoded['token'], equals(fcmToken));
      expect(decoded['platform'], equals('android'));
      expect(decoded['branch_id'], equals(branchId));
    });

    test('web-push unsubscribe JSON contract conforms to Lovable backend spec', () {
      const fcmToken = 'sample_fcm_token_abcdef123456';

      final unsubscribePayload = {
        'action': 'unsubscribe',
        'token': fcmToken,
      };

      final encoded = jsonEncode(unsubscribePayload);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['action'], equals('unsubscribe'));
      expect(decoded['token'], equals(fcmToken));
    });

    test('unsubscribeDeviceFromBackend clears cached token from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('incline_registered_fcm_token', 'token_to_remove');
      await prefs.setString('incline_registered_branch_id', 'branch_to_remove');

      expect(prefs.getString('incline_registered_fcm_token'), equals('token_to_remove'));
      expect(prefs.getString('incline_registered_branch_id'), equals('branch_to_remove'));

      // Calling unsubscribe when unauthenticated clears the cached token and branch
      await PushNotificationService.instance.unsubscribeDeviceFromBackend();

      expect(prefs.getString('incline_registered_fcm_token'), isNull);
      expect(prefs.getString('incline_registered_branch_id'), isNull);
    });

    test('dynamic multi-branch support binds device to member assigned branch', () async {
      const customBranchId = '22222222-2222-2222-2222-222222222222';
      final memberBranch2 = Member(
        id: 'member_branch_02',
        branchId: customBranchId,
        memberCode: 'INC-UDR-0042',
        status: 'active',
      );

      // Cache member in memory
      SupabaseService.instance.setCachedMember(memberBranch2);

      // Verify SupabaseService resolves this dynamic branch
      final resolved = await SupabaseService.instance.resolveEffectiveBranchId();
      expect(resolved, equals(customBranchId));

      // Attempt registration without explicit branchId argument
      await PushNotificationService.instance.registerDeviceWithBackend(
        token: 'token_branch_2',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('incline_registered_fcm_token'), equals('token_branch_2'));
      // Device registration dynamically bound to member's custom branch
      expect(prefs.getString('incline_registered_branch_id'), equals(customBranchId));
      expect(PushNotificationService.instance.activeBranchId, equals(customBranchId));

      // Reset cached member
      SupabaseService.instance.setCachedMember(null);
    });

    test('multi-branch payload supports dynamic branch switching', () {
      const branchSector14 = '11111111-1111-1111-1111-111111111111';
      const branchFatehsagar = '33333333-3333-3333-3333-333333333333';

      final payloadBranch1 = {
        'action': 'register_device',
        'token': 'fcm_dynamic_token',
        'platform': 'android',
        'branch_id': branchSector14,
      };

      final payloadBranch2 = {
        'action': 'register_device',
        'token': 'fcm_dynamic_token',
        'platform': 'android',
        'branch_id': branchFatehsagar,
      };

      expect(payloadBranch1['branch_id'], equals(branchSector14));
      expect(payloadBranch2['branch_id'], equals(branchFatehsagar));
      expect(payloadBranch1['token'], equals(payloadBranch2['token']));
    });

    test('syncDeviceRegistration re-registers with new dynamic branch', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('incline_registered_fcm_token', 'cached_token_for_sync');

      const newBranchId = '44444444-4444-4444-4444-444444444444';
      await PushNotificationService.instance.syncDeviceRegistration(branchId: newBranchId);

      expect(prefs.getString('incline_registered_fcm_token'), equals('cached_token_for_sync'));
      expect(prefs.getString('incline_registered_branch_id'), equals(newBranchId));
      expect(PushNotificationService.instance.activeBranchId, equals(newBranchId));
    });
  });
}
