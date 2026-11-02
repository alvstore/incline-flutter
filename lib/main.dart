import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/env_config.dart';
import 'core/models/models.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/session_manager.dart';
import 'core/services/app_error_reporting_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/biometric_auth_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/onboarding/incline_welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandling();

  // Initialize ThemeController
  await ThemeController.instance.init();

  // Initial system UI overlay styling adapted to device brightness
  final isDark = ThemeController.instance.isDarkMode;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor:
        isDark ? AppTheme.surfaceElevated : AppTheme.lightSurface,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  ));

  // Initialize Supabase & Session Manager
  try {
    await SupabaseService.instance.init();
    await AppErrorReportingService.instance.initialize();
  } catch (e) {
    debugPrint('[INCLINE] Supabase initialization notice: $e');
  }

  // Pre-load essential brand typography synchronously from local assets to eliminate font swapping / FOUT on launch
  try {
    GoogleFonts.outfit(fontWeight: FontWeight.w900);
    GoogleFonts.outfit(fontWeight: FontWeight.w700);
    GoogleFonts.outfit(fontWeight: FontWeight.w600);
    GoogleFonts.outfit(fontWeight: FontWeight.w400);
    GoogleFonts.inter(fontWeight: FontWeight.w400);
    await GoogleFonts.pendingFonts();
  } catch (e) {
    debugPrint('[INCLINE] Font preload notice: $e');
  }

  await SessionManager.instance.init();

  runApp(const InclineApp());
}

class InclineApp extends StatelessWidget {
  const InclineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _InclineAppRoot(),
    );
  }
}

class _InclineAppRoot extends ConsumerStatefulWidget {
  const _InclineAppRoot();

  @override
  ConsumerState<_InclineAppRoot> createState() => _InclineAppRootState();
}

class _InclineAppRootState extends ConsumerState<_InclineAppRoot> {
  bool _isLoading = true;
  bool _splashFinished = false;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    AppErrorReportingService.instance.setCurrentScreenProvider(() {
      try {
        return _router?.routerDelegate.currentConfiguration.uri.path ??
            '/startup';
      } catch (_) {
        return '/startup';
      }
    });
    _checkInitialState();
    SessionManager.instance.addListener(_onSessionStateChange);
  }

  @override
  void dispose() {
    SessionManager.instance.removeListener(_onSessionStateChange);
    AppErrorReportingService.instance.setCurrentScreenProvider(null);
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  void _onSessionStateChange() {
    if (SessionManager.instance.isSessionInvalid && _router != null) {
      _router!.go(AppRoutePaths.login);
    }
  }

  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    final permissionsGranted =
        prefs.getBool('has_granted_permissions') ?? false;
    final isAuth = SupabaseService.instance.isAuthenticated;

    Member? member;
    if (isAuth) {
      member = await SupabaseService.instance.fetchCurrentMember();

      // Check biometric authentication if enabled by member.
      final bioEnabled =
          await BiometricAuthService.instance.isBiometricLockEnabled();
      if (bioEnabled) {
        final authenticated = await BiometricAuthService.instance.authenticate(
          reason: 'Authenticate with Face ID / Biometrics to access Incline',
        );
        if (!authenticated) {
          await SupabaseService.instance.signOut();
          member = null;
        }
      }
    }

    // Immediately mount UI with cached/initial state for <100ms startup
    if (mounted) {
      setState(() {
        _router = AppRouter.createRouter(
          hasSeenOnboarding: seen,
          hasGrantedPermissions: permissionsGranted,
          initialMember: member,
        );
        _isLoading = false;
      });
    }

    // Initialize Push Notifications & Deep Link Routing asynchronously in background
    PushNotificationService.instance.init().then((_) {
      PushNotificationService.instance.isHydrationRemindersEnabled().then((enabled) {
        if (enabled) {
          PushNotificationService.instance.scheduleHydrationReminders(enabled: true);
        }
      });
    });

    DeepLinkService.instance.init(
      onRouteDispatched: (route, params) {
        debugPrint('[INCLINE] Deep link dispatch: $route ($params)');
        if (_router != null) {
          if (route.startsWith('/store') ||
              route.startsWith('/bookings') ||
              route.startsWith('/workout') ||
              route.startsWith('/profile')) {
            _router!.go(route);
          } else if (route.contains('payment/callback')) {
            _router!.go(AppRoutePaths.store);
          } else if (route == '/scan-login' || route == '/howbody-login') {
            final uri = Uri(path: route, queryParameters: params);
            _router!.go(uri.toString());
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    if (_isLoading || !_splashFinished || _router == null) {
      return MaterialApp(
        title: '${EnvConfig.appName} • ${EnvConfig.tagline}',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: InclineWelcomeScreen(
          onContinue: () {
            if (mounted) {
              setState(() {
                _splashFinished = true;
              });
            }
          },
        ),
      );
    }

    return MaterialApp.router(
      title: '${EnvConfig.appName} • ${EnvConfig.tagline}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router!,
    );
  }
}


void _installErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AppErrorReportingService.instance.record(
      details.exception,
      stackTrace: details.stack,
    ));
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(AppErrorReportingService.instance.record(
      error,
      stackTrace: stackTrace,
      severity: 'critical',
    ));
    return true;
  };

  ErrorWidget.builder = (details) => kDebugMode
      ? ErrorWidget(details.exception)
      : const _SoftErrorFallback();
}

class _SoftErrorFallback extends StatelessWidget {
  const _SoftErrorFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error, size: 32),
              const SizedBox(height: 12),
              Text(
                'This screen could not load',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Please try again. If this keeps happening, contact the Incline team.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
