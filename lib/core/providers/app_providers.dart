import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/session_manager.dart';
import '../services/watch_sync_service.dart';
import '../theme/theme_controller.dart';

// -----------------------------------------------------------------------------
// 1. Theme State Management
// -----------------------------------------------------------------------------

/// Notifier to manage ThemeMode dynamically and reactively with Riverpod
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeController.instance.themeMode) {
    ThemeController.instance.addListener(_syncFromController);
  }

  void _syncFromController() {
    if (state != ThemeController.instance.themeMode) {
      state = ThemeController.instance.themeMode;
    }
  }

  Future<void> toggleTheme() async {
    await ThemeController.instance.toggleTheme();
    state = ThemeController.instance.themeMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ThemeController.instance.setThemeMode(mode);
    state = ThemeController.instance.themeMode;
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_syncFromController);
    super.dispose();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeProvider);
  return mode == ThemeMode.dark;
});

// -----------------------------------------------------------------------------
// 2. Member & Auth State Management
// -----------------------------------------------------------------------------

class MemberNotifier extends StateNotifier<AsyncValue<Member?>> {
  MemberNotifier() : super(const AsyncValue.loading()) {
    loadMember();
  }

  Future<void> loadMember() async {
    try {
      state = const AsyncValue.loading();
      if (!SupabaseService.instance.isAuthenticated) {
        state = const AsyncValue.data(null);
        return;
      }
      final member = await SupabaseService.instance.fetchCurrentMember();
      state = AsyncValue.data(member);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setMember(Member? member) {
    state = AsyncValue.data(member);
  }

  void clearMember() {
    state = const AsyncValue.data(null);
  }
}

final memberProvider = StateNotifierProvider<MemberNotifier, AsyncValue<Member?>>((ref) {
  return MemberNotifier();
});

// -----------------------------------------------------------------------------
// 3. Health & Watch Telemetry State Management
// -----------------------------------------------------------------------------

class WatchSyncNotifier extends StateNotifier<WatchSyncData> {
  WatchSyncNotifier() : super(WatchSyncService.instance.data) {
    WatchSyncService.instance.addListener(_syncFromService);
  }

  void _syncFromService() {
    state = WatchSyncService.instance.data;
  }

  Future<void> syncNow() async {
    await WatchSyncService.instance.syncNow();
    state = WatchSyncService.instance.data;
  }

  @override
  void dispose() {
    WatchSyncService.instance.removeListener(_syncFromService);
    super.dispose();
  }
}

final watchSyncProvider = StateNotifierProvider<WatchSyncNotifier, WatchSyncData>((ref) {
  return WatchSyncNotifier();
});

// -----------------------------------------------------------------------------
// 4. Incline Member Dashboard Summary Provider (Async)
// -----------------------------------------------------------------------------

class DashboardSummary {
  final Membership? membership;
  final WorkoutPlan? workoutPlan;
  final StreakData? streakData;
  final List<GymClass> todayClasses;
  final List<GymNotification> notifications;
  final MemberDietPlan? dietPlan;
  final MyTrainer? assignedTrainer;
  final int pendingRequestsCount;
  final MemberPtPackage? ptPackage;

  const DashboardSummary({
    this.membership,
    this.workoutPlan,
    this.streakData,
    this.todayClasses = const [],
    this.notifications = const [],
    this.dietPlan,
    this.assignedTrainer,
    this.pendingRequestsCount = 0,
    this.ptPackage,
  });
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final memberAsync = ref.watch(memberProvider);
  final member = memberAsync.value ?? SupabaseService.instance.cachedMember;
  final memberId = member?.id ?? SupabaseService.instance.currentUser?.id ?? '';

  final results = await Future.wait([
    SupabaseService.instance.fetchActiveMembership(memberId),
    SupabaseService.instance.fetchWorkoutPlan(memberId),
    SupabaseService.instance.fetchMemberStreak(memberId),
    SupabaseService.instance.fetchGymClasses(),
    SupabaseService.instance.fetchNotifications(),
    SupabaseService.instance.fetchDietPlan(memberId),
    SupabaseService.instance.fetchAssignedTrainer(),
    SupabaseService.instance.fetchMyRequests(memberId),
    SupabaseService.instance.fetchMemberPtPackage(memberId),
  ]);

  final requests = results[7] as List<MemberRequest>;
  final pendingCount = requests.where((r) => r.isPending).length;

  return DashboardSummary(
    membership: results[0] as Membership?,
    workoutPlan: results[1] as WorkoutPlan?,
    streakData: results[2] as StreakData?,
    todayClasses: results[3] as List<GymClass>,
    notifications: results[4] as List<GymNotification>,
    dietPlan: results[5] as MemberDietPlan?,
    assignedTrainer: results[6] as MyTrainer?,
    pendingRequestsCount: pendingCount,
    ptPackage: results[8] as MemberPtPackage?,
  );
});

// -----------------------------------------------------------------------------
// 5. Session & Inactivity State
// -----------------------------------------------------------------------------

final isSessionInvalidProvider = Provider<bool>((ref) {
  // SessionManager notification can trigger rebuilds
  return SessionManager.instance.isSessionInvalid;
});
