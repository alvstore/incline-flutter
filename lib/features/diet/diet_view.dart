import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dumbbell_loader.dart';
import 'widgets/macro_radar_card.dart';
import 'widgets/meal_card.dart';
import 'widgets/supplements_card.dart';
import 'widgets/water_intake_card.dart';
import '../profile/member_requests_screen.dart';

/// Full Interactive Day-Wise Diet & Nutrition Plan View
class DietView extends StatefulWidget {
  final Member? member;
  final MyTrainer? trainer;
  final MemberDietPlan? initialPlan;

  const DietView({
    super.key,
    this.member,
    this.trainer,
    this.initialPlan,
  });

  @override
  State<DietView> createState() => DietViewState();
}

class DietViewState extends State<DietView> {
  MemberDietPlan? _dietPlan;
  MyTrainer? _trainer;
  bool _isLoading = true;
  int _selectedDayIndex = 0;
  int _waterIntakeMl = 0;
  String? _errorMessage;

  void reloadSilent() {
    _loadDietPlan(silent: true);
  }

  Future<void> reload({bool forceRefresh = false}) async {
    await _loadDietPlan(forceRefresh: forceRefresh);
  }

  @override
  void initState() {
    super.initState();
    _trainer = widget.trainer;
    if (widget.initialPlan != null) {
      _dietPlan = widget.initialPlan;
      _isLoading = false;
      final todayWeekday = DateTime.now().weekday;
      if (_dietPlan!.days.isNotEmpty) {
        final match = _dietPlan!.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
        _selectedDayIndex = match != -1 ? match : 0;
      }
    } else {
      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      final cachedPlan = SupabaseService.instance.getCachedDietPlan(memberId);
      final cachedWater = SupabaseService.instance.getCachedWaterIntake(memberId);
      final cachedTrainer = _trainer ?? SupabaseService.instance.getCachedAssignedTrainer();

      if (cachedPlan != null) {
        if (memberId.isNotEmpty) {
          final today = DateTime.now().toIso8601String().substring(0, 10);
          OfflineSyncService.instance.getCompletedMealIds(memberId, today).then((completed) {
            if (completed.isNotEmpty && mounted) {
              setState(() {
                for (final day in cachedPlan.days) {
                  for (final m in day.meals) {
                    if (completed.contains(m.id)) {
                      m.isCompleted = true;
                    }
                  }
                }
              });
            }
          });
        }
        _dietPlan = cachedPlan;
        _isLoading = false;
        final todayWeekday = DateTime.now().weekday;
        if (_dietPlan!.days.isNotEmpty) {
          final match = _dietPlan!.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
          _selectedDayIndex = match != -1 ? match : 0;
        }
      }
      if (cachedWater != null) {
        _waterIntakeMl = cachedWater;
      }
      if (cachedTrainer != null) {
        _trainer = cachedTrainer;
      }

      _loadDietPlan(silent: cachedPlan != null);
    }

    PushNotificationService.instance.onWaterLogged = () {
      if (mounted) {
        _loadDietPlan(silent: true);
      }
    };
  }

  @override
  void dispose() {
    if (PushNotificationService.instance.onWaterLogged != null) {
      PushNotificationService.instance.onWaterLogged = null;
    }
    super.dispose();
  }

  String _getTrainerDisplayName() {
    if (_trainer?.fullName != null && _trainer!.fullName.trim().isNotEmpty) {
      return _trainer!.fullName.startsWith('Coach')
          ? _trainer!.fullName
          : 'Coach ${_trainer!.fullName}';
    }
    return 'Incline Coaching Team';
  }

