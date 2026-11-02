import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Platform health data access. The app reads existing samples only.
abstract class NativeHealthProvider {
  String get name;
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<Map<String, dynamic>> readDailyMetrics();
}

/// Read-only Apple HealthKit provider.
class AppleHealthKitProvider implements NativeHealthProvider {
  static const MethodChannel _channel =
      MethodChannel('com.incline/native_health');

  @override
  String get name => 'Apple Health';

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isHealthDataAvailable') ?? false;
    } catch (error) {
      debugPrint('[NativeHealthBridge] Apple Health availability error: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (error) {
      debugPrint('[NativeHealthBridge] Apple Health permission error: $error');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> readDailyMetrics() async {
    if (!await isAvailable()) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('readDailyMetrics') ??
          const {};
    } catch (error) {
      debugPrint('[NativeHealthBridge] Apple Health read error: $error');
      return const {};
    }
  }
}

/// Read-only Android Health Connect provider.
class AndroidHealthConnectProvider implements NativeHealthProvider {
  static const MethodChannel _channel =
      MethodChannel('com.incline/native_health');

  @override
  String get name => 'Google Health Connect';

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isHealthDataAvailable') ?? false;
    } catch (error) {
      debugPrint('[NativeHealthBridge] Health Connect availability error: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (error) {
      debugPrint('[NativeHealthBridge] Health Connect permission error: $error');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> readDailyMetrics() async {
    if (!await isAvailable()) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('readDailyMetrics') ??
          const {};
    } catch (error) {
      debugPrint('[NativeHealthBridge] Health Connect read error: $error');
      return const {};
    }
  }
}

/// Native Health Bridge Manager
class NativeHealthBridge {
  static final NativeHealthBridge instance = NativeHealthBridge._internal();
  NativeHealthBridge._internal() {
    if (!kIsWeb && Platform.isIOS) {
      _activeProvider = AppleHealthKitProvider();
    } else if (!kIsWeb && Platform.isAndroid) {
      _activeProvider = AndroidHealthConnectProvider();
    }
  }

  NativeHealthProvider? _activeProvider;
  NativeHealthProvider? get activeProvider => _activeProvider;

  /// Shows an M3 Health Permissions Disclosure modal explaining telemetry usage
  /// Programmatically request health telemetry permissions
  Future<bool> requestPermissions() async {
    final provider = _activeProvider;
    if (provider == null || !await provider.isAvailable()) return false;
    return provider.requestPermissions();
  }

  Future<bool> showPermissionsRationaleDialog(BuildContext context) async {
    final providerName = _activeProvider?.name ?? (kIsWeb ? 'Health Sensors' : 'Fitness Platform');
    final isIOS = !kIsWeb && Platform.isIOS;

    bool granted = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isIOS ? Icons.favorite_rounded : Icons.health_and_safety_rounded,
              color: context.brandAccent,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Connect $providerName',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIOS
                  ? 'Read the latest samples saved in Apple Health. Heart rate updates when Apple Health receives new samples from your devices.'
                  : 'Read the latest records saved in Health Connect. New values appear when your wearable or health apps write records; Incline refreshes while it is open.',
              style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  _permissionRow(Icons.directions_walk_rounded, 'Daily Steps', 'Shows recorded steps for today', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.local_fire_department_rounded, 'Active Calories', 'Monitors workout energy output', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.favorite_rounded, 'Heart Rate', 'Shows the latest saved heart-rate sample', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.bedtime_rounded, 'Sleep & HRV', 'Shows recorded sleep and HRV when available', context),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              granted = await requestPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Allow & Connect', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    return granted;
  }

  static Widget _permissionRow(IconData icon, String title, String desc, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.brandAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text(desc, style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
