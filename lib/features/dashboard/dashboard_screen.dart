import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/env_config.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';
import '../notifications/notifications_screen.dart';
import '../profile/feedback_screen.dart';
import '../profile/member_requests_screen.dart';
import '../workout/workout_execution_sheet.dart';

/// Luxury Material 3 Bento Dashboard for Incline Members
/// Re-thought with Interactive Streak Bento, Class Shortcuts, and Club Bulletins
class DashboardScreen extends StatefulWidget {
  final Member? member;
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.member,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Membership? _membership;
  WorkoutPlan? _workoutPlan;
  MemberDietPlan? _dietPlan;
  StreakData? _streakData;
  MyTrainer? _assignedTrainer;
  MemberPtPackage? _ptPackage;
  int _pendingRequestsCount = 0;
  List<GymClass> _todayClasses = [];
  List<GymNotification> _notifications = [];
  int _activeNotificationIndex = 0;
  bool _simulateExpiringAlert = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
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

      if (mounted) {
        setState(() {
          _membership = results[0] as Membership?;
          _workoutPlan = results[1] as WorkoutPlan?;
          _streakData = results[2] as StreakData?;
          _todayClasses = results[3] as List<GymClass>;
          _notifications = results[4] as List<GymNotification>;
          _dietPlan = results[5] as MemberDietPlan?;
          _assignedTrainer = results[6] as MyTrainer?;
          final requests = results[7] as List<MemberRequest>;
          _pendingRequestsCount = requests.where((r) => r.isPending).length;
          _ptPackage = results[8] as MemberPtPackage?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to refresh dashboard telemetry: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openTodayWorkout() {
    if (_workoutPlan == null || _workoutPlan!.days.isEmpty) return;
    final todayWeekday = DateTime.now().weekday;
    final match = _workoutPlan!.days.firstWhere(
      (d) => d.weekdayIndex == (todayWeekday % 7),
      orElse: () => _workoutPlan!.days.first,
    );

    if (match.isRest || match.exercises.isEmpty) {
      widget.onNavigateTab?.call(1); // Go to Bookings
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => WorkoutExecutionSheet(
          day: match,
          initialExerciseIndex: 0,
          onExerciseUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NotificationsScreen(
          onNavigateToBookings: () => widget.onNavigateTab?.call(1),
          onNavigateToWorkout: () => widget.onNavigateTab?.call(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.member?.profile?.fullName ??
        SupabaseService.instance.cachedMember?.profile?.fullName ??
        'Member';
    final membership = _membership;
    final streak = _streakData ?? const StreakData(
      currentStreak: 0,
      bestStreak: 0,
      monthlyVisits: 0,
      weekActivity: [false, false, false, false, false, false, false],
      nextMilestone: 'Check-in to start streak',
      milestoneProgress: 0.0,
    );
    final todayDay = (_workoutPlan != null && _workoutPlan!.days.isNotEmpty)
        ? _workoutPlan!.days.firstWhere(
            (d) => d.weekdayIndex == (DateTime.now().weekday % 7),
            orElse: () => _workoutPlan!.days.first,
          )
        : null;
    final todayDiet = (_dietPlan != null && _dietPlan!.days.isNotEmpty)
        ? _dietPlan!.days.firstWhere(
            (d) => d.weekdayIndex == (DateTime.now().weekday % 7),
            orElse: () => _dietPlan!.days.first,
          )
        : null;
    final unreadNotifs = _notifications.where((n) => !n.isRead).length;
    final featuredClass = _todayClasses.isNotEmpty ? _todayClasses.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/incline_logo.png',
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.fitness_center_rounded,
                color: AppTheme.gold,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EnvConfig.appName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.gold,
                  ),
                ),
                Text(
                  EnvConfig.tagline,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Notification Bell with unread badge counter
          IconButton(
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppTheme.gold, size: 24),
                if (unreadNotifs > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.rose,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$unreadNotifs',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Gold Tier Badge
          Container(
            margin: const EdgeInsets.only(right: 16, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                const SizedBox(width: 4),
                Text(
                  'GOLD TIER',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppTheme.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: DumbbellLoader(
                  text: 'Syncing Member Telemetry...',
                  size: DumbbellLoaderSize.md,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
          color: AppTheme.gold,
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Member Greeting Bento Card
                BentoCard(
                  asymmetricCorners: true,
                  backgroundColor: AppTheme.surfaceElevated,
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3), width: 1.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTimeBasedGreeting(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  memberName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.gold, width: 1.5),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/avatar_placeholder.jpg',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.gold,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Membership expiry status
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _simulateExpiringAlert = !_simulateExpiringAlert;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          membership?.planName ?? 'No Active Membership',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_simulateExpiringAlert || (membership?.daysRemaining ?? 0) <= 30)
                                        ? AppTheme.amber.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _simulateExpiringAlert
                                        ? '12d left ⚠️'
                                        : membership == null ? 'Inactive' : '${membership.daysRemaining}d left',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: (_simulateExpiringAlert || (membership?.daysRemaining ?? 0) <= 30)
                                          ? AppTheme.amber
                                          : AppTheme.gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 1b. Expiring Membership Alert Banner (Contextual, Elevated <= 30 days)
                _buildExpiringMembershipBanner(membership),

                const SizedBox(height: 16),

                // 2. HERO BENTO: 14-Day Streak & Consistency Hub (Adopted per request)
                _buildConsistencyStreakBento(streak),

                const SizedBox(height: 16),

                // 2b. HERO BENTO: Dedicated Coach / Personal Trainer (Assigned vs Request)
                _buildTrainerBentoCard(),

                const SizedBox(height: 16),

                // 3. Today's Assigned Workout Bento Card
                if (todayDay != null)
                  BentoCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: AppTheme.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.fitness_center_rounded, color: AppTheme.gold, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TODAY\'S WORKOUT SPLIT',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: AppTheme.gold,
                                          ),
                                        ),
                                        Text(
                                          todayDay.dayLabel,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _openTodayWorkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.gold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'Start Workout',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${todayDay.focus} • ${todayDay.exercises.length} Exercises (~25 min)',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  BentoCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.surfaceElevated,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fitness_center_rounded, color: AppTheme.gold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WORKOUT SPLIT',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                    Text(
                                      'No Routine Assigned',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Awaiting Coach Programming',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => widget.onNavigateTab?.call(2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceHighlight,
                            foregroundColor: AppTheme.gold,
                            side: const BorderSide(color: AppTheme.gold),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Request Routine',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // 3b. Today's Assigned Nutrition & Fuel Bento Card
                if (todayDiet != null)
                  BentoCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: AppTheme.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.emerald, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TODAY\'S NUTRITION & FUEL',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: AppTheme.emerald,
                                          ),
                                        ),
                                        Text(
                                          '${todayDiet.dayLabel} • Clean Fuel',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => widget.onNavigateTab?.call(2),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.surfaceHighlight,
                                foregroundColor: AppTheme.gold,
                                side: const BorderSide(color: AppTheme.gold),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'View Diet Plan',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target: ${todayDiet.targetCalories} kcal • ${todayDiet.targetProtein.toInt()}g Protein',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${todayDiet.completedMealsCount}/${todayDiet.meals.length} Logged',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  BentoCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.surfaceElevated,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.emerald, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NUTRITION & FUEL',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                    Text(
                                      'No Diet Plan Assigned',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Awaiting Macro Protocol',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => widget.onNavigateTab?.call(2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceHighlight,
                            foregroundColor: AppTheme.emerald,
                            side: const BorderSide(color: AppTheme.emerald),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Request Diet',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // 4. Quick Shortcuts: Studio Classes & Contrast Therapy
                Row(
                  children: [
                    // Studio Class Card
                    Expanded(
                      child: BentoCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppTheme.surfaceElevated,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sky.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.self_improvement_rounded, color: AppTheme.sky, size: 18),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    featuredClass != null ? '${featuredClass.spotsRemaining} OPEN' : 'STUDIO',
                                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              featuredClass?.title ?? 'Studio Schedule',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              featuredClass != null ? '${featuredClass.startTime} • Studio A' : 'Incline Studio',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => widget.onNavigateTab?.call(1),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.sky,
                                  side: BorderSide(color: AppTheme.sky.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Book Class', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Contrast Therapy Suite Card
                    Expanded(
                      child: BentoCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppTheme.surfaceElevated,
                        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.hot_tub_rounded, color: AppTheme.emerald, size: 18),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FREE',
                                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Steam Suite',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Private Suite • Free',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => widget.onNavigateTab?.call(1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.emerald,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Reserve Free', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 5. Incline Club Notifications & Daily Reminders Hub
                _buildHomeNotificationsHub(),

                const SizedBox(height: 16),

                // 5b. Desk Requests & Club Feedback Hub (Aligned with Web Portal)
                _buildDeskRequestsAndFeedbackHub(),

                const SizedBox(height: 20),

                // 6. Quick Action Navigation Grid (2x2)
                Text(
                  'QUICK ACTIONS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _bentoActionCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Book Classes & Suites',
                        subtitle: 'Steam, Yoga, Pilates',
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bentoActionCard(
                        icon: Icons.fitness_center_rounded,
                        title: 'Workout Split',
                        subtitle: 'Weekly routine & sync',
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _bentoActionCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Member Store',
                        subtitle: 'Packs, nutrition, gear',
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bentoActionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'My Profile',
                        subtitle: 'Attendance & session',
                        onTap: () => widget.onNavigateTab?.call(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Dashboard Sync Notice',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to Incline telemetry servers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry Connection',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyStreakBento(StreakData streak) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

    return BentoCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: AppTheme.surfaceElevated,
      border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35), width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.amber, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCLINE STREAK',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppTheme.amber,
                            ),
                          ),
                          Text(
                            '${streak.currentStreak} Days Consecutive',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'Top 5% Member',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 7-Day Day-by-Day Visualizer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (idx) {
                final dayNum = idx + 1;
                final isDone = streak.weekActivity[idx];
                final isToday = dayNum == todayWeekday;

                return Column(
                  children: [
                    Text(
                      days[idx],
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isToday ? AppTheme.gold : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppTheme.amber
                            : (isToday ? AppTheme.surfaceElevated : Colors.transparent),
                        border: Border.all(
                          color: isDone
                              ? AppTheme.amber
                              : (isToday ? AppTheme.gold : AppTheme.border),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                            : (isToday
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.gold,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 14),

          // Milestone Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: ${streak.nextMilestone}',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              Text(
                '${(streak.milestoneProgress * 100).toInt()}%',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: streak.milestoneProgress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceHighlight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.amber),
            ),
          ),

          const SizedBox(height: 12),

          // Sub-stats (Best Streak, Monthly Visits)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Best Streak: ${streak.bestStreak}d • ${streak.monthlyVisits} Visits This Month',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rise. Reflect. Repeat.',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.gold.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppTheme.surfaceElevated,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerBentoCard() {
    final trainer = _assignedTrainer;
    final hasTrainer = trainer != null;

    return BentoCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: AppTheme.surfaceElevated,
      border: Border.all(
        color: hasTrainer ? AppTheme.gold.withValues(alpha: 0.35) : AppTheme.border,
        width: 1.2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, color: AppTheme.gold, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MY DEDICATED COACH',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasTrainer ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasTrainer ? '1-ON-1 ACTIVE' : 'UNASSIGNED',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: hasTrainer ? AppTheme.emerald : AppTheme.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (hasTrainer) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.surfaceHighlight,
                    backgroundImage: (trainer.avatarUrl != null && trainer.avatarUrl!.isNotEmpty)
                        ? NetworkImage(trainer.avatarUrl!)
                        : null,
                    child: (trainer.avatarUrl == null || trainer.avatarUrl!.isEmpty)
                        ? Text(
                            trainer.fullName.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.gold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Lead Strength & Conditioning Coach',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gold,
                        ),
                      ),
                      if (trainer.trainerCode != null)
                        Text(
                          'Coach ID: ${trainer.trainerCode}',
                          style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberRequestsScreen(
                          member: widget.member,
                          initialCategory: 'trainer_change',
                        ),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Consult',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (trainer.specializations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: trainer.specializations.take(4).map((spec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      spec,
                      style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ],

            // ---------------------------------------------------------------
            // PT SESSION QUOTA & VISUAL PROGRESS TRACKER
            // ---------------------------------------------------------------
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 14, color: AppTheme.gold),
                          const SizedBox(width: 6),
                          Text(
                            'PT QUOTA',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppTheme.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_ptPackage?.completedSessions ?? 12}/${_ptPackage?.sessionsTotal ?? 16} Sessions Completed',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _ptPackage?.progressRate ?? (12 / 16),
                      minHeight: 8,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_ptPackage?.sessionsRemaining ?? 4} Remaining',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Valid Until 28 Dec 2026',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // DIRECT ACTION BUTTONS: Schedule Next Session & Top-Up
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSchedulePtSessionSheet(context),
                    icon: const Icon(Icons.calendar_today_rounded, size: 15),
                    label: Text(
                      'Schedule Next Session',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showPurchasePtModal(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Top-Up',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.gold, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Personal Trainer Assigned',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accelerate your transformation with tailored periodised programming and dedicated accountability.',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberRequestsScreen(
                            member: widget.member,
                            initialCategory: 'trainer_change',
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 16),
                    label: Text(
                      'Request Trainer',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showPurchasePtModal(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Buy PT Pack',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Elevated Expiring Membership Warning Banner
  Widget _buildExpiringMembershipBanner(Membership? membership) {
    final daysRemaining = _simulateExpiringAlert ? 12 : (membership?.daysRemaining ?? 0);
    final isExpiringSoon = daysRemaining <= 30;

    if (!isExpiringSoon) return const SizedBox.shrink();

    return BentoCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppTheme.surfaceElevated,
      border: Border.all(color: AppTheme.amber.withValues(alpha: 0.6), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMBERSHIP EXPIRING SOON',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppTheme.amber,
                      ),
                    ),
                    Text(
                      'Only $daysRemaining Days Left • Renewal Required',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                onPressed: () => setState(() => _simulateExpiringAlert = false),
                tooltip: 'Dismiss alert preview',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Renew now to maintain uninterrupted Turnstile Access, Steam Suite privileges, and protect your consistency streak.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRazorpayRenewalModal(context, membership),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(
                'Instant Razorpay Renewal • 10% Loyalty Off',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Schedule PT Session Bottom Sheet
  void _showSchedulePtSessionSheet(BuildContext context) {
    String selectedDay = 'Tomorrow (Thursday)';
    String selectedTime = '07:00 AM';
    String selectedFocus = 'Chest & Upper Hypertrophy';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.surfaceHighlight,
                          backgroundImage: (_assignedTrainer?.avatarUrl != null && _assignedTrainer!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(_assignedTrainer!.avatarUrl!)
                              : null,
                          child: (_assignedTrainer?.avatarUrl == null || _assignedTrainer!.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: AppTheme.gold)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Schedule 1-on-1 PT Session',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '${_assignedTrainer?.fullName ?? 'Dedicated Coach'} • ${_ptPackage?.sessionsRemaining ?? 0} Sessions Left',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.gold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date Picker Chips
                    Text(
                      'SELECT DATE',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Today', 'Tomorrow (Thursday)', 'Friday', 'Saturday'].map((day) {
                        final isSel = selectedDay == day;
                        return ChoiceChip(
                          label: Text(day, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.black : AppTheme.textPrimary)),
                          selected: isSel,
                          selectedColor: AppTheme.gold,
                          backgroundColor: AppTheme.surfaceHighlight,
                          onSelected: (_) => setSheetState(() => selectedDay = day),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Time Slot Picker
                    Text(
                      'PREFERRED TIME SLOT',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['07:00 AM', '08:30 AM', '10:00 AM', '05:30 PM', '06:45 PM', '08:00 PM'].map((slot) {
                        final isSel = selectedTime == slot;
                        return ChoiceChip(
                          label: Text(slot, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.black : AppTheme.textPrimary)),
                          selected: isSel,
                          selectedColor: AppTheme.gold,
                          backgroundColor: AppTheme.surfaceHighlight,
                          onSelected: (_) => setSheetState(() => selectedTime = slot),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Focus Area Picker
                    Text(
                      'SESSION BIOMECHANICAL FOCUS',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Chest & Upper Hypertrophy',
                        'Squat Depth & Biomechanics',
                        'Posterior Chain & RDL Form',
                        'Active Mobility & Recovery',
                      ].map((focus) {
                        final isSel = selectedFocus == focus;
                        return ChoiceChip(
                          label: Text(focus, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.black : AppTheme.textPrimary)),
                          selected: isSel,
                          selectedColor: AppTheme.gold,
                          backgroundColor: AppTheme.surfaceHighlight,
                          onSelected: (_) => setSheetState(() => selectedFocus = focus),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Special Notes Input
                    TextField(
                      controller: notesController,
                      style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Notes for ${_assignedTrainer?.fullName ?? 'Coach'} (e.g. shoulder warmup)',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceHighlight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm Booking Action
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
                          final coachName = _assignedTrainer?.fullName ?? 'Dedicated Coach';
                          await SupabaseService.instance.schedulePtSession(
                            memberId: memberId,
                            scheduledAt: DateTime.now().add(const Duration(days: 1)),
                            focus: selectedFocus,
                            trainerName: coachName,
                            notes: notesController.text,
                          );

                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.emerald,
                              content: Text(
                                '✅ PT Session Confirmed with $coachName on $selectedDay at $selectedTime!',
                                style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                          _loadDashboardData();
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          'Confirm 1-on-1 Session Booking',
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Purchase / Top-Up PT Package Modal
  void _showPurchasePtModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Personal Training Session Packs',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              Text(
                '1-on-1 private coaching with Incline Certified Coaches',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              // 16 Sessions Pack (Recommended)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.gold, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('16 Session Transformation Pack', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(4)),
                              child: Text('BEST VALUE', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black)),
                            ),
                          ],
                        ),
                        Text('₹1,375 / session • 60-day validity', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    Text('₹22,000', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.gold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.gold,
                        content: Text(
                          'Payment initiated via Razorpay Live Gateway (₹22,000). Sessions credited!',
                          style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: Text('Purchase via Razorpay / UPI (₹22,000)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Instant Razorpay Renewal Modal for Expiring Membership
  void _showRazorpayRenewalModal(BuildContext context, Membership? membership) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Membership Renewal',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Razorpay Secure 256-Bit Gateway',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.gold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('10% OFF', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Membership Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Plan Renewal:', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(membership?.planName ?? 'Active Plan', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Term Extension:', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('+365 Days (Full Year)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Standard Fee:', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
                        Text('₹38,888', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                    const Divider(height: 16, color: AppTheme.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Final Payable (Incl. GST):', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('₹34,999', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.gold)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Privileges Retained
              Text(
                'PRIVILEGES RETAINED WITH RENEWAL',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Text('• Uninterrupted Smart Gate & Turnstile Token', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
              Text('• Unlimited Steam Suite & Contrast Suite Bookings', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
              Text('• Incline Streak Preservation & Gold Trophy Progress', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _simulateExpiringAlert = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.emerald,
                        content: Text(
                          '🎉 Razorpay Payment of ₹34,999 Successful! Membership extended by 365 days.',
                          style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: Text('Pay ₹34,999 via UPI / Card', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeNotificationsHub() {
    if (_notifications.isEmpty) return const SizedBox.shrink();

    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final activeIndex = _activeNotificationIndex.clamp(0, _notifications.length - 1);
    final activeNotif = _notifications[activeIndex];

    Color notifColor;
    IconData notifIcon;
    String categoryLabel;

    switch (activeNotif.type) {
      case 'reminder':
        notifColor = Colors.orange;
        notifIcon = Icons.alarm_rounded;
        categoryLabel = 'SESSION REMINDER';
        break;
      case 'motivation':
        notifColor = AppTheme.gold;
        notifIcon = Icons.format_quote_rounded;
        categoryLabel = 'DAILY MOTIVATION';
        break;
      case 'booking':
        notifColor = AppTheme.emerald;
        notifIcon = Icons.check_circle_rounded;
        categoryLabel = 'BOOKING CONFIRMED';
        break;
      case 'streak':
        notifColor = AppTheme.amber;
        notifIcon = Icons.local_fire_department_rounded;
        categoryLabel = 'STREAK STATUS';
        break;
      default:
        notifColor = context.brandAccent;
        notifIcon = Icons.campaign_rounded;
        categoryLabel = 'CLUB BULLETIN';
        break;
    }

    return GestureDetector(
      onTap: _openNotifications,
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: context.cardElevated,
        border: Border.all(
          color: notifColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category Badge + Icon + Unread Pill / View All
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notifColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notifIcon, color: notifColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        activeNotif.badge ?? categoryLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: notifColor,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: notifColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$unreadCount NEW',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: notifColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Bulletins',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: context.textMuted, size: 11),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Notification Title
            Text(
              activeNotif.title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Notification Message (styled gracefully with quote if motivation)
            Text(
              activeNotif.message,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: activeNotif.type == 'motivation' ? context.textPrimary : context.textSecondary,
                fontStyle: activeNotif.type == 'motivation' ? FontStyle.italic : FontStyle.normal,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Navigation / Action Buttons if present
            if (activeNotif.actionLabel != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      if (activeNotif.type == 'booking') {
                        widget.onNavigateTab?.call(1); // Bookings
                      } else if (activeNotif.type == 'reminder' || activeNotif.type == 'workout' || activeNotif.type == 'motivation') {
                        widget.onNavigateTab?.call(2); // Workout
                      } else {
                        _openNotifications();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: notifColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: notifColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeNotif.actionLabel!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: notifColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: notifColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // If multiple notifications exist, provide quick carousel switcher dots
            if (_notifications.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _notifications.length.clamp(0, 5),
                  (i) => GestureDetector(
                    onTap: () => setState(() => _activeNotificationIndex = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _activeNotificationIndex == i ? 16 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _activeNotificationIndex == i
                            ? notifColor
                            : context.borderCol,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeskRequestsAndFeedbackHub() {
    return Row(
      children: [
        // Desk Requests Bento
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberRequestsScreen(member: widget.member),
                ),
              ).then((_) => _loadDashboardData());
            },
            child: BentoCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surfaceElevated,
              border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppTheme.cyan, size: 18),
                      ),
                      if (_pendingRequestsCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$_pendingRequestsCount PENDING',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.amber),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Service Requests',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track & raise desk inquiries',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Club Feedback Bento
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FeedbackScreen(member: widget.member),
                ),
              );
            },
            child: BentoCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surfaceElevated,
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.star_outline_rounded, color: AppTheme.amber, size: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'VOICE',
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.gold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Member Feedback',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Share ratings & reviews',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING,';
    if (hour < 17) return 'GOOD AFTERNOON,';
    return 'GOOD EVENING,';
  }
}
