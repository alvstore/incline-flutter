import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Applies a persistent 15-day inactivity window while Supabase continues to
/// refresh its short-lived access token normally.
class SessionManager extends ChangeNotifier {
  static final SessionManager instance = SessionManager._internal();
  SessionManager._internal();

  static const Duration inactivityWindow = Duration(days: 15);
  static const String _lastActivityKey = 'incline_last_member_activity';

  Timer? _inactivityTimer;
  StreamSubscription<dynamic>? _authSubscription;
  DateTime? _lastPersistedActivity;
  bool _isSessionInvalid = false;
  bool _isInitialized = false;
  String? _invalidReason;

  bool get isSessionInvalid => _isSessionInvalid;
  String? get invalidReason => _invalidReason;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final client = SupabaseService.instance.client;
      _authSubscription = client.auth.onAuthStateChange.listen((data) {
        switch (data.event.name) {
          case 'signedIn':
            clearInvalidSession();
            break;
          case 'signedOut':
            _inactivityTimer?.cancel();
            if (!_isSessionInvalid) {
              unawaited(_clearLastActivity());
            }
            notifyListeners();
            break;
          case 'tokenRefreshed':
            notifyListeners();
            break;
        }
      });

      if (!SupabaseService.instance.isAuthenticated) return;

      final prefs = await SharedPreferences.getInstance();
      final lastActivity = DateTime.tryParse(
        prefs.getString(_lastActivityKey) ?? '',
      );
      final now = DateTime.now();

      // Existing signed-in members get a fresh baseline once. Later launches
      // enforce the full persisted inactivity interval.
      if (lastActivity == null) {
        await _saveLastActivity(now);
        _startTimer(inactivityWindow);
        return;
      }

      final elapsed = now.difference(lastActivity);
      if (elapsed >= inactivityWindow) {
        invalidateSession(
          reason: 'Your session expired after 15 days of inactivity. Please sign in again.',
        );
        return;
      }

      _lastPersistedActivity = lastActivity;
      _startTimer(inactivityWindow - elapsed);
    } catch (error) {
      debugPrint('[SessionManager] Init error: $error');
      if (SupabaseService.instance.isAuthenticated) {
        _startTimer(inactivityWindow);
      }
    }
  }

  /// Called for member interaction. Persistence is throttled to one write per
  /// minute, while the in-memory deadline resets on each interaction.
  void recordUserActivity() {
    if (_isSessionInvalid || !SupabaseService.instance.isAuthenticated) return;

    final now = DateTime.now();
    _startTimer(inactivityWindow);
    final lastSaved = _lastPersistedActivity;
    if (lastSaved == null || now.difference(lastSaved) >= const Duration(minutes: 1)) {
      _lastPersistedActivity = now;
      unawaited(_saveLastActivity(now));
    }
  }

  void resetInactivityTimer() {
    recordUserActivity();
  }

  void _startTimer(Duration remaining) {
    _inactivityTimer?.cancel();
    if (remaining <= Duration.zero) {
      invalidateSession(
        reason: 'Your session expired after 15 days of inactivity. Please sign in again.',
      );
      return;
    }
    _inactivityTimer = Timer(remaining, () {
      invalidateSession(
        reason: 'Your session expired after 15 days of inactivity. Please sign in again.',
      );
    });
  }

  void invalidateSession({
    String reason = 'Your session has expired. Please sign in again.',
  }) {
    if (_isSessionInvalid) return;
    _inactivityTimer?.cancel();
    _isSessionInvalid = true;
    _invalidReason = reason;
    unawaited(SupabaseService.instance.signOut());
    notifyListeners();
  }

  /// Clears the invalid session flag after a successful sign-in.
  void clearInvalidSession() {
    _isSessionInvalid = false;
    _invalidReason = null;
    final now = DateTime.now();
    _lastPersistedActivity = now;
    _startTimer(inactivityWindow);
    unawaited(_saveLastActivity(now));
    notifyListeners();
  }

  Future<void> _saveLastActivity(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActivityKey, time.toIso8601String());
    } catch (error) {
      debugPrint('[SessionManager] Activity persistence error: $error');
    }
  }

  Future<void> _clearLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastActivityKey);
      _lastPersistedActivity = null;
    } catch (error) {
      debugPrint('[SessionManager] Activity cleanup error: $error');
    }
  }
}
