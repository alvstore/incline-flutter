import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clean, production-grade error mapper that sanitizes backend exceptions
/// into dignified, member-friendly messages without leaking infrastructure URLs or technical stack traces.
class UserFriendlyErrorMapper {
  UserFriendlyErrorMapper._();

  /// Converts any authentication or network error into a clean, human-readable member notice.
  static String toAuthErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    debugPrint('[Incline Security Shield] Raw auth exception sanitized: $error');

    // 1. Network / Connectivity / DNS / Host lookup failures
    if (error is SocketException ||
        error is AuthRetryableFetchException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('ClientException') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Connection timed out') ||
        error.toString().contains('HandshakeException')) {
      return 'Unable to reach Incline servers. Please check your internet connection or try again shortly.';
    }

    // 2. Supabase / GoTrue Auth specific exceptions
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final status = error.statusCode;

      if (status == '400' || msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return 'Incorrect email, phone, or password. Please verify your credentials.';
      }

      if (status == '429' || msg.contains('rate limit') || msg.contains('too many requests')) {
        return 'Too many login attempts. Please wait a moment before trying again.';
      }

      if (msg.contains('user not found')) {
        return 'No Incline membership found with these credentials.';
      }

      if (msg.contains('email not confirmed')) {
        return 'Please confirm your email address before logging in.';
      }

      if (msg.contains('user banned') || msg.contains('disabled')) {
        return 'Your account is deactivated. Please contact Incline Concierge for assistance.';
      }

      if (msg.contains('password should be at least')) {
        return 'Password does not meet length requirements.';
      }
    }

    // 3. String-based fallback matching without exposing raw error strings
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('invalid login credentials') || errStr.contains('invalid credentials')) {
      return 'Incorrect email, phone, or password. Please verify your credentials.';
    }

    if (errStr.contains('failed host lookup') ||
        errStr.contains('socket') ||
        errStr.contains('clientexception') ||
        errStr.contains('offline') ||
        errStr.contains('network')) {
      return 'Unable to connect to Incline services. Please verify your internet connection.';
    }

    if (errStr.contains('rate limit') || errStr.contains('429')) {
      return 'Too many requests. Please pause a moment before retrying.';
    }

    if (errStr.contains('jwt') || errStr.contains('token') || errStr.contains('expired')) {
      return 'Your session has expired. Please sign in again.';
    }

    // 4. Default luxury production fallback
    return 'Authentication could not be completed at this time. Please try again or contact Club Concierge.';
  }

  /// Converts general action/operation errors into clean member notices
  static String toGeneralErrorMessage(dynamic error, {String action = 'operation'}) {
    if (error == null) return 'Unable to complete $action. Please try again.';

    debugPrint('[Incline Security Shield] Raw operation exception sanitized: $error');

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('failed host lookup') ||
        errStr.contains('socket') ||
        errStr.contains('network') ||
        errStr.contains('clientexception')) {
      return 'Network connection interrupted. Please check your connectivity.';
    }

    return 'Unable to complete $action right now. Please try again later.';
  }
}
