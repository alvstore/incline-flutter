import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Reports client errors to the shared System Health RPC.
///
/// Errors captured before authentication are kept locally and submitted after
/// sign-in. Errors captured during an authenticated session are sent once;
/// logging failures are swallowed and are never re-logged by this service.
class AppErrorReportingService {
  AppErrorReportingService._();

  static final AppErrorReportingService instance =
      AppErrorReportingService._();

  static const _queueKey = 'incline_pending_app_error_logs';
  static const _maximumQueuedErrors = 50;
  static const _appVersion = '1.0.0'; // Keep aligned with pubspec.yaml.

  StreamSubscription<dynamic>? _authSubscription;
  String Function()? _currentScreenProvider;
  bool _initialized = false;
  bool _isFlushing = false;
  Future<void> _queueLock = Future<void>.value();
  int _queueIdCounter = 0;

  void setCurrentScreenProvider(String Function()? provider) {
    _currentScreenProvider = provider;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final client = SupabaseService.instance.client;
      _authSubscription = client.auth.onAuthStateChange.listen(
        (state) {
          if (state.session != null) unawaited(flushPending());
        },
        onError: (Object _) {},
      );
      _initialized = true;
      if (client.auth.currentSession != null) unawaited(flushPending());
    } catch (_) {
      // Error handling must remain safe before backend initialization.
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _initialized = false;
  }

  /// Never throws. Before login, stores a bounded, sanitized local queue.
  /// While signed in, sends the event directly and drops client-side failures.
  Future<void> record(
    Object error, {
    StackTrace? stackTrace,
    String? screen,
    String severity = 'error',
  }) async {
    try {
      final payload = _makePayload(
        message: error.toString(),
        stack: stackTrace?.toString(),
        screen: screen,
        severity: severity,
      );

      if (SupabaseService.instance.currentSession == null) {
        await _enqueue(payload);
        // Covers the race where sign-in completed while the queue was written.
        if (SupabaseService.instance.currentSession != null) {
          unawaited(flushPending());
        }
        return;
      }

      await _send(payload);
    } catch (_) {
      // Reporting failures must never escape or create recursive error logs.
    }
  }

  /// Sends only previously buffered pre-login errors, after a valid session
  /// exists. Failed sends remain queued for the next sign-in/app start.
  Future<void> flushPending() async {
    if (_isFlushing || SupabaseService.instance.currentSession == null) return;
    _isFlushing = true;
    try {
      final entries = await _withQueueLock(_readQueue);
      for (final entry in entries) {
        if (SupabaseService.instance.currentSession == null) break;
        final sent = await _send(entry.payload);
        if (!sent) break;
        await _withQueueLock(() => _removeQueued(entry.id));
      }
    } catch (_) {
      // Retain queued pre-login records if local storage or the RPC is unavailable.
    } finally {
      _isFlushing = false;
    }
  }

