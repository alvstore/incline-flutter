import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'watch_sync_service.dart';

/// Abstract Extension Point for OS Health Platforms
abstract class NativeHealthProvider {
  String get name;
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<Map<String, dynamic>> readDailyMetrics();
  Future<bool> writeCompletedWorkout({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int caloriesBurned,
  });
}

/// iOS Apple HealthKit Provider Implementation
class AppleHealthKitProvider implements NativeHealthProvider {
  @override
  String get name => 'Apple HealthKit';

  @override
  Future<bool> isAvailable() async {
    return !kIsWeb && Platform.isIOS;
  }

  @override
  Future<bool> requestPermissions() async {
    // In production, invokes HealthKit native authorization for HKQuantityTypeIdentifierStepCount,
    // ActiveEnergyBurned, HeartRate, and WorkoutType.
    debugPrint('[INCLINE] AppleHealthKitProvider: Requesting HKAuthorizationStatus');
    return true;
  }

  @override
  Future<Map<String, dynamic>> readDailyMetrics() async {
    final telemetry = WatchSyncService.instance.data;
    return {
      'steps': telemetry.steps,
      'activeCalories': telemetry.activeCalories,
      'heartRate': telemetry.heartRate,
      'sleepHours': telemetry.sleepHours,
      'workoutMinutes': telemetry.workoutMinutes,
    };
  }

  @override
  Future<bool> writeCompletedWorkout({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int caloriesBurned,
  }) async {
    debugPrint('[INCLINE] AppleHealthKitProvider: Recording HKWorkout ($title, $caloriesBurned kcal)');
    return true;
  }
}

/// Android Google Health Connect / Samsung Health Provider Implementation
class AndroidHealthConnectProvider implements NativeHealthProvider {
  @override
  String get name => 'Google Health Connect';

  @override
  Future<bool> isAvailable() async {
    return !kIsWeb && Platform.isAndroid;
  }

  @override
  Future<bool> requestPermissions() async {
    // In production, launches Health Connect permission contract (androidx.health.connect.client)
    debugPrint('[INCLINE] AndroidHealthConnectProvider: Requesting Health Connect permissions');
    return true;
  }

  @override
  Future<Map<String, dynamic>> readDailyMetrics() async {
    final telemetry = WatchSyncService.instance.data;
    return {
      'steps': telemetry.steps,
      'activeCalories': telemetry.activeCalories,
      'heartRate': telemetry.heartRate,
      'sleepHours': telemetry.sleepHours,
      'workoutMinutes': telemetry.workoutMinutes,
    };
  }

  @override
  Future<bool> writeCompletedWorkout({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int caloriesBurned,
  }) async {
    debugPrint('[INCLINE] AndroidHealthConnectProvider: Writing ExerciseSessionRecord ($title, $caloriesBurned kcal)');
    return true;
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
    final granted = await _activeProvider?.requestPermissions() ?? true;
    if (granted) {
      await WatchSyncService.instance.syncNow();
    }
    return granted;
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
              'Synchronize authentic biometric telemetry to power your personalized training and contrast recovery routines.',
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
                  _permissionRow(Icons.directions_walk_rounded, 'Daily Steps', 'Calibrates daily NEAT activity', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.local_fire_department_rounded, 'Active Calories', 'Monitors workout energy output', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.favorite_rounded, 'Heart Rate', 'Tracks contrast suite HRV & recovery', context),
                  const SizedBox(height: 8),
                  _permissionRow(Icons.bedtime_rounded, 'Sleep Telemetry', 'Adapts morning training intensity', context),
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
              granted = await _activeProvider?.requestPermissions() ?? true;
              if (granted) {
                await WatchSyncService.instance.syncNow();
              }
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
