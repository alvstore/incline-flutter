import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/bookings/bookings_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/incline_welcome_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/permissions_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/store/store_screen.dart';
import '../../features/workout/workout_execution_sheet.dart';
import '../../features/workout/workout_screen.dart';
import '../models/models.dart';
import '../services/session_manager.dart';
import '../services/supabase_service.dart';
import '../widgets/floating_capsule_nav_bar.dart';

import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_controller.dart';
import '../theme/app_theme.dart';
import '../../features/progress/components/howbody_link_sheet.dart';

/// Typed route path constants for declarative deep linking
abstract class AppRoutePaths {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String permissions = '/permissions';
  static const String login = '/login';
  static const String passwordLogin = '/login/password';
  static const String home = '/home';
  static const String bookings = '/bookings';
  static const String workout = '/workout';
  static const String workoutExecution = '/workout/execution';
  static const String store = '/store';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String scanLogin = '/scan-login';
  static const String howbodyLogin = '/howbody-login';
}

/// Key accessors for root and shell navigators
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Declarative GoRouter configuration with typed paths, auth guards, and deep-linkable modals
class AppRouter {
  static bool hasGrantedPermissions = false;
  static bool hasSeenOnboarding = false;

  static GoRouter createRouter({
    required bool hasSeenOnboarding,
    bool? initialHasGrantedPermissions,
    bool hasGrantedPermissions = false,
    Member? initialMember,
  }) {
    AppRouter.hasSeenOnboarding = hasSeenOnboarding;
    AppRouter.hasGrantedPermissions =
        initialHasGrantedPermissions ?? hasGrantedPermissions;
    final isAuth = SupabaseService.instance.isAuthenticated;

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: isAuth
          ? (AppRouter.hasGrantedPermissions
              ? AppRoutePaths.home
              : AppRoutePaths.permissions)
          : AppRoutePaths.login,
      redirect: (context, state) {
        final isAuth = SupabaseService.instance.isAuthenticated;
        final isLoggingIn = state.matchedLocation == AppRoutePaths.login ||
            state.matchedLocation == AppRoutePaths.passwordLogin;
        final isWelcome = state.matchedLocation == AppRoutePaths.splash;
        final isOnboarding = state.matchedLocation == AppRoutePaths.onboarding;
        final isPermissions =
            state.matchedLocation == AppRoutePaths.permissions;

        // 1. Unauthenticated users: direct to login screen after splash
        if (!isAuth) {
          if (isOnboarding || isWelcome) {
            return null;
          }
          if (!isLoggingIn) {
            return AppRoutePaths.login;
          }
          return null;
        }

        // 2. Authenticated users: must grant permissions before accessing dashboard
        if (!AppRouter.hasGrantedPermissions && !isPermissions) {
          return AppRoutePaths.permissions;
        }

        // 3. Authenticated users should not revisit login or onboarding
        if (isLoggingIn || isOnboarding) {
          return AppRouter.hasGrantedPermissions
              ? AppRoutePaths.home
              : AppRoutePaths.permissions;
        }

        return null;
      },
      routes: [
        // Welcome entry route; Continue opens real auth or member home.
        GoRoute(
          path: AppRoutePaths.splash,
          builder: (context, state) => InclineWelcomeScreen(
            onContinue: () {
              if (SupabaseService.instance.isAuthenticated) {
                context.go(AppRoutePaths.home);
              } else {
                context.go(AppRoutePaths.login);
              }
            },
          ),
        ),

        // Onboarding
        GoRoute(
          path: AppRoutePaths.onboarding,
          builder: (context, state) => OnboardingScreen(
            onComplete: () {
              AppRouter.hasSeenOnboarding = true;
              SharedPreferences.getInstance()
                  .then((p) => p.setBool('seen_onboarding', true));
              if (!AppRouter.hasGrantedPermissions) {
                context.go(AppRoutePaths.permissions);
              } else if (SupabaseService.instance.isAuthenticated) {
                context.go(AppRoutePaths.home);
              } else {
                context.go(AppRoutePaths.login);
              }
            },
          ),
        ),

        // Authentication - 2026 World-Class Luxury Authentication
        GoRoute(
          path: AppRoutePaths.login,
          builder: (context, state) => LoginScreen(
            onLoginSuccess: () => context.go(
              AppRouter.hasGrantedPermissions
                  ? AppRoutePaths.home
                  : AppRoutePaths.permissions,
            ),
          ),
        ),

        // Direct Password Mode Route
        GoRoute(
          path: AppRoutePaths.passwordLogin,
          builder: (context, state) => LoginScreen(
            onLoginSuccess: () => context.go(
              AppRouter.hasGrantedPermissions
                  ? AppRoutePaths.home
                  : AppRoutePaths.permissions,
            ),
          ),
        ),

        // Notifications Modal / Deep link
        GoRoute(
          path: AppRoutePaths.notifications,
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: NotificationsScreen(
              onNavigateToBookings: () => context.go(AppRoutePaths.bookings),
              onNavigateToWorkout: () => context.go(AppRoutePaths.workout),
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        ),

        // Fullscreen Active Workout Execution Player
        GoRoute(
          path: AppRoutePaths.workoutExecution,
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) {
            final day = state.extra as WorkoutDay?;
            if (day == null) {
              return MaterialPage(
                child: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Invalid Workout Session'),
                    ),
                  ),
                ),
              );
            }
            return MaterialPage(
              fullscreenDialog: true,
              child: WorkoutExecutionSheet(
                day: day,
                initialExerciseIndex: 0,
                onExerciseUpdated: () {},
              ),
            );
          },
        ),

        // Fullscreen App Launch Permissions Screen
        GoRoute(
          path: AppRoutePaths.permissions,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AppPermissionsScreen(),
        ),

        // Stateful Navigation Shell with M3 NavigationBar
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return AppScaffoldShell(
              currentPath: state.matchedLocation,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: AppRoutePaths.home,
              pageBuilder: (context, state) => NoTransitionPage(
                child: HomeScreen(
                  member: initialMember,
                  onNavigateTab: (index) {
                    while (_shellNavigatorKey.currentState?.canPop() == true) {
                      _shellNavigatorKey.currentState?.pop();
                    }
                    switch (index) {
                      case 0:
                        context.go(AppRoutePaths.bookings);
                        break;
                      case 1:
                        context.go(AppRoutePaths.workout);
                        break;
                      case 2:
                        context.go(AppRoutePaths.home);
                        break;
                      case 3:
                        context.go(AppRoutePaths.store);
                        break;
                      case 4:
                        context.go(AppRoutePaths.activity);
                        break;
                    }
                  },
                  onStartWorkout: () => context.go(AppRoutePaths.workout),
                  onOpenNotifications: () =>
                      context.push(AppRoutePaths.notifications),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutePaths.bookings,
              pageBuilder: (context, state) {
                final sectionParam = state.uri.queryParameters['section'];
                final filterParam = state.uri.queryParameters['filter'];
                final initialSection = int.tryParse(sectionParam ?? '') ?? 0;
                return NoTransitionPage(
                  key: state.pageKey,
                  child: BookingsScreen(
                    key: ValueKey('bookings_${sectionParam}_$filterParam'),
                    member: initialMember,
                    initialSection: initialSection,
                    initialRecoveryFilter: filterParam,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutePaths.workout,
              pageBuilder: (context, state) {
                final tabParam = state.uri.queryParameters['tab'];
                final initialTab = int.tryParse(tabParam ?? '') ?? 0;
                return NoTransitionPage(
                  key: state.pageKey,
                  child: WorkoutScreen(
                    key: ValueKey('workout_$tabParam'),
                    member: initialMember,
                    initialTab: initialTab,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutePaths.store,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: StoreScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutePaths.activity,
              pageBuilder: (context, state) {
                final tabParam = state.uri.queryParameters['tab'];
                final initialSubTab = int.tryParse(tabParam ?? '') ?? 0;
                return NoTransitionPage(
                  child: ActivityScreen(
                    member: initialMember,
                    initialSubTab: initialSubTab,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutePaths.profile,
              pageBuilder: (context, state) => NoTransitionPage(
                child: ProfileScreen(
                  member: initialMember,
                  onSignOut: () async {
                    await SupabaseService.instance.signOut();
                    if (context.mounted) {
                      context.go(AppRoutePaths.login);
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        // Universal Scanner Session Links
        GoRoute(
          path: AppRoutePaths.scanLogin,
          builder: (context, state) {
            final eq = (state.uri.queryParameters['equipmentNo'] ?? state.uri.queryParameters['equipment_no'] ?? '').trim();
            final sid = (state.uri.queryParameters['scanId'] ?? state.uri.queryParameters['scan_id'] ?? '').trim();
            final kind = (state.uri.queryParameters['kind'] ?? 'body').trim();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (eq.isNotEmpty && sid.isNotEmpty && context.mounted) {
                HowbodyLinkSheet.show(
                  context,
                  equipmentNo: eq,
                  scanId: sid,
                  initialKind: kind,
                  member: initialMember,
                );
              }
            });

            return ActivityScreen(
              key: const ValueKey('activity_scan_login'),
              member: initialMember,
              initialSubTab: 1, // Body & 3D Progress sub-tab
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.howbodyLogin,
          builder: (context, state) {
            final eq = (state.uri.queryParameters['equipmentNo'] ?? state.uri.queryParameters['equipment_no'] ?? '').trim();
            final sid = (state.uri.queryParameters['scanId'] ?? state.uri.queryParameters['scan_id'] ?? '').trim();
            final kind = (state.uri.queryParameters['kind'] ?? 'body').trim();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (eq.isNotEmpty && sid.isNotEmpty && context.mounted) {
                HowbodyLinkSheet.show(
                  context,
                  equipmentNo: eq,
                  scanId: sid,
                  initialKind: kind,
                  member: initialMember,
                );
              }
            });

            return ActivityScreen(
              key: const ValueKey('activity_howbody_login'),
              member: initialMember,
              initialSubTab: 1, // Body & 3D Progress sub-tab
            );
          },
        ),
      ],
      errorBuilder: (context, state) {
        return Scaffold(
          backgroundColor: ThemeController.instance.isDark
              ? InclineColors.bgPrimary
              : InclineColors.lightBgPrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: ThemeController.instance.isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutePaths.home);
                }
              },
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: InclineColors.accentOrange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: InclineColors.accentOrange.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 48,
                        color: InclineColors.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Unrecognized Code or Link',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ThemeController.instance.isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This code is not a recognized Incline workout, pass, or scanner session. You can safely return to your home dashboard or workout screen.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ThemeController.instance.isDark ? Colors.white60 : Colors.black54,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutePaths.home),
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: Text(
                          'Return to Home Dashboard',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InclineColors.accentOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutePaths.workout);
                          }
                        },
                        icon: const Icon(Icons.fitness_center_rounded, size: 16),
                        label: Text(
                          'Go to Workout & Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeController.instance.isDark ? Colors.white : Colors.black87,
                          side: BorderSide(
                            color: ThemeController.instance.isDark ? Colors.white24 : Colors.black26,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// M3 Scaffold Shell with tactile responsive bottom navigation
class AppScaffoldShell extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AppScaffoldShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  int _calculateSelectedIndex() {
    if (currentPath.startsWith(AppRoutePaths.bookings)) return 0;
    if (currentPath.startsWith(AppRoutePaths.workout)) return 1;
    if (currentPath.startsWith(AppRoutePaths.home)) return 2;
    if (currentPath.startsWith(AppRoutePaths.store)) return 3;
    if (currentPath.startsWith(AppRoutePaths.activity)) return 4;
    return 2; // Default to Center Home
  }

  void _onItemTapped(BuildContext context, int index) {
    HapticFeedback.lightImpact();
    // Safely pop all pushed sub-screens on the shell navigator stack so the user returns to the root of the tab
    while (_shellNavigatorKey.currentState?.canPop() == true) {
      _shellNavigatorKey.currentState?.pop();
    }
    switch (index) {
      case 0:
        context.go(AppRoutePaths.bookings);
        break;
      case 1:
        context.go(AppRoutePaths.workout);
        break;
      case 2:
        context.go(AppRoutePaths.home);
        break;
      case 3:
        context.go(AppRoutePaths.store);
        break;
      case 4:
        context.go(AppRoutePaths.activity);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex();
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: (_) => SessionManager.instance.recordUserActivity(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBody: true,
        body: child,
        bottomNavigationBar: SafeArea(
          top: false,
          child: FloatingCapsuleNavBar(
            selectedIndex: selectedIndex,
            onItemSelected: (idx) => _onItemTapped(context, idx),
            items: const [
              CapsuleNavItem(
                outlineIcon: Icons.hot_tub_outlined,
                filledIcon: Icons.hot_tub_rounded,
                label: 'Bookings',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.fitness_center_outlined,
                filledIcon: Icons.fitness_center_rounded,
                label: 'Workout',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.home_outlined,
                filledIcon: Icons.home_rounded,
                label: 'Home',
                isCenterHero: true,
              ),
              CapsuleNavItem(
                outlineIcon: Icons.shopping_bag_outlined,
                filledIcon: Icons.shopping_bag_rounded,
                label: 'Store',
              ),
              CapsuleNavItem(
                outlineIcon: Icons.insights_outlined,
                filledIcon: Icons.insights_rounded,
                label: 'Activity',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