  Map<String, dynamic> _makePayload({
    required String message,
    required String? stack,
    required String? screen,
    required String severity,
  }) {
    return <String, dynamic>{
      'p_message': _sanitize(message, maxLength: 2000),
      'p_severity': _allowedSeverity(severity),
      'p_screen': _safeScreen(screen),
      'p_stack': stack == null ? '' : _sanitize(stack, maxLength: 12000),
      'p_app_version': _appVersion,
      'p_platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    };
  }

  Future<bool> _send(Map<String, dynamic> payload) async {
    try {
      final client = SupabaseService.instance.client;
      if (client.auth.currentSession == null) return false;
      await client.rpc('log_mobile_error', params: payload);
      return true;
    } catch (_) {
      // A client-side network/offline failure is intentionally dropped here.
      return false;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    await _withQueueLock(() async {
      final prefs = await SharedPreferences.getInstance();
      final entries = await _readQueue(prefs: prefs);
      _queueIdCounter++;
      final id = '${DateTime.now().microsecondsSinceEpoch}-$_queueIdCounter';
      entries.add(_QueuedError(id: id, payload: payload));
      if (entries.length > _maximumQueuedErrors) {
        entries.removeRange(0, entries.length - _maximumQueuedErrors);
      }
      await _writeQueue(prefs, entries);
    });
  }

  Future<List<_QueuedError>> _readQueue({SharedPreferences? prefs}) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    final raw = storage.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <_QueuedError>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      await storage.remove(_queueKey);
      return <_QueuedError>[];
    }
    if (decoded is! List) {
      await storage.remove(_queueKey);
      return <_QueuedError>[];
    }

    final entries = <_QueuedError>[];
    var needsUpgrade = false;
    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];
      if (value is! Map) continue;
      final row = Map<String, dynamic>.from(value);
      final nestedPayload = row['payload'];
      if (nestedPayload is Map && row['id'] is String) {
        final payload = _normalizePayload(
          Map<String, dynamic>.from(nestedPayload),
        );
        if (payload != null) {
          entries.add(_QueuedError(id: row['id'] as String, payload: payload));
        }
      } else {
        // Upgrade records written by the previous local-only table logger.
        final payload = _migrateLegacyPayload(row);
        if (payload != null) {
          needsUpgrade = true;
          entries.add(_QueuedError(
            id: 'legacy-$index-${_fingerprint(jsonEncode(row))}',
            payload: payload,
          ));
        }
      }
    }

    if (needsUpgrade) await _writeQueue(storage, entries);
    return entries;
  }

  Map<String, dynamic>? _migrateLegacyPayload(Map<String, dynamic> row) {
    final message = row['p_message'] ?? row['message'];
    if (message is! String || message.trim().isEmpty) return null;

    final rawSeverity = (row['p_severity'] ?? row['severity'] ?? 'error')
        .toString()
        .toLowerCase();
    final severity = rawSeverity == 'fatal' ? 'critical' : rawSeverity;
    final rawPlatform = (row['p_platform'] ?? row['platform'] ?? '')
        .toString()
        .toLowerCase();
    final platform = rawPlatform == 'ios' ? 'ios' : 'android';
    final rawStack = row['p_stack'] ?? row['stack'];

    return <String, dynamic>{
      'p_message': _sanitize(message, maxLength: 2000),
      'p_severity': _allowedSeverity(severity),
      'p_screen': _safeScreen(row['p_screen']?.toString()),
      'p_stack': rawStack is String ? _sanitize(rawStack, maxLength: 12000) : '',
      'p_app_version': _sanitize(
        (row['p_app_version'] ?? row['app_version'] ?? _appVersion).toString(),
        maxLength: 40,
      ),
      'p_platform': platform,
    };
  }

  Map<String, dynamic>? _normalizePayload(Map<String, dynamic> row) {
    final message = row['p_message'];
    if (message is! String || message.trim().isEmpty) return null;
    final stack = row['p_stack'];
    return <String, dynamic>{
      'p_message': _sanitize(message, maxLength: 2000),
      'p_severity': _allowedSeverity(row['p_severity']?.toString() ?? 'error'),
      'p_screen': _safeScreen(row['p_screen']?.toString()),
      'p_stack': stack is String ? _sanitize(stack, maxLength: 12000) : '',
      'p_app_version': _sanitize(
        row['p_app_version']?.toString() ?? _appVersion,
        maxLength: 40,
      ),
      'p_platform': row['p_platform']?.toString().toLowerCase() == 'ios'
          ? 'ios'
          : 'android',
    };
  }

  Future<void> _removeQueued(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readQueue(prefs: prefs);
    entries.removeWhere((entry) => entry.id == id);
    await _writeQueue(prefs, entries);
  }

  Future<void> _writeQueue(
    SharedPreferences prefs,
    List<_QueuedError> entries,
  ) async {
    if (entries.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }
    await prefs.setString(
      _queueKey,
      jsonEncode(entries
          .map((entry) => <String, dynamic>{
                'id': entry.id,
                'payload': entry.payload,
              })
          .toList()),
    );
  }

  Future<T> _withQueueLock<T>(Future<T> Function() operation) async {
    final previous = _queueLock;
    final release = Completer<void>();
    _queueLock = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  String _safeScreen(String? explicitScreen) {
    String? value = explicitScreen;
    if (value == null || value.trim().isEmpty) {
      try {
        value = _currentScreenProvider?.call();
      } catch (_) {
        value = null;
      }
    }
    if (value == null || value.trim().isEmpty) return '/startup';

    final parsed = Uri.tryParse(value.trim());
    final path = parsed?.hasScheme == true ? parsed!.path : (parsed?.path ?? value);
    final safePath = path.replaceAll(RegExp(r'[^a-zA-Z0-9_./-]'), '_');
    final normalized = safePath.startsWith('/') ? safePath : '/$safePath';
    return normalized.length > 200 ? normalized.substring(0, 200) : normalized;
  }

  String _allowedSeverity(String value) =>
      const {'info', 'warning', 'error', 'critical'}.contains(value.toLowerCase())
          ? value.toLowerCase()
          : 'error';

  String _sanitize(String value, {required int maxLength}) {
    var safe = value
        .replaceAll(RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false), 'Bearer [redacted]')
        .replaceAll(
          RegExp(
            r'(access[_-]?token|refresh[_-]?token|authorization|password|secret|apikey|api[_-]?key)\s*[:=]\s*[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1=[redacted]',
        )
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
        .replaceAll(
          RegExp(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b'),
          '[id]',
        )
        .replaceAll(RegExp(r'\+?\d[\d \t().-]{7,}\d'), '[phone]')
        .replaceAll(RegExp(r'https?://[^\s]+'), '[url]')
        .replaceAll(RegExp(r'/Users/[^/\s]+'), '[user-path]')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
    if (safe.length > maxLength) safe = safe.substring(0, maxLength);
    return safe;
  }

  String _fingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _QueuedError {
  const _QueuedError({required this.id, required this.payload});

  final String id;
  final Map<String, dynamic> payload;
}
