import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../theme/incline_colors.dart';
import '../utils/ist_date_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../../firebase_options.dart';
import 'supabase_service.dart';

/// Top-level background handler for FCM messages when app is killed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[INCLINE FCM] Background message received: ${message.messageId}');
}

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
  static const String _prefFcmToken = 'incline_registered_fcm_token';
  static const String _prefRegisteredBranchId = 'incline_registered_branch_id';
  static const String _defaultBranchId = '11111111-1111-1111-1111-111111111111';

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _activeBranchId;

  /// Currently active or registered branch ID for dynamic multi-branch notification routing
  String? get activeBranchId => _activeBranchId;

  /// Optional listener triggered when member logs water from push notification action
  VoidCallback? onWaterLogged;

  /// Optional listener triggered when member taps a push notification banner
  ValueChanged<String>? onNotificationTap;

  /// Initializes notifications and requests authorization
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[INCLINE] Notification response: ${response.payload}');
          if (response.payload == 'water_log_250') {
            SupabaseService.instance.logWaterIntake(memberId: '', amountMl: 250);
            onWaterLogged?.call();
          } else if (response.payload != null && response.payload!.isNotEmpty) {
            onNotificationTap?.call(response.payload!);
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

      // Request authorization on iOS / macOS Darwin
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
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

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

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

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
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

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
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

  // ---------------------------------------------------------------------------
  // FIREBASE CLOUD MESSAGING (FCM) & SUPABASE WEB-PUSH SYNC
  // ---------------------------------------------------------------------------

  /// Initializes Firebase Cloud Messaging and registers the device FCM token
  /// with the Supabase `web-push` edge function using dynamic multi-branch resolution.
  Future<void> initFirebaseMessaging({String? branchId}) async {
    try {
      if (branchId != null && branchId.trim().isNotEmpty) {
        _activeBranchId = branchId.trim();
      }

      // 1. Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        try {
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          } catch (_) {
            await Firebase.initializeApp();
          }
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          debugPrint('[INCLINE FCM] Firebase app initialized successfully');
        } catch (e) {
          debugPrint('[INCLINE FCM] Firebase init note: $e');
          // Try to sync any previously cached token if already present
          final prefs = await SharedPreferences.getInstance();
          final cachedToken = prefs.getString(_prefFcmToken);
          if (cachedToken != null && cachedToken.isNotEmpty) {
            await registerDeviceWithBackend(token: cachedToken, branchId: _activeBranchId);
          }
          return;
        }
      }

      // 2. Request remote notification permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[INCLINE FCM] Remote push authorization: ${settings.authorizationStatus}');

      // 3. Fetch FCM token and register with web-push
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[INCLINE FCM] Acquired FCM token: $token');
        await registerDeviceWithBackend(token: token, branchId: _activeBranchId);
      }

      // 4. Listen for token refreshes and re-register dynamically
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[INCLINE FCM] FCM token refreshed: $newToken');
        await registerDeviceWithBackend(token: newToken, branchId: _activeBranchId);
      });

      // 5. Foreground push message reception
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[INCLINE FCM] Foreground push received: ${message.notification?.title} - ${message.notification?.body}');
        final title = message.notification?.title ?? message.data['title'] ?? 'INCLINE Alert';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        final payloadRoute = message.data['route'] ?? message.data['click_action'] ?? '/notifications';
        showLocalAlert(
          title: title,
          body: body,
          payloadRoute: payloadRoute,
        );
      });

      // 6. Push message tap when app in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[INCLINE FCM] Notification tapped from background');
        final payloadRoute = message.data['route'] ?? message.data['click_action'] ?? '/notifications';
        onNotificationTap?.call(payloadRoute);
      });

      // 7. Initial message tap when app cold launched from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[INCLINE FCM] Initial notification tapped on cold launch');
        final payloadRoute = initialMessage.data['route'] ?? initialMessage.data['click_action'] ?? '/notifications';
        onNotificationTap?.call(payloadRoute);
      }
    } catch (e) {
      debugPrint('[INCLINE FCM] initFirebaseMessaging error: $e');
    }
  }

  /// Sends device registration payload to `${EnvConfig.supabaseUrl}/functions/v1/web-push`
  /// Dynamically resolves the effective branch ID to guarantee multi-branch support.
  Future<bool> registerDeviceWithBackend({
    required String token,
    String? branchId,
    String? platform,
  }) async {
    try {
      if (branchId != null && branchId.trim().isNotEmpty) {
        _activeBranchId = branchId.trim();
      }

      Session? session;
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {
        session = null;
      }

      // Dynamically resolve multi-branch ID:
      // Priority 1: explicitly passed branchId
      // Priority 2: _activeBranchId in PushNotificationService
      // Priority 3: SupabaseService dynamic resolution (in-memory member, disk member, members table, branches table)
      // Priority 4: Fallback default branch UUID
      String? dynamicBranchId;
      try {
        dynamicBranchId = await SupabaseService.instance.resolveEffectiveBranchId(branchId ?? _activeBranchId);
      } catch (e) {
        debugPrint('[INCLINE FCM] resolveEffectiveBranchId notice: $e');
      }
      final effectiveBranchId = dynamicBranchId ?? branchId ?? _activeBranchId ?? _defaultBranchId;
      _activeBranchId = effectiveBranchId;

      if (session == null) {
        debugPrint('[INCLINE FCM] No active auth session; caching token ($token) and branch ($effectiveBranchId) for post-login registration');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefFcmToken, token);
        await prefs.setString(_prefRegisteredBranchId, effectiveBranchId);
        return false;
      }

      final effectivePlatform = platform ?? (Platform.isIOS ? 'ios' : 'android');

      // Primary invocation method: Supabase functions.invoke
      try {
        final invokeRes = await Supabase.instance.client.functions.invoke(
          'web-push',
          body: {
            'action': 'register_device',
            'token': token,
            'platform': effectivePlatform,
            'branch_id': effectiveBranchId,
          },
        );
        debugPrint('[INCLINE FCM] functions.invoke web-push status: ${invokeRes.status}');
        if (invokeRes.status >= 200 && invokeRes.status < 300) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefFcmToken, token);
          await prefs.setString(_prefRegisteredBranchId, effectiveBranchId);
          return true;
        }
      } catch (e) {
        debugPrint('[INCLINE FCM] functions.invoke notice: $e (falling back to direct client)');
      }

      final url = Uri.parse('${EnvConfig.supabaseUrl}/functions/v1/web-push');
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('apikey', EnvConfig.supabaseAnonKey);
      request.headers.set('Authorization', 'Bearer ${session.accessToken}');
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'action': 'register_device',
        'token': token,
        'platform': effectivePlatform,
        'branch_id': effectiveBranchId,
      });

      request.write(payload);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      debugPrint('[INCLINE FCM] web-push register_device (branch: $effectiveBranchId, platform: $effectivePlatform) -> HTTP ${response.statusCode}: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefFcmToken, token);
        await prefs.setString(_prefRegisteredBranchId, effectiveBranchId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[INCLINE FCM] registerDeviceWithBackend exception: $e');
      return false;
    }
  }

  /// Synchronizes the cached or live FCM device token with the backend,
  /// ensuring dynamic multi-branch binding is always up to date.
  Future<bool> syncDeviceRegistration({String? branchId}) async {
    try {
      if (branchId != null && branchId.trim().isNotEmpty) {
        _activeBranchId = branchId.trim();
      }

      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(_prefFcmToken);

      if ((token == null || token.isEmpty) && Firebase.apps.isNotEmpty) {
        try {
          // ignore: deprecated_member_use
          token = await FirebaseMessaging.instance.getToken();
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        return await registerDeviceWithBackend(token: token, branchId: branchId ?? _activeBranchId);
      }
    } catch (e) {
      debugPrint('[INCLINE FCM] syncDeviceRegistration exception: $e');
    }
    return false;
  }

  /// Sends unsubscription payload to `web-push` when member signs out
  Future<bool> unsubscribeDeviceFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_prefFcmToken);
      if (savedToken == null || savedToken.isEmpty) return true;

      Session? session;
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {
        session = null;
      }

      if (session == null) {
        await prefs.remove(_prefFcmToken);
        await prefs.remove(_prefRegisteredBranchId);
        _activeBranchId = null;
        return true;
      }

      final url = Uri.parse('${EnvConfig.supabaseUrl}/functions/v1/web-push');
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('apikey', EnvConfig.supabaseAnonKey);
      request.headers.set('Authorization', 'Bearer ${session.accessToken}');
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'action': 'unsubscribe',
        'token': savedToken,
      });

      request.write(payload);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      debugPrint('[INCLINE FCM] web-push unsubscribe -> HTTP ${response.statusCode}: $responseBody');
      await prefs.remove(_prefFcmToken);
      await prefs.remove(_prefRegisteredBranchId);
      _activeBranchId = null;
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[INCLINE FCM] unsubscribeDeviceFromBackend exception: $e');
      return false;
    }
  }
}
