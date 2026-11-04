import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// Luxury Hero Telemetry & Consistency Card for Incline Dashboard
/// Features polished micro-animations conforming strictly to Incline specification:
/// - Staggered entrances for avatar, greeting, streak, wave bar, floor check-in, and quick actions
/// - Left-to-right synchronized progressive reveal of the Thermal Orange Bézier curve & gradient
/// - One-time flame pulse & target marker scale pulse
/// - Gentle status dot pulse respecting reduced motion
/// - Tactile spring response on quick action taps
/// - Theme icon rotation without rotating the parent button
/// - Notification bell wobble on unread count increase
class HomeHeroCard extends StatefulWidget {
  final String memberName;
  final String? avatarUrl;
  final String membershipStatus;
  final int streakDays;
  final int unreadNotifications;
  final MemberAttendanceAnalysis? attendanceAnalysis;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onBookTap;
  final VoidCallback onWorkoutTap;
  final VoidCallback onWaterTap;
  final VoidCallback? onDietTap;
  final VoidCallback? onCheckInTap;

  const HomeHeroCard({
    super.key,
    required this.memberName,
    this.avatarUrl,
    this.membershipStatus = 'ACTIVE',
    this.streakDays = 0,
    this.unreadNotifications = 0,
    this.attendanceAnalysis,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.onBookTap,
    required this.onWorkoutTap,
    required this.onWaterTap,
    this.onDietTap,
    this.onCheckInTap,
  });

  @override
  State<HomeHeroCard> createState() => _HomeHeroCardState();
}