  Future<void> _loadDietPlan({bool silent = false, bool forceRefresh = false}) async {
    if (!silent && _dietPlan == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      final results = await Future.wait([
        SupabaseService.instance.fetchDietPlan(memberId, forceRefresh: forceRefresh),
        if (widget.trainer != null)
          Future.value(widget.trainer)
        else
          SupabaseService.instance.fetchAssignedTrainer(forceRefresh: forceRefresh),
        SupabaseService.instance.fetchTodayWaterIntake(memberId, forceRefresh: forceRefresh),
      ]);
      final plan = results[0] as MemberDietPlan?;
      final trainer = results[1] as MyTrainer?;
      final todayWater = results[2] as int? ?? 0;

      if (widget.initialPlan != null && !forceRefresh && plan == null) {
        // Retain initial plan in preview / widget test environments
        return;
      }

      // Pick today's weekday index by default
      final todayWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
      int initialIndex = 0;
      if (plan != null && plan.days.isNotEmpty) {
        final match = plan.days.indexWhere((d) => d.weekdayIndex == (todayWeekday % 7));
        if (match != -1) {
          initialIndex = match;
        } else if (_selectedDayIndex < plan.days.length) {
          initialIndex = _selectedDayIndex;
        } else {
          initialIndex = 0;
        }
      }

      // Restore today's completed meal IDs from persistent device storage
      if (plan != null && memberId.isNotEmpty) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final completedMealIds = await OfflineSyncService.instance.getCompletedMealIds(memberId, today);
        for (final day in plan.days) {
          for (final m in day.meals) {
            if (completedMealIds.contains(m.id)) {
              m.isCompleted = true;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _dietPlan = plan;
          _trainer = trainer;
          _selectedDayIndex = initialIndex;
          _waterIntakeMl = todayWater;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] Diet plan load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_dietPlan == null) {
            _errorMessage = 'Could not load nutrition plan. Please check connection.';
          }
        });
      }
    }
  }

  void _onToggleMeal(DietMeal meal, bool isCompleted, [int? mealIndex]) async {
    setState(() {
      meal.isCompleted = isCompleted;
      if (isCompleted) {
        meal.completedAt = DateTime.now();
      } else {
        meal.completedAt = null;
      }
    });

    final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Immediately persist to device persistent storage (private member tracking)
    await OfflineSyncService.instance.setMealCompleted(
      memberId: memberId,
      date: today,
      mealId: meal.id,
      isCompleted: isCompleted,
    );

    // 2. Also re-cache diet plan locally on disk
    if (_dietPlan != null) {
      await OfflineSyncService.instance.cacheDietPlan(_dietPlan!);
    }

    if (isCompleted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.cardElevated,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${meal.displaySlotLabel}: ${meal.name} logged! +${meal.targetCalories} kcal • ${meal.targetProtein.toInt()}g protein',
                  style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onAddWater(int deltaMl) {
    setState(() {
      _waterIntakeMl = (_waterIntakeMl + deltaMl).clamp(0, 8000);
    });

    final memberId = widget.member?.id ??
        SupabaseService.instance.cachedMember?.id ??
        SupabaseService.instance.currentUser?.id ??
        '';
    SupabaseService.instance.logWaterIntake(memberId: memberId, amountMl: deltaMl);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.cardElevated,
        content: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: InclineColors.accentOrange, size: 18),
            const SizedBox(width: 10),
            Text(
              '+$deltaMl ml logged! Total: ${(_waterIntakeMl / 1000).toStringAsFixed(1)}L',
              style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onResetWater() {
    setState(() => _waterIntakeMl = 0);
    final memberId = widget.member?.id ??
        SupabaseService.instance.cachedMember?.id ??
        SupabaseService.instance.currentUser?.id ??
        '';
    SupabaseService.instance.resetWaterIntake(memberId: memberId);
  }

  void _showAskNutritionistDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.support_agent_rounded, size: 20, color: context.brandAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask Trainer & Nutritionist',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.brandAccent),
                  ),
                  Text(
                    '${_getTrainerDisplayName()} • Incline Club',
                    style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have a question about food swaps, macros, or fasting around sauna sessions?',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Can I substitute quinoa with sweet potatoes post-squats?',
                hintStyle: GoogleFonts.outfit(color: context.textMuted, fontSize: 12),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.brandAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InclineScaleButton(
                  onTap: () => Navigator.pop(ctx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                InclineScaleButton(
                  onTap: () async {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    final curMember = widget.member ?? SupabaseService.instance.cachedMember;
                    final memberId = curMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final cardColor = context.cardElevated;
                    final brandAccent = context.brandAccent;

                    final success = await SupabaseService.instance.submitServiceRequest(
                      memberId: memberId,
                      branchId: curMember?.branchId,
                      category: 'diet',
                      title: 'Nutrition Question for ${_getTrainerDisplayName()}',
                      description: text,
                    );

                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        backgroundColor: cardColor,
                        content: Text(
                          success
                              ? 'Inquiry submitted to ${_getTrainerDisplayName()}! Expect a reply in Club Requests.'
                              : 'Failed to submit inquiry. Please try again.',
                          style: GoogleFonts.outfit(color: brandAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.brandAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Send Inquiry',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        color: context.onBrandAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: DumbbellLoader(text: 'Loading Incline Diet...'));
    }

    if (_errorMessage != null && _dietPlan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(
                'Could not retrieve nutrition plan',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDietPlan,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final plan = _dietPlan;
    final days = plan?.days ?? const <DietDayPlan>[];
    final activeDay = days.isNotEmpty
        ? days[_selectedDayIndex.clamp(0, days.length - 1)]
        : null;

    if (activeDay == null || plan == null) {
      return RefreshIndicator(
        onRefresh: () => _loadDietPlan(forceRefresh: true),
        color: AppTheme.emerald,
        child: _buildEmptyDietState(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDietPlan(forceRefresh: true),
      color: AppTheme.emerald,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (activeDay.nutritionistNote != null && activeDay.nutritionistNote!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: context.cardElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.eco_rounded, size: 14, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeDay.nutritionistNote!,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: context.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Day Selector Rail (Mon - Sun)
          Text(
            'WEEKLY NUTRITION SCHEDULE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.textMuted,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final d = days[idx];
                final isSelected = idx == _selectedDayIndex;
                final todayWeekday = DateTime.now().weekday;
                final isToday = d.weekdayIndex == (todayWeekday % 7);

                return InkWell(
                  onTap: () => setState(() => _selectedDayIndex = idx),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 78,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.brandAccent
                          : context.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? context.brandAccent
                            : (isToday ? context.brandAccent.withValues(alpha: 0.5) : context.borderCol),
                        width: isSelected || isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d.dayLabel.substring(0, 3),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? context.onBrandAccent : context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.meals.length} meals',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? context.onBrandAccent.withValues(alpha: 0.8)
                                : context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.targetCalories}k',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? context.onBrandAccent : context.brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Macro Radar Bento Card
          MacroRadarCard(dayPlan: activeDay),

          const SizedBox(height: 16),

          // Water Intake Hydration Bento Card
          WaterIntakeCard(
            currentMl: _waterIntakeMl,
            targetMl: activeDay.targetWaterMl,
            onAddWater: _onAddWater,
            onReset: _onResetWater,
          ),

          const SizedBox(height: 18),

          // Meals Timeline Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${activeDay.dayLabel.toUpperCase()} MEAL SCHEDULE',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${activeDay.completedMealsCount} of ${activeDay.meals.length} LOGGED',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: activeDay.completedMealsCount == activeDay.meals.length
                      ? AppTheme.emerald
                      : context.brandAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Itemized Meal Cards
          ...activeDay.meals.asMap().entries.map((entry) {
            final idx = entry.key;
            final meal = entry.value;
            return MealCard(
              meal: meal,
              index: idx,
              onToggleCompleted: (isCompleted) => _onToggleMeal(meal, isCompleted, idx),
            );
          }),

          const SizedBox(height: 6),

          // Supplements Protocol Bento Card
          SupplementsCard(supplements: activeDay.supplements),

          const SizedBox(height: 16),

          // Ask Nutritionist CTA Card
          InkWell(
            onTap: _showAskNutritionistDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.brandAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_rounded, size: 18, color: context.brandAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalized Nutrition Support',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Direct consultation with ${_getTrainerDisplayName()} included in Incline Membership',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.brandAccent, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildEmptyDietState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Luxury Empty State Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.cardElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.emerald.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppTheme.emerald,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.emerald,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'AWAITING NUTRITION PROTOCOL',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.emerald,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'No Nutrition Plan Assigned',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'A personalized metabolic diet plan has not been assigned to your profile yet. Request a custom plan from your coach to get tailored macro splits and meal timing.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: InclineScaleButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberRequestsScreen(
                          member: widget.member ?? SupabaseService.instance.cachedMember,
                          initialCategory: 'diet',
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, size: 16, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Request Diet Plan',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.black,
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

          const SizedBox(height: 18),

          // Daily Hydration Tracking (Available immediately for all members)
          WaterIntakeCard(
            currentMl: _waterIntakeMl,
            targetMl: 3500,
            onAddWater: _onAddWater,
            onReset: _onResetWater,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
