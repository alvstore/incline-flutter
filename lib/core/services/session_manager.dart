import 'dart:async';
import 'package:flutter/material.dart';
import 'supabase_service.dart';

/// Manages auth session lifecycle, expiry detection, and forced re-login.
class SessionManager extends ChangeNotifier {
  static final SessionManager instance = SessionManager._internal();
  SessionManager._internal();

  Timer? _inactivityTimer;
  bool _isSessionInvalid = false;
  String? _invalidReason;

  bool get isSessionInvalid => _isSessionInvalid;
  String? get invalidReason => _invalidReason;

  /// Starts listening to auth state changes and monitors session validity
  void init() {
    SupabaseService.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event.name == 'signedOut' || data.event.name == 'tokenRefreshed') {
        notifyListeners();
      }
    });
    resetInactivityTimer();
  }

  /// Records user touch/interaction to prevent idle logout
  void recordUserActivity() {
    resetInactivityTimer();
  }

  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // 30-minute inactivity window
    _inactivityTimer = Timer(const Duration(minutes: 30), () {
      invalidateSession(reason: 'Session timed out due to 30 minutes of inactivity.');
    });
  }

  /// Manually or programmatically invalidate session and trigger re-login
  void invalidateSession({String reason = 'Your session has expired. Please sign in again.'}) {
    _isSessionInvalid = true;
    _invalidReason = reason;
    SupabaseService.instance.signOut();
    notifyListeners();
  }

  /// Clears the invalid session flag once user reaches login
  void clearInvalidSession() {
    _isSessionInvalid = false;
    _invalidReason = null;
    notifyListeners();
  }
}
