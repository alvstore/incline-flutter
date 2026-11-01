import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../routing/app_router.dart';
import '../../features/progress/components/howbody_link_sheet.dart';

/// Callback signature for handling recognized deep link destinations
typedef DeepLinkRouteHandler = void Function(String route, Map<String, String> queryParams);

/// Deep Links and Payment Return Flow Handler
/// Resolves custom scheme `incline://` and Universal Links `https://inclineclub.in/`
/// Supports instant navigation to Store items, Class bookings, Workout routines,
/// HOWBODY scanner pairing (`/scan-login`, `/howbody-login`),
/// and Razorpay / UPI payment callbacks (`incline://payment/callback?status=success&order_id=...`).
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  DeepLinkRouteHandler? _onRouteDispatched;

  /// Initializes deep link listening across cold boot and background resume
  Future<void> init({required DeepLinkRouteHandler onRouteDispatched}) async {
    _onRouteDispatched = onRouteDispatched;

    if (kIsWeb) return;

    try {
      // 1. Check for initial launch link (cold boot)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }

      // 2. Listen to subsequent stream of incoming links (warm boot / foreground)
      _sub?.cancel();
      _sub = _appLinks.uriLinkStream.listen(
        (uri) => _handleIncomingUri(uri),
        onError: (err) => debugPrint('[INCLINE] uriLinkStream error: $err'),
      );
    } catch (e) {
      debugPrint('[INCLINE] DeepLinkService init error: $e');
    }
  }

  void _handleIncomingUri(Uri uri, [BuildContext? explicitContext]) {
    debugPrint('[INCLINE] Received Deep Link: $uri');

    // Extract path and query parameters
    final host = uri.host;
    final path = uri.path;
    final params = uri.queryParameters;

    // e.g. incline://store/product/123 or https://inclineclub.in/store/product/123
    String targetRoute = '/';
    if (uri.scheme == 'incline') {
      if (host.isNotEmpty) {
        targetRoute = '/$host$path';
      } else {
        targetRoute = path;
      }
    } else {
      targetRoute = path;
    }

    // Clean up trailing slash
    if (targetRoute.endsWith('/') && targetRoute.length > 1) {
      targetRoute = targetRoute.substring(0, targetRoute.length - 1);
    }

    // Dispatch to registered route handler
    _onRouteDispatched?.call(targetRoute, params);

    // Universal OS Camera Deep Link for HOWBODY 3D Scanner
    if (targetRoute == '/scan-login' || targetRoute == '/howbody-login') {
      final eq = (params['equipmentNo'] ?? params['equipment_no'] ?? params['device'] ?? '').trim();
      final sid = (params['scanId'] ?? params['scan_id'] ?? params['session'] ?? '').trim();
      final kind = (params['kind'] ?? params['scanType'] ?? 'body').trim().toLowerCase();

      if (eq.isNotEmpty && sid.isNotEmpty) {
        final ctx = explicitContext ?? rootNavigatorKey.currentContext;
        if (ctx != null) {
          HowbodyLinkSheet.show(
            ctx,
            equipmentNo: eq,
            scanId: sid,
            initialKind: kind,
          );
        }
      }
    }
  }

  /// Manually dispatches an incoming URI (useful for testing and OS notifications)
  void handleUri(Uri uri, [BuildContext? context]) {
    _handleIncomingUri(uri, context);
  }

  /// Disposes stream subscription
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
