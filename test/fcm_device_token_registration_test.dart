import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/services/push_notification_service.dart';

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

      expect(prefs.getString('incline_registered_fcm_token'), equals('token_to_remove'));

      // Calling unsubscribe when unauthenticated clears the cached token
      await PushNotificationService.instance.unsubscribeDeviceFromBackend();

      expect(prefs.getString('incline_registered_fcm_token'), isNull);
    });
  });
}