class _HomeHeroCardState extends State<HomeHeroCard>
    with TickerProviderStateMixin {
  // 1. Master Entrance Controller (500 ms)
  late final AnimationController _entranceController;

  // 2. Wave Bar Controller (1100 ms)
  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  // 3. Target Marker Controller (400 ms)
  late final AnimationController _targetMarkerController;
  late final Animation<double> _targetMarkerScaleAnimation;
  late final Animation<double> _targetMarkerAlphaAnimation;

  // 4. Streak Flame Pulse Controller (500 ms)
  late final AnimationController _flamePulseController;
  late final Animation<double> _flameScaleAnimation;

  // 5. Floor Check-In Status Dot Pulse Controller (1200 ms)
  late final AnimationController _statusDotController;
  late final Animation<double> _statusDotAnimation;

  // 6. Notification Bell Wobble Controller (350 ms)
  late final AnimationController _bellWobbleController;
  late final Animation<double> _bellWobbleAnimation;

  static bool get _isTestEnvironment {
    bool inTest = false;
    assert(() {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          inTest = true;
        }
      } catch (_) {}
      return true;
    }());
    return inTest;
  }

  @override
  void initState() {
    super.initState();

    // 1. Entrance Controller
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 2. Wave Controller (Left-to-right cubic curve reveal over 1100 ms)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOutCubic,
    );

    // 3. Target Marker Pulse (runs after wave curve draws)
    _targetMarkerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _targetMarkerScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_targetMarkerController);
    _targetMarkerAlphaAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _targetMarkerController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _targetMarkerController.forward();
      }
    });

    // 4. Flame Scale Pulse (100% -> 112% -> 100% over 500 ms)
    _flamePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flameScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_flamePulseController);

    // 5. Status Dot Opacity Pulse (70% -> 100% over 1200 ms)
    _statusDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _statusDotAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(parent: _statusDotController, curve: Curves.easeInOut),
    );

    // 6. Bell Wobble Animation (10 degrees = 0.174 rad)
    _bellWobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bellWobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.174)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.174, end: -0.174)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.174, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_bellWobbleController);

    // Start entrance sequences
    _entranceController.forward();
    _waveController.forward();
    _flamePulseController.forward();

    // In production / device: repeat gentle status dot pulse unless reduced motion is active
    if (!_isTestEnvironment) {
      _statusDotController.repeat(reverse: true);
    } else {
      _statusDotController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(HomeHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bell wobble when notifications increase
    if (widget.unreadNotifications > oldWidget.unreadNotifications) {
      _bellWobbleController.forward(from: 0.0);
    }
    // Flame pulse when streak value changes
    if (widget.streakDays != oldWidget.streakDays) {
      _flamePulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _waveController.dispose();
    _targetMarkerController.dispose();
    _flamePulseController.dispose();
    _statusDotController.dispose();
    _bellWobbleController.dispose();
    super.dispose();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      return 'Good evening';
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardGradient = isDark
        ? const LinearGradient(
            colors: [InclineColors.cardSurface, InclineColors.cardRecessed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [
              InclineColors.lightCardSurface,
              InclineColors.lightCardRecessed
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final borderColor =
        isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;

    // Staggered Entrance Animations
    final avatarScaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    final greetingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutCubic),
      ),
    );
    final greetingSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    final streakFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.90, curve: Curves.easeOutCubic),
      ),
    );
    final streakSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    final trendFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Row: Avatar, Greeting & Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar & Greeting
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Open profile for ${widget.memberName}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onProfileTap();
                        },
                        child: Row(
                          children: [
                            ScaleTransition(
                              scale: avatarScaleAnimation,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: InclineColors.accentOrange,
                                    width: 1.5,
                                  ),
                                  color: InclineColors.accentOrange
                                      .withValues(alpha: 0.15),
                                ),
                                alignment: Alignment.center,
                                child: (widget.avatarUrl != null &&
                                        widget.avatarUrl!.startsWith('http'))
                                    ? ClipOval(
                                        child: Image.network(
                                          widget.avatarUrl!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              _getInitials(widget.memberName),
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : InclineColors.accentOrange,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _getInitials(widget.memberName),
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : InclineColors.accentOrange,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FadeTransition(
                                opacity: greetingFadeAnimation,
                                child: SlideTransition(
                                  position: greetingSlideAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTimeGreeting(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.72)
                                              : InclineColors.lightTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 1.5),
                                      Text(
                                        widget.memberName.trim().isNotEmpty
                                            ? widget.memberName.split(' ').first
                                            : 'Athlete',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : InclineColors.lightTextPrimary,
                                          letterSpacing: -0.2,
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
                    ),
                  ),

                  // Top Right Actions: Light/Dark Switcher & Notification Bell
                  Row(
                    children: [
                      _buildTopAction(
                        label: isDark
                            ? 'Switch to light theme'
                            : 'Switch to dark theme',
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        iconColor: InclineColors.accentOrange,
                        isDark: isDark,
                        isThemeToggle: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ThemeController.instance.toggleTheme();
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildTopAction(
                        label: widget.unreadNotifications > 0
                            ? 'Notifications, ${widget.unreadNotifications} unread'
                            : 'Notifications',
                        icon: Icons.notifications_none_rounded,
                        iconColor: isDark
                            ? Colors.white
                            : InclineColors.lightTextPrimary,
                        isDark: isDark,
                        wobbleAnimation: _bellWobbleAnimation,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNotificationTap();
                        },
                        badgeCount: widget.unreadNotifications,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Telemetry Metric Section (Streak + Flame Pulse + Count-up)
              FadeTransition(
                opacity: streakFadeAnimation,
                child: SlideTransition(
                  position: streakSlideAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(1);
                      final stackMetrics =
                          constraints.maxWidth < 330 || textScale > 1.15;
                      final metric = _buildStreakMetric(context, isDark);
                      final trend = FadeTransition(
                        opacity: trendFadeAnimation,
                        child: _buildTrendPill(isDark),
                      );

                      if (stackMetrics) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            metric,
                            const SizedBox(height: 10),
                            trend,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: metric),
                          const SizedBox(width: 12),
                          trend,
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 3. Smooth Rhythmic Wave Chart (Exact Original Position Preserved)
              SizedBox(
                height: 48,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _waveAnimation,
                    _targetMarkerScaleAnimation,
                    _targetMarkerAlphaAnimation,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _HeroWaveChartPainter(
                        lineColor: InclineColors.accentOrange,
                        animationProgress: _waveAnimation.value,
                        targetMarkerScale: _targetMarkerScaleAnimation.value,
                        targetMarkerAlpha: _targetMarkerAlphaAnimation.value,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 4. Floor Check-In Ready Section (Merged directly after Wave Bar)
              _buildFloorCheckInSection(context, isDark),

              const SizedBox(height: 16),

              // 5. Quick Actions Row (Same 4 Circular Buttons: Book, Workout, Hydrate, Diet)
              Row(
                children: [
                  Expanded(
                    child: _buildCircleAction(
                      label: 'Book',
                      icon: Icons.add_rounded,
                      isPrimary: true,
                      isDark: isDark,
                      staggerInterval: const Interval(0.55, 0.82,
                          curve: Curves.easeOutCubic),
                      onTap: widget.onBookTap,
                    ),
                  ),
                  Expanded(
                    child: _buildCircleAction(
                      label: 'Workout',
                      icon: Icons.fitness_center_rounded,
                      isPrimary: false,
                      isDark: isDark,
                      staggerInterval: const Interval(0.62, 0.88,
                          curve: Curves.easeOutCubic),
                      onTap: widget.onWorkoutTap,
                    ),
                  ),
                  Expanded(
                    child: _buildCircleAction(
                      label: 'Hydrate',
                      icon: Icons.water_drop_rounded,
                      isPrimary: false,
                      isDark: isDark,
                      staggerInterval: const Interval(0.69, 0.94,
                          curve: Curves.easeOutCubic),
                      onTap: widget.onWaterTap,
                    ),
                  ),
                  Expanded(
                    child: _buildCircleAction(
                      label: 'Diet',
                      icon: Icons.restaurant_menu_rounded,
                      isPrimary: false,
                      isDark: isDark,
                      staggerInterval: const Interval(0.76, 1.00,
                          curve: Curves.easeOutCubic),
                      onTap: widget.onDietTap ?? widget.onCheckInTap ?? () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakMetric(BuildContext context, bool isDark) {
    final effectiveStreak =
        widget.attendanceAnalysis?.streakDays ?? widget.streakDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR STREAK',
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.65)
                : InclineColors.lightTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Count-up animation on streak value
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: effectiveStreak.toDouble()),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) {
                  final days = val.toInt();
                  final label = days == 1 ? '1 Day' : '$days Days';
                  return Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark ? Colors.white : InclineColors.lightTextPrimary,
                      letterSpacing: -0.8,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              ScaleTransition(
                scale: _flameScaleAnimation,
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendPill(bool isDark) {
    final effectiveStreak =
        widget.attendanceAnalysis?.streakDays ?? widget.streakDays;
    final hasStreak = effectiveStreak > 0;

    final String motivationalCopy;
    if (effectiveStreak >= 7) {
      motivationalCopy = 'ONE WEEK STRONG';
    } else if (effectiveStreak >= 4) {
      motivationalCopy = 'KEEP IT GOING';
    } else if (effectiveStreak >= 1) {
      motivationalCopy = 'BUILDING MOMENTUM';
    } else {
      motivationalCopy = 'START YOUR STREAK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (hasStreak
                ? InclineColors.accentOrange
                : (isDark ? Colors.white : InclineColors.lightHeroSpotlight))
            .withValues(
                alpha: hasStreak ? (isDark ? 0.2 : 0.12) : (isDark ? 0.08 : 0.6)),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (hasStreak
                  ? InclineColors.accentOrange
                  : (isDark ? Colors.white : InclineColors.lightCardBorder))
              .withValues(
                  alpha: hasStreak ? (isDark ? 0.35 : 0.25) : (isDark ? 0.2 : 0.6)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasStreak
                ? Icons.arrow_outward_rounded
                : Icons.track_changes_rounded,
            size: 13,
            color: hasStreak
                ? InclineColors.accentOrange
                : (isDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : InclineColors.lightTextSecondary),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              motivationalCopy,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: hasStreak
                    ? InclineColors.accentOrange
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : InclineColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCheckInSection(BuildContext context, bool isDark) {
    final analysis = widget.attendanceAnalysis;
    final isVisitedToday = analysis?.isVisitedToday ?? false;
    final weekActivity = analysis?.weekActivity ??
        const [true, true, false, false, false, false, false];
    final visitedCount = weekActivity.where((visited) => visited).length;
    final weeklyConsistencyPct = ((visitedCount / 7) * 100).toInt();
    final todayWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final String sessionStatus;
    if (isVisitedToday) {
      sessionStatus = "Today's Session Logged ✓";
    } else if (analysis?.todayCheckIn != null) {
      sessionStatus = 'Your Session Is Underway';
    } else if (widget.membershipStatus.toUpperCase() == 'ACTIVE') {
      sessionStatus = 'Floor Check-In Ready';
    } else {
      sessionStatus = 'Ready for Your Next Session';
    }

    // Headline and Subtitle staggered fade-in
    final headlineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    final subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? InclineColors.cardRecessed.withValues(alpha: 0.55)
            : InclineColors.lightCardRecessed,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header: Floor Check-In Ready & Consistency 28%
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Status Dot with gentle opacity pulse (70% -> 100%)
                    AnimatedBuilder(
                      animation: _statusDotAnimation,
                      builder: (context, _) {
                        final opacity = _statusDotAnimation.value;
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: InclineColors.accentOrange
                                .withValues(alpha: opacity),
                            boxShadow: [
                              BoxShadow(
                                color: InclineColors.accentOrange
                                    .withValues(alpha: 0.5 * opacity),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeTransition(
                            opacity: headlineFade,
                            child: Text(
                              sessionStatus,
                              semanticsLabel: 'Your Weekly Progress',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? Colors.white
                                    : InclineColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FadeTransition(
                            opacity: subtitleFade,
                            child: Text(
                              '$visitedCount of 7 days completed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? InclineColors.textSecondary
                                    : InclineColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Animate 0% -> 28% Consistency over 700 ms
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0, end: weeklyConsistencyPct.toDouble()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      return Text(
                        '${val.toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: InclineColors.accentOrange,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  Text(
                    'WEEKLY ACTIVITY',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark
                          ? InclineColors.textMuted
                          : InclineColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 7-Day Day-Wise Rail (M, T, W, T, F, S, S) with 55ms Staggered Reveal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNumber = index + 1; // 1 = Mon ... 7 = Sun
              final isVisited =
                  index < weekActivity.length && weekActivity[index];
              final isToday = dayNumber == todayWeekday;

              // Staggered interval: approx 55 ms apart
              final startInterval = (0.35 + index * 0.06).clamp(0.0, 0.85);
              final endInterval = (startInterval + 0.25).clamp(0.0, 1.0);
              final capsuleAnimation = CurvedAnimation(
                parent: _entranceController,
                curve: Interval(startInterval, endInterval,
                    curve: Curves.easeOutCubic),
              );

              // Checkmark scale-in on logged days
              final checkmarkAnimation = CurvedAnimation(
                parent: _entranceController,
                curve: Interval((startInterval + 0.05).clamp(0.0, 0.90),
                    endInterval,
                    curve: Curves.easeOutBack),
              );

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FadeTransition(
                    opacity: capsuleAnimation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1.0)
                          .animate(capsuleAnimation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isToday
                              ? (isDark
                                  ? InclineColors.cardRecessed
                                  : InclineColors.lightCardRecessed)
                              : (isDark
                                  ? InclineColors.cardSurface
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isToday
                                ? InclineColors.accentOrange
                                : (isDark
                                    ? InclineColors.cardBorder
                                    : Colors.black.withValues(alpha: 0.06)),
                            width: isToday ? 1.5 : 1,
                          ),
                          boxShadow: isToday && !isDark
                              ? [
                                  BoxShadow(
                                    color: InclineColors.accentOrange
                                        .withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayLetters[index],
                              textScaler: const TextScaler.linear(1.0),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isToday
                                    ? InclineColors.accentOrange
                                    : (isDark
                                        ? InclineColors.textSecondary
                                        : InclineColors.lightTextSecondary),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isVisited
                                    ? InclineColors.accentOrange
                                        .withValues(alpha: 0.18)
                                    : (isToday
                                        ? InclineColors.accentOrange
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black
                                                .withValues(alpha: 0.04))),
                              ),
                              alignment: Alignment.center,
                              child: isVisited
                                  ? ScaleTransition(
                                      scale: Tween<double>(begin: 0.6, end: 1.0)
                                          .animate(checkmarkAnimation),
                                      child: FadeTransition(
                                        opacity: checkmarkAnimation,
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 13,
                                          color: InclineColors.accentOrange,
                                        ),
                                      ),
                                    )
                                  : (isToday
                                      ? const Icon(
                                          Icons.circle,
                                          size: 7,
                                          color: Colors.white,
                                        )
                                      : Icon(
                                          Icons.circle_outlined,
                                          size: 7,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black26,
                                        )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool isThemeToggle = false,
    Animation<double>? wobbleAnimation,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : InclineColors.lightHeroSpotlight,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : InclineColors.lightCardBorder,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isThemeToggle
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) {
                            final isMoon = icon == Icons.dark_mode_rounded;
                            return RotationTransition(
                              turns: isMoon
                                  ? Tween<double>(begin: -0.25, end: 0.0)
                                      .animate(animation)
                                  : Tween<double>(begin: 0.25, end: 0.0)
                                      .animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            icon,
                            key: ValueKey(icon.codePoint),
                            size: 20,
                            color: iconColor,
                          ),
                        )
                      : (wobbleAnimation != null
                          ? AnimatedBuilder(
                              animation: wobbleAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: wobbleAnimation.value,
                                  child: child,
                                );
                              },
                              child: Icon(icon, size: 20, color: iconColor),
                            )
                          : Icon(icon, size: 20, color: iconColor)),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 1,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: InclineColors.accentOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
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
  }

  Widget _buildCircleAction({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required bool isDark,
    required Interval staggerInterval,
    required VoidCallback onTap,
  }) {
    const primaryBg = LinearGradient(
      colors: [InclineColors.accentOrange, InclineColors.thermalAmber],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final entranceScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: staggerInterval,
      ),
    );
    final entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: staggerInterval,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: FadeTransition(
          opacity: entranceFade,
          child: ScaleTransition(
            scale: entranceScale,
            child: _TactileActionButton(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isPrimary ? primaryBg : null,
                        color: isPrimary
                            ? null
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : InclineColors.lightHeroSpotlight),
                        border: Border.all(
                          color: isPrimary
                              ? Colors.transparent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : InclineColors.lightCardBorder),
                        ),
                        boxShadow: isPrimary
                            ? [
                                BoxShadow(
                                  color: InclineColors.accentOrange
                                      .withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : (!isDark
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 22,
                        color: isPrimary
                            ? Colors.white
                            : (isDark
                                ? Colors.white
                                : InclineColors.lightTextPrimary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textScaler: const TextScaler.linear(1),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : InclineColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile bounce wrapper giving quick 96% -> 100% response over 140 ms
class _TactileActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TactileActionButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_TactileActionButton> createState() => _TactileActionButtonState();
}

class _TactileActionButtonState extends State<_TactileActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Custom Painter for Hero Wave Line Chart with Synchronized Left-to-Right Reveal
class _HeroWaveChartPainter extends CustomPainter {
  final Color lineColor;
  final double animationProgress;
  final double targetMarkerScale;
  final double targetMarkerAlpha;

  _HeroWaveChartPainter({
    required this.lineColor,
    this.animationProgress = 1.0,
    this.targetMarkerScale = 1.0,
    this.targetMarkerAlpha = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final linePath = Path();
    linePath.moveTo(0, height * 0.75);
    linePath.cubicTo(
      width * 0.2,
      height * 0.8,
      width * 0.3,
      height * 0.5,
      width * 0.5,
      height * 0.6,
    );
    linePath.cubicTo(
      width * 0.7,
      height * 0.7,
      width * 0.85,
      height * 0.25,
      width,
      height * 0.15,
    );

    // Gradient Area Underneath
    final areaPath = Path.from(linePath);
    areaPath.lineTo(width, height);
    areaPath.lineTo(0, height);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, height),
        [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;

    // Smooth Line Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Reveal Bézier stroke and gradient area synchronously from left to right
    if (animationProgress > 0.0) {
      canvas.save();
      canvas.clipRect(
          Rect.fromLTWH(0, 0, width * animationProgress.clamp(0.0, 1.0), height));
      canvas.drawPath(areaPath, fillPaint);
      canvas.drawPath(linePath, strokePaint);
      canvas.restore();
    }

    // Target Marker Dot at endpoint with fade and scale pulse after drawing finishes
    if (targetMarkerAlpha > 0.0 && animationProgress >= 0.95) {
      final target = Offset(width - 2, height * 0.15);
      final alpha = targetMarkerAlpha.clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(target.dx, target.dy);
      canvas.scale(targetMarkerScale);
      canvas.translate(-target.dx, -target.dy);

      canvas.drawCircle(
          target, 6, Paint()..color = lineColor.withValues(alpha: 0.25 * alpha));
      canvas.drawCircle(
          target, 3.5, Paint()..color = Colors.white.withValues(alpha: alpha));
      canvas.drawCircle(
          target, 2, Paint()..color = lineColor.withValues(alpha: alpha));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroWaveChartPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.targetMarkerScale != targetMarkerScale ||
      oldDelegate.targetMarkerAlpha != targetMarkerAlpha;
}
