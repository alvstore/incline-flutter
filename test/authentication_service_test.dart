import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:incline_app/core/config/env_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Test email vs phone in signInWithPassword', () async {
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: EnvConfig.supabaseAnonKey,
    );

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: 'mohitgurjarawanaa@gmail.com',
        password: 'Incline@2026',
      );
      // ignore: avoid_print
      print('Email login success: ${res.user?.id}');
    } catch (e) {
      // ignore: avoid_print
      print('Email login failed: $e');
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        phone: '918209887831',
        password: 'Incline@2026',
      );
      // ignore: avoid_print
      print('Phone 918209887831 login success: ${res.user?.id}');
    } catch (e) {
      // ignore: avoid_print
      print('Phone 918209887831 login failed: $e');
    }
  });
}
