import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'native_health_bridge.dart';

/// Reads real native health samples and keeps member-defined goals locally.
/// Missing samples stay unavailable; the app never manufactures health values.
class WatchSyncService extends ChangeNotifier with WidgetsBindingObserver {
  static final WatchSyncService instance = WatchSyncService._internal();

  WatchSyncService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _detectEcosystem();
    _ready = init();
  }

  Timer? _foregroundRefreshTimer;

  late final Future<void> _ready;

  String _watchBrand = 'Health data';
  String _ecosystemSubtitle = 'No health provider available';
  IconData _watchIcon = Icons.health_and_safety_outlined;

  String get watchBrand => _watchBrand;
  String get ecosystemSubtitle => _ecosystemSubtitle;
  IconData get watchIcon => _watchIcon;
  String get heartRateVariabilityMetricName {
    if (kIsWeb) return 'HRV';
    if (Platform.isAndroid) return 'RMSSD';
    if (Platform.isIOS) return 'SDNN';
    return 'HRV';
  }

  WatchSyncData _data = const WatchSyncData();
  WatchSyncData get data => _data;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static const String _prefGoalSteps = 'health_goal_steps';
  static const String _prefGoalCalories = 'health_goal_calories';
  static const String _prefGoalSleep = 'health_goal_sleep';
  static const String _prefGoalWorkout = 'health_goal_workout_min';

  static const String _prefTodaySteps = 'health_today_steps';
  static const String _prefTodayCalories = 'health_today_calories';
  static const String _prefTodaySleep = 'health_today_sleep';
  static const String _legacySleepScorePreference = 'health_today_sleep_score';
  static const String _prefTodayWorkout = 'health_today_workout';
  static const String _prefHeartRate = 'health_today_heart_rate';
  static const String _prefHeartRateAt = 'health_today_heart_rate_at';
  static const String _prefHrv = 'health_today_hrv_ms';
  static const String _prefHrvAt = 'health_today_hrv_at';
  static const String _prefLastSyncIso = 'health_last_sync_iso';
  static const String _prefDeviceData = 'health_native_data_available';
  static const String _prefManualSleep = 'health_sleep_is_manual';
  static const String _prefTelemetryDate = 'health_telemetry_date';
  static const String _prefDataVersion = 'health_telemetry_data_version';
  static const String _currentDataVersion = 'native_health_2';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = _dateKey(now);
      final storedDate = prefs.getString(_prefTelemetryDate);
      final isSameDay = storedDate == today;

      // Old builds stored synthetic steps/calories from exercise-set taps. Clear
      // those unverified values once and retain only manually entered sleep.
      if (prefs.getString(_prefDataVersion) != _currentDataVersion) {
        await prefs.remove(_prefTodaySteps);
        await prefs.remove(_prefTodayCalories);
        await prefs.remove(_prefTodayWorkout);
        await prefs.remove(_legacySleepScorePreference);
        await prefs.remove(_prefHeartRate);
        await prefs.remove(_prefHeartRateAt);
        await prefs.remove(_prefHrv);
        await prefs.remove(_prefHrvAt);
        await prefs.remove(_prefLastSyncIso);
        await prefs.remove(_prefDeviceData);
        await prefs.setString(_prefDataVersion, _currentDataVersion);
      }
      // Legacy readiness scores were calculated from sleep duration, not a
      // measured recovery source. Never present those as a clinical score.
      await prefs.remove(_legacySleepScorePreference);

      if (!isSameDay) {
        await prefs.setString(_prefTelemetryDate, today);
        await prefs.remove(_prefTodaySteps);
        await prefs.remove(_prefTodayCalories);
        await prefs.remove(_prefTodaySleep);
        await prefs.remove(_prefTodayWorkout);
        await prefs.remove(_prefHeartRate);
        await prefs.remove(_prefHeartRateAt);
        await prefs.remove(_prefHrv);
        await prefs.remove(_prefHrvAt);
        await prefs.remove(_prefLastSyncIso);
        await prefs.remove(_prefDeviceData);
        await prefs.remove(_prefManualSleep);
      }

      final goalSteps = prefs.getInt(_prefGoalSteps) ?? 10000;
      final goalCalories = prefs.getInt(_prefGoalCalories) ?? 750;
      final goalSleep = prefs.getDouble(_prefGoalSleep) ?? 8.0;
      final goalWorkout = prefs.getInt(_prefGoalWorkout) ?? 60;

      final steps = isSameDay ? (prefs.getInt(_prefTodaySteps) ?? -1) : -1;
      final calories =
          isSameDay ? (prefs.getInt(_prefTodayCalories) ?? -1) : -1;
      final sleepHours =
          isSameDay ? (prefs.getDouble(_prefTodaySleep) ?? 0.0) : 0.0;
      final workout =
          isSameDay ? (prefs.getInt(_prefTodayWorkout) ?? -1) : -1;
      var heartRate = isSameDay ? (prefs.getInt(_prefHeartRate) ?? -1) : -1;
      DateTime? heartRateAt = DateTime.tryParse(
        prefs.getString(_prefHeartRateAt) ?? '',
      );
      if (heartRateAt == null ||
          now.difference(heartRateAt) > const Duration(hours: 24) ||
          heartRate <= 0) {
        heartRate = -1;
        heartRateAt = null;
      }

      var hrv = isSameDay ? (prefs.getDouble(_prefHrv) ?? -1.0) : -1.0;
      DateTime? hrvAt = DateTime.tryParse(prefs.getString(_prefHrvAt) ?? '');
      if (hrvAt == null || now.difference(hrvAt) > const Duration(hours: 24) || hrv <= 0) {
        hrv = -1;
        hrvAt = null;
      }
      final lastSync = isSameDay
          ? DateTime.tryParse(prefs.getString(_prefLastSyncIso) ?? '')
          : null;
      final deviceData = isSameDay && (prefs.getBool(_prefDeviceData) ?? false);
      final manualSleep = isSameDay &&
          (prefs.getBool(_prefManualSleep) ?? (sleepHours > 0));
      _data = WatchSyncData(
        steps: steps,
        goalSteps: goalSteps,
        activeCalories: calories,
        goalCalories: goalCalories,
        heartRate: heartRate,
        heartRateRecordedAt: heartRateAt,
        heartRateVariabilityMs: hrv,
        heartRateVariabilityRecordedAt: hrvAt,
        sleepHours: sleepHours,
        goalSleepHours: goalSleep,
        isManualSleep: manualSleep,
        workoutMinutes: workout,
        goalWorkoutMinutes: goalWorkout,
        lastSyncTime: lastSync,
        isConnected: deviceData,
        hasSyncedToday: deviceData,
      );

      _isInitialized = true;
      if (_data.isConnected &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _startForegroundRefresh();
      }
      notifyListeners();
    } catch (error) {
      debugPrint('[WatchSyncService] Init error: $error');
    }
  }

  void _detectEcosystem() {
    if (kIsWeb) {
      _watchBrand = 'Health data';
      _ecosystemSubtitle = 'Native health sync is unavailable on web';
      _watchIcon = Icons.health_and_safety_outlined;
    } else if (Platform.isIOS) {
      _watchBrand = 'Apple Health';
      _ecosystemSubtitle = 'Apple Health · latest saved samples';
      _watchIcon = Icons.favorite_rounded;
    } else if (Platform.isAndroid) {
      _watchBrand = 'Health Connect';
      _ecosystemSubtitle = 'Connect Health Connect to read saved health records';
      _watchIcon = Icons.watch_rounded;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_data.isConnected) {
        unawaited(syncNow());
        _startForegroundRefresh();
      }
    } else {
      _foregroundRefreshTimer?.cancel();
      _foregroundRefreshTimer = null;
    }
  }

  void _startForegroundRefresh() {
    _foregroundRefreshTimer?.cancel();
    _foregroundRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(syncNow());
      }
    });
  }

  Future<void> updateGoals({
    int? steps,
    int? calories,
    double? sleepHours,
    int? workoutMinutes,
  }) async {
    await _ready;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newGoalSteps = steps ?? _data.goalSteps;
      final newGoalCalories = calories ?? _data.goalCalories;
      final newGoalSleep = sleepHours ?? _data.goalSleepHours;
      final newGoalWorkout = workoutMinutes ?? _data.goalWorkoutMinutes;

      await prefs.setInt(_prefGoalSteps, newGoalSteps);
      await prefs.setInt(_prefGoalCalories, newGoalCalories);
      await prefs.setDouble(_prefGoalSleep, newGoalSleep);
      await prefs.setInt(_prefGoalWorkout, newGoalWorkout);

      _data = _data.copyWith(
        goalSteps: newGoalSteps,
        goalCalories: newGoalCalories,
        goalSleepHours: newGoalSleep,
        goalWorkoutMinutes: newGoalWorkout,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('[WatchSyncService] updateGoals error: $error');
    }
  }

  /// Records member-entered sleep when the watch was off-wrist.
  Future<void> logSleep({
    required double hours,
  }) async {
    await _ready;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setDouble(_prefTodaySleep, hours);
      await prefs.setBool(_prefManualSleep, true);
      await prefs.setString(_prefTelemetryDate, _dateKey(now));

      _data = _data.copyWith(
        sleepHours: hours,
        isManualSleep: true,
        hasSyncedToday: _data.isConnected,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('[WatchSyncService] logSleep error: $error');
    }
  }

  /// Reads the native provider. No values are inferred from exercise taps.
  Future<void> syncNow() async {
    await _ready;
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final provider = NativeHealthBridge.instance.activeProvider;
      if (provider == null || !await provider.isAvailable()) {
        _ecosystemSubtitle = provider is AndroidHealthConnectProvider
            ? 'Install or update Health Connect to connect health data'
            : 'Apple Health is unavailable on this device';
        _foregroundRefreshTimer?.cancel();
        _foregroundRefreshTimer = null;
        _data = _data.copyWith(
          steps: -1,
          activeCalories: -1,
          workoutMinutes: -1,
          heartRate: -1,
          clearHeartRateRecordedAt: true,
          heartRateVariabilityMs: -1,
          clearHeartRateVariabilityRecordedAt: true,
          isConnected: false,
          hasSyncedToday: false,
        );
        return;
      }

      _ecosystemSubtitle = provider is AndroidHealthConnectProvider
          ? 'Health Connect · refreshes every 5 minutes while Incline is open'
          : 'Apple Health · refreshes every 5 minutes while Incline is open';

      final values = await provider.readDailyMetrics();
      final now = DateTime.now();

      final hasStepData = values['hasStepsData'] == true;
      final hasCaloriesData = values['hasCaloriesData'] == true;
      final hasWorkoutData = values['hasWorkoutData'] == true;
      final hasHeartRateData = values['hasHeartRateData'] == true;
      final hasHrvData = values['hasHrvData'] == true;
      final hasSleepData = values['hasSleepData'] == true;

      final steps = hasStepData ? _toInt(values['steps']) : -1;
      final calories =
          hasCaloriesData ? _toInt(values['activeCalories']) : -1;
      final workout =
          hasWorkoutData ? _toInt(values['workoutMinutes']) : -1;
      final heartRate =
          hasHeartRateData ? _toInt(values['heartRate']) : -1;
      final heartRateAt = hasHeartRateData
          ? DateTime.tryParse(values['heartRateRecordedAt']?.toString() ?? '')
          : null;
      final hrv = hasHrvData ? _toDouble(values['heartRateVariabilityMs']) : -1.0;
      final hrvAt = hasHrvData
          ? DateTime.tryParse(values['heartRateVariabilityRecordedAt']?.toString() ?? '')
          : null;
      final sleepValue = hasSleepData ? _toDouble(values['sleepHours']) : null;
      final keepManualSleep =
          !hasSleepData && _data.isManualSleep && _data.sleepHours > 0;
      final sleep = sleepValue ?? (keepManualSleep ? _data.sleepHours : 0.0);
      final hasDeviceData = values['hasData'] == true ||
          hasStepData ||
          hasCaloriesData ||
          hasWorkoutData ||
          hasHeartRateData ||
          hasHrvData ||
          hasSleepData;

      _data = _data.copyWith(
        steps: steps,
        activeCalories: calories,
        workoutMinutes: workout,
        heartRate: heartRate,
        heartRateRecordedAt: heartRateAt,
        clearHeartRateRecordedAt: !hasHeartRateData,
        heartRateVariabilityMs: hrv,
        heartRateVariabilityRecordedAt: hrvAt,
        clearHeartRateVariabilityRecordedAt: !hasHrvData,
        sleepHours: sleep,
        isManualSleep: keepManualSleep,
        isConnected: hasDeviceData,
        hasSyncedToday: hasDeviceData,
        lastSyncTime: now,
      );

      if (_data.isConnected &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _startForegroundRefresh();
      } else if (!_data.isConnected) {
        _foregroundRefreshTimer?.cancel();
        _foregroundRefreshTimer = null;
      }

      await _persistCurrentMetrics(now);
    } catch (error) {
      debugPrint('[WatchSyncService] syncNow error: $error');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _persistCurrentMetrics(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTelemetryDate, _dateKey(now));
    await prefs.setInt(_prefTodaySteps, _data.steps);
    await prefs.setInt(_prefTodayCalories, _data.activeCalories);
    await prefs.setDouble(_prefTodaySleep, _data.sleepHours);
    await prefs.setInt(_prefTodayWorkout, _data.workoutMinutes);
    await prefs.setBool(_prefDeviceData, _data.isConnected);
    await prefs.setBool(_prefManualSleep, _data.isManualSleep);
    await prefs.setString(_prefLastSyncIso, now.toIso8601String());

    if (_data.heartRate >= 0 && _data.heartRateRecordedAt != null) {
      await prefs.setInt(_prefHeartRate, _data.heartRate);
      await prefs.setString(
        _prefHeartRateAt,
        _data.heartRateRecordedAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_prefHeartRate);
      await prefs.remove(_prefHeartRateAt);
    }
    if (_data.heartRateVariabilityMs >= 0 && _data.heartRateVariabilityRecordedAt != null) {
      await prefs.setDouble(_prefHrv, _data.heartRateVariabilityMs);
      await prefs.setString(_prefHrvAt, _data.heartRateVariabilityRecordedAt!.toIso8601String());
    } else {
      await prefs.remove(_prefHrv);
      await prefs.remove(_prefHrvAt);
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return -1;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  String _dateKey(DateTime date) =>
      date.year.toString() +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundRefreshTimer?.cancel();
    super.dispose();
  }
}
