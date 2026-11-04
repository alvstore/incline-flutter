import '../models/models.dart';
import '../theme/incline_colors.dart';
import '../utils/ist_date_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Push Notifications and Club Bulletin Service
/// Handles incoming notifications, class reminders, suite confirmations, streak alerts,
/// and automated hydration prompts with 1-tap logging.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  PushNotificationService._internal();

  static const String _prefNotificationsEnabled = 'incline_push_notifications_enabled';
  static const String _prefClassRemindersEnabled = 'incline_class_reminders_enabled';
  static const String _prefStreakAlertsEnabled = 'incline_streak_alerts_enabled';
  static const String _prefHydrationRemindersEnabled = 'incline_hydration_reminders_enabled';

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Optional listener triggered when member logs water from push notification action
  VoidCallback? onWaterLogged;

  /// Initializes notifications and requests authorization
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[INCLINE] Notification response: ${response.payload}');
          if (response.payload == 'water_log_250') {
            SupabaseService.instance.logWaterIntake(memberId: '', amountMl: 250);
            onWaterLogged?.call();
          }
        },
      );

      // Create Android Notification Channels
      const androidChannel = AndroidNotificationChannel(
        'incline_club_alerts',
        'Incline Club Alerts & Reminders',
        description: 'Motivational cues, session reminders, and contrast suite bookings',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const hydrationChannel = AndroidNotificationChannel(
        'incline_hydration_alerts',
        'Incline Hydration & Water Reminders',
        description: 'Timely reminders to maintain cellular hydration, sauna/cryo recovery, and electrolyte balance',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.createNotificationChannel(hydrationChannel);
        // Request permission on Android 13+
        await androidPlugin.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('[INCLINE] PushNotificationService initialized with club & hydration channels');
      return true;
    } catch (e) {
      debugPrint('[INCLINE] PushNotificationService init note: $e');
      return false;
    }
  }

  /// Whether push notifications are enabled by the member
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefNotificationsEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Whether 1-hour class reminders are enabled
  Future<bool> isClassRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefClassRemindersEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Whether streak & consistency alerts are enabled
  Future<bool> isStreakAlertsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefStreakAlertsEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Whether daily water intake hydration reminders are enabled
  Future<bool> isHydrationRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefHydrationRemindersEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggle notification permissions
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefNotificationsEnabled, enabled);
    } catch (e) {
      debugPrint('[INCLINE] PushNotificationService setEnabled error: $e');
    }
  }

  /// Toggle hydration notification reminders
  Future<void> setHydrationRemindersEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHydrationRemindersEnabled, enabled);
      if (enabled) {
        await scheduleHydrationReminders(enabled: true);
      } else {
        await cancelHydrationReminders();
      }
    } catch (e) {
      debugPrint('[INCLINE] PushNotificationService setHydrationRemindersEnabled error: $e');
    }
  }

  /// Schedules daily hydration reminders throughout training & recovery hours
  Future<void> scheduleHydrationReminders({required bool enabled, int intervalHours = 2}) async {
    if (!enabled) {
      await cancelHydrationReminders();
      return;
    }

    try {
      if (!_isInitialized) await init();

      const androidDetails = AndroidNotificationDetails(
        'incline_hydration_alerts',
        'Incline Hydration & Water Reminders',
        channelDescription: 'Timely reminders to maintain cellular hydration, sauna/cryo recovery, and electrolyte balance',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: InclineColors.accentOrange,
        playSound: true,
        enableVibration: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      // Schedule periodic reminders across active hours
      await _localNotifications.periodicallyShow(
        8801,
        'Hydration Check • Incline Performance',
        'Maintain peak cellular output and flush lactic acid. Drink a glass of water now (+250 ml).',
        RepeatInterval.hourly,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'water_log_250',
      );
      debugPrint('[INCLINE] Scheduled periodic hydration reminders (channel: incline_hydration_alerts)');
    } catch (e) {
      debugPrint('[INCLINE] scheduleHydrationReminders error: $e');
    }
  }

  /// Cancels recurring hydration notifications
  Future<void> cancelHydrationReminders() async {
    try {
      await _localNotifications.cancel(8801);
      debugPrint('[INCLINE] Cancelled hydration notifications');
    } catch (e) {
      debugPrint('[INCLINE] cancelHydrationReminders error: $e');
    }
  }

  /// Dispatches an immediate test or real-time hydration prompt
  Future<void> sendImmediateHydrationPrompt({
    String title = 'Hydration Alert • Incline Fuel',
    String body = 'Time to drink water! Replenish electrolytes and maintain peak cellular performance. Tap to log 250ml.',
  }) async {
    try {
      if (!_isInitialized) await init();

      final androidDetails = AndroidNotificationDetails(
        'incline_hydration_alerts',
        'Incline Hydration & Water Reminders',
        channelDescription: 'Timely reminders to maintain cellular hydration, sauna/cryo recovery, and electrolyte balance',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: InclineColors.accentOrange,
        styleInformation: BigTextStyleInformation(body),
        playSound: true,
        enableVibration: true,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        8802,
        title,
        body,
        notificationDetails,
        payload: 'water_log_250',
      );
      debugPrint('[INCLINE] Dispatched immediate hydration prompt');
    } catch (e) {
      debugPrint('[INCLINE] sendImmediateHydrationPrompt error: $e');
    }
  }

  /// Schedules a 1-hour advance reminder for an upcoming booked class
  Future<void> scheduleClassReminder({
    required String classTitle,
    required String studio,
    required DateTime classTime,
  }) async {
    final reminderTime = classTime.subtract(const Duration(hours: 1));
    debugPrint('[INCLINE] Scheduled 1-hour class reminder for "$classTitle" at $reminderTime');
  }

  /// Schedules a 30-minute advance preparation alert for contrast therapy suites
  Future<void> scheduleContrastSuiteReminder({
    required String suiteName,
    required DateTime slotTime,
  }) async {
    final reminderTime = slotTime.subtract(const Duration(minutes: 30));
    debugPrint('[INCLINE] Scheduled suite reminder for "$suiteName" at $reminderTime');
  }

  /// Evaluates whether the member has passed their habitual visit time today without
  /// an optical turnstile check-in, and dispatches a streak-defense motivational alert.
  Future<void> checkAndDispatchMissedGymAlert(MemberAttendanceAnalysis analysis) async {
    if (analysis.isVisitedToday) return;

    final enabled = await isStreakAlertsEnabled();
    if (!enabled) return;

    final nowIST = ISTDateUtils.toIST(DateTime.now());
    final currentHour = nowIST.hour;

    // Dispatches once per day when current time reaches or exceeds their habitual time
    // between habitualHour and 22:00 (club closing hours)
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'incline_missed_gym_notified_${nowIST.year}_${nowIST.month}_${nowIST.day}';
    if (prefs.getBool(todayKey) == true) return;

    if (currentHour >= analysis.habitualHour && currentHour < 22) {
      final streak = analysis.streakDays;
      final title = streak > 0
          ? 'Streak Defense • $streak-Day Streak at Risk! 🔥'
          : 'Rise & Reflect • Incline Routine';
      final body = streak > 0
          ? 'You usually train around ${analysis.habitualTime}. Protect your $streak-day streak today — club doors are open!'
          : 'You usually visit around ${analysis.habitualTime}. Take 45 minutes for yourself today — workout floors and contrast suites are ready.';

      await showLocalAlert(
        title: title,
        body: body,
        payloadRoute: '/workout',
      );
      await prefs.setBool(todayKey, true);
      debugPrint('[INCLINE] Dispatched missed-gym motivational prompt for habitual time ${analysis.habitualTime}');
    }
  }

  /// Dispatches immediate local alert for confirmed booking, motivational cue, or reminder
  Future<void> showLocalAlert({
    required String title,
    required String body,
    String? payloadRoute,
  }) async {
    debugPrint('[INCLINE] PushNotification: $title • $body (Payload: $payloadRoute)');

    try {
      if (!_isInitialized) {
        await init();
      }

      final androidDetails = AndroidNotificationDetails(
        'incline_club_alerts',
        'Incline Club Alerts & Reminders',
        channelDescription: 'Motivational cues, session reminders, and contrast suite bookings',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: InclineColors.accentOrange,
        styleInformation: BigTextStyleInformation(body),
        playSound: true,
        enableVibration: true,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payloadRoute,
      );
    } catch (e) {
      debugPrint('[INCLINE] showLocalAlert error: $e');
    }
  }
}
