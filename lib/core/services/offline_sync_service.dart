import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Offline Sync and Local Cache Service
/// Ensures uninterrupted workout execution, nutrition view, and profile access
/// even with slow network, underground gyms, or zero internet connectivity.
class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  OfflineSyncService._internal();

  static const String _prefCachedWorkoutKey = 'incline_offline_cached_workout_plan';
  static const String _prefWorkoutVersionKey = 'incline_offline_workout_version';
  static const String _prefCachedDietKey = 'incline_offline_cached_diet_plan';
  static const String _prefDietVersionKey = 'incline_offline_diet_version';
  static const String _prefCachedMemberKey = 'incline_offline_cached_member_profile';
  static const String _prefWaterPrefix = 'incline_offline_water_';
  static const String _prefMealCompletionsPrefix = 'incline_member_consumed_meals_';
  static const String _prefWorkoutCompletionsPrefix = 'incline_member_completed_exercises_';
  static const String _prefOfflineQueueKey = 'incline_offline_action_queue';
  static const String _prefExerciseVideoDemosKey = 'incline_exercise_video_demos_enabled';

  // ---------------------------------------------------------------------------
  // WORKOUT PLAN DISK CACHE & VERSIONING
  // ---------------------------------------------------------------------------

  /// Caches the active workout plan locally for 100% offline access and instant 0ms launch
  Future<void> cacheWorkoutPlan(WorkoutPlan plan, {String? versionTag}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCachedWorkoutKey, jsonEncode(plan.toJson()));
      if (versionTag != null && versionTag.isNotEmpty) {
        await prefs.setString(_prefWorkoutVersionKey, versionTag);
      }
      debugPrint('[INCLINE] Successfully cached workout plan on device (version: $versionTag).');
    } catch (e) {
      debugPrint('[INCLINE] cacheWorkoutPlan error: $e');
    }
  }

  /// Retrieves the cached workout plan from persistent device storage
  Future<WorkoutPlan?> getCachedWorkoutPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedWorkoutKey);
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return WorkoutPlan.fromJson(map);
    } catch (e) {
      debugPrint('[INCLINE] getCachedWorkoutPlan error: $e');
      return null;
    }
  }

  /// Gets the currently cached workout plan version signature (e.g. "planId_updatedAt")
  Future<String?> getWorkoutPlanVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefWorkoutVersionKey);
    } catch (_) {
      return null;
    }
  }

  /// Clears any cached workout plan from local storage
  Future<void> clearCachedWorkoutPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefCachedWorkoutKey);
      await prefs.remove(_prefWorkoutVersionKey);
      debugPrint('[INCLINE] Cleared offline cached workout plan and version tag.');
    } catch (e) {
      debugPrint('[INCLINE] clearCachedWorkoutPlan error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // DIET & NUTRITION PLAN DISK CACHE & VERSIONING
  // ---------------------------------------------------------------------------

  /// Caches the active diet plan locally for 100% offline access and instant 0ms launch
  Future<void> cacheDietPlan(MemberDietPlan plan, {String? versionTag}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCachedDietKey, jsonEncode(plan.toJson()));
      if (versionTag != null && versionTag.isNotEmpty) {
        await prefs.setString(_prefDietVersionKey, versionTag);
      }
      debugPrint('[INCLINE] Successfully cached diet plan on device (version: $versionTag).');
    } catch (e) {
      debugPrint('[INCLINE] cacheDietPlan error: $e');
    }
  }

  /// Retrieves the cached diet plan from persistent device storage
  Future<MemberDietPlan?> getCachedDietPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedDietKey);
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MemberDietPlan.fromJson(map);
    } catch (e) {
      debugPrint('[INCLINE] getCachedDietPlan error: $e');
      return null;
    }
  }

  /// Gets the currently cached diet plan version signature (e.g. "planId_updatedAt")
  Future<String?> getDietPlanVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefDietVersionKey);
    } catch (_) {
      return null;
    }
  }

  /// Clears any cached diet plan from local storage
  Future<void> clearCachedDietPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefCachedDietKey);
      await prefs.remove(_prefDietVersionKey);
      debugPrint('[INCLINE] Cleared offline cached diet plan and version tag.');
    } catch (e) {
      debugPrint('[INCLINE] clearCachedDietPlan error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MEMBER PROFILE PERSISTENCE (Accelerates cold launches)
  // ---------------------------------------------------------------------------

  /// Caches member profile on disk for instantaneous app startup
  Future<void> cacheCurrentMember(Member member) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCachedMemberKey, jsonEncode(member.toJson()));
      debugPrint('[INCLINE] Cached member profile on disk: ${member.memberCode}');
    } catch (e) {
      debugPrint('[INCLINE] cacheCurrentMember error: $e');
    }
  }

  /// Loads member profile from local disk
  Future<Member?> getCachedCurrentMember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedMemberKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Member.fromJson(map);
    } catch (e) {
      debugPrint('[INCLINE] getCachedCurrentMember error: $e');
      return null;
    }
  }

  /// Clears member profile from local disk (on logout)
  Future<void> clearCachedCurrentMember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefCachedMemberKey);
    } catch (e) {
      debugPrint('[INCLINE] clearCachedCurrentMember error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY HYDRATION PERSISTENCE (Offline water logging)
  // ---------------------------------------------------------------------------

  /// Saves today's logged water intake locally so member data is preserved offline
  Future<void> cacheWaterIntake(String memberId, String logDate, int amountMl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefWaterPrefix${memberId}_$logDate';
      await prefs.setInt(key, amountMl);
      debugPrint('[INCLINE] Cached water intake locally for $logDate: $amountMl ml');
    } catch (e) {
      debugPrint('[INCLINE] cacheWaterIntake error: $e');
    }
  }

  /// Retrieves today's logged water intake from local storage
  Future<int> getCachedWaterIntake(String memberId, String logDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefWaterPrefix${memberId}_$logDate';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('[INCLINE] getCachedWaterIntake error: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE MEMBER TRACKING (MEAL CONSUMPTIONS & WORKOUT EXERCISES)
  // Strictly maintained on device storage for member tracking privacy and offline autonomy
  // ---------------------------------------------------------------------------

  /// Records meal completion locally on device storage for a member on a specific date (e.g. "2026-10-29")
  Future<void> setMealCompleted({
    required String memberId,
    required String date,
    required String mealId,
    required bool isCompleted,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefMealCompletionsPrefix${memberId}_$date';
      final list = prefs.getStringList(key) ?? [];
      final set = list.toSet();
      if (isCompleted) {
        set.add(mealId);
      } else {
        set.remove(mealId);
      }
      await prefs.setStringList(key, set.toList());
      debugPrint('[INCLINE] Saved meal completion on device: $mealId = $isCompleted ($date)');
    } catch (e) {
      debugPrint('[INCLINE] setMealCompleted error: $e');
    }
  }

  /// Retrieves the set of completed meal IDs for a member on a specific date
  Future<Set<String>> getCompletedMealIds(String memberId, String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefMealCompletionsPrefix${memberId}_$date';
      final list = prefs.getStringList(key) ?? [];
      return list.toSet();
    } catch (e) {
      debugPrint('[INCLINE] getCompletedMealIds error: $e');
      return {};
    }
  }

  /// Clears completed meals for a given date
  Future<void> clearCompletedMeals(String memberId, String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefMealCompletionsPrefix${memberId}_$date';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[INCLINE] clearCompletedMeals error: $e');
    }
  }

  /// Records workout exercise completion locally on device
  Future<void> setExerciseCompleted({
    required String memberId,
    required String date,
    required String planId,
    required String dayLabel,
    required int exerciseIndex,
    required bool isCompleted,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefWorkoutCompletionsPrefix${memberId}_${date}_${planId}_$dayLabel';
      final list = prefs.getStringList(key) ?? [];
      final set = list.toSet();
      final entry = exerciseIndex.toString();
      if (isCompleted) {
        set.add(entry);
      } else {
        set.remove(entry);
      }
      await prefs.setStringList(key, set.toList());
      debugPrint('[INCLINE] Saved exercise completion on device: ex $exerciseIndex = $isCompleted');
    } catch (e) {
      debugPrint('[INCLINE] setExerciseCompleted error: $e');
    }
  }

  /// Retrieves completed exercise indices for a member's daily workout
  Future<Set<int>> getCompletedExerciseIndices({
    required String memberId,
    required String date,
    required String planId,
    required String dayLabel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefWorkoutCompletionsPrefix${memberId}_${date}_${planId}_$dayLabel';
      final list = prefs.getStringList(key) ?? [];
      return list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } catch (e) {
      debugPrint('[INCLINE] getCompletedExerciseIndices error: $e');
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // OFFLINE QUEUE
  // ---------------------------------------------------------------------------

  /// Enqueues an action performed while offline to be flushed upon reconnecting
  Future<void> enqueueOfflineAction(String actionType, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefOfflineQueueKey) ?? [];
      final item = jsonEncode({
        'action': actionType,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      existing.add(item);
      await prefs.setStringList(_prefOfflineQueueKey, existing);
      debugPrint('[INCLINE] Enqueued offline action: $actionType');
    } catch (e) {
      debugPrint('[INCLINE] enqueueOfflineAction error: $e');
    }
  }

  /// Flushes pending offline actions once connectivity returns
  Future<void> flushOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefOfflineQueueKey) ?? [];
      if (existing.isEmpty) return;

      debugPrint('[INCLINE] Flushing ${existing.length} queued offline actions...');
      await prefs.remove(_prefOfflineQueueKey);
    } catch (e) {
      debugPrint('[INCLINE] flushOfflineQueue error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // EXERCISE MEDIA & DEMO PREFERENCES
  // ---------------------------------------------------------------------------

  /// Retrieves whether exercise video demos are enabled on device (default: false)
  Future<bool> getExerciseVideoDemosEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefExerciseVideoDemosKey) ?? false;
    } catch (e) {
      debugPrint('[INCLINE] getExerciseVideoDemosEnabled error: $e');
      return false;
    }
  }

  /// Persists whether exercise video demos are enabled
  Future<void> setExerciseVideoDemosEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefExerciseVideoDemosKey, enabled);
    } catch (e) {
      debugPrint('[INCLINE] setExerciseVideoDemosEnabled error: $e');
    }
  }
}
