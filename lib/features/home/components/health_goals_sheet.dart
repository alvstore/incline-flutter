import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/watch_sync_service.dart';
import '../../../core/theme/app_theme.dart';

/// Material 3 Health Goals & Sleep Customization Sheet
/// Allows members to customize their daily targets for steps, active calories,
/// sleep, and workout duration, or manually log off-wrist sleep.
class HealthGoalsSheet extends StatefulWidget {
  const HealthGoalsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HealthGoalsSheet(),
    );
  }

  @override
  State<HealthGoalsSheet> createState() => _HealthGoalsSheetState();
}

class _HealthGoalsSheetState extends State<HealthGoalsSheet> {
  late int _stepGoal;
  late int _calorieGoal;
  late double _sleepGoal;
  late int _workoutGoal;

  double _manualSleepHours = 7.5;
  bool _isSaving = false;
  bool _isWearableConnected = false;

  @override
  void initState() {
    super.initState();
    final d = WatchSyncService.instance.data;
    _stepGoal = d.goalSteps;
    _calorieGoal = d.goalCalories;
    _sleepGoal = d.goalSleepHours;
    _workoutGoal = d.goalWorkoutMinutes;
    _manualSleepHours = d.sleepHours > 0 ? d.sleepHours : 7.5;
    _isWearableConnected = d.isConnected;
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    await WatchSyncService.instance.updateGoals(
      steps: _stepGoal,
      calories: _calorieGoal,
      sleepHours: _sleepGoal,
      workoutMinutes: _workoutGoal,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: InclineColors.accentOrange, size: 20),
              SizedBox(width: 10),
              Text('Health targets updated successfully!'),
            ],
          ),
          backgroundColor: InclineColors.cardSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _logManualSleep() async {
    HapticFeedback.lightImpact();
    await WatchSyncService.instance.logSleep(hours: _manualSleepHours);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: InclineColors.thermalAmber, size: 20),
              const SizedBox(width: 10),
              Text('Logged ${_manualSleepHours.toStringAsFixed(1)} hrs sleep for today!'),
            ],
          ),
          backgroundColor: InclineColors.cardSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: InclineColors.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: InclineColors.accentOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Targets & Goals',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Calibrate your personal health benchmarks',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),

            // Content Scroll
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                shrinkWrap: true,
                children: [
                  // 1. Step Target
                  _buildGoalCard(
                    title: 'DAILY STEP TARGET',
                    valueDisplay: '$_stepGoal steps',
                    icon: Icons.directions_walk_rounded,
                    accentColor: InclineColors.thermalAmber,
                    child: Column(
                      children: [
                        Slider(
                          value: _stepGoal.toDouble(),
                          min: 4000,
                          max: 25000,
                          divisions: 42,
                          activeColor: InclineColors.thermalAmber,
                          onChanged: (val) {
                            setState(() => _stepGoal = (val / 500).round() * 500);
                          },
                        ),
                        _buildPresetRow(
                          presets: const [6000, 8000, 10000, 12000, 15000],
                          formatter: (val) => '${val ~/ 1000}k',
                          current: _stepGoal,
                          onSelect: (val) => setState(() => _stepGoal = val),
                          accentColor: InclineColors.thermalAmber,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Active Calories Target
                  _buildGoalCard(
                    title: 'ACTIVE CALORIES BURN',
                    valueDisplay: '$_calorieGoal kcal',
                    icon: Icons.local_fire_department_rounded,
                    accentColor: InclineColors.accentOrange,
                    child: Column(
                      children: [
                        Slider(
                          value: _calorieGoal.toDouble(),
                          min: 300,
                          max: 1800,
                          divisions: 30,
                          activeColor: InclineColors.accentOrange,
                          onChanged: (val) {
                            setState(() => _calorieGoal = (val / 50).round() * 50);
                          },
                        ),
                        _buildPresetRow(
                          presets: const [500, 650, 750, 900, 1200],
                          formatter: (val) => '$val',
                          current: _calorieGoal,
                          onSelect: (val) => setState(() => _calorieGoal = val),
                          accentColor: InclineColors.accentOrange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Sleep Hours Target
                  _buildGoalCard(
                    title: 'REST & SLEEP TARGET',
                    valueDisplay: '${_sleepGoal.toStringAsFixed(1)} hrs',
                    icon: Icons.nightlight_round,
                    accentColor: InclineColors.thermalRed,
                    child: Column(
                      children: [
                        Slider(
                          value: _sleepGoal,
                          min: 6.0,
                          max: 10.0,
                          divisions: 8,
                          activeColor: InclineColors.thermalRed,
                          onChanged: (val) {
                            setState(() => _sleepGoal = (val * 2).round() / 2);
                          },
                        ),
                        _buildPresetRow<double>(
                          presets: const [7.0, 7.5, 8.0, 8.5, 9.0],
                          formatter: (val) => '${val.toStringAsFixed(1)}h',
                          current: _sleepGoal,
                          onSelect: (val) => setState(() => _sleepGoal = val),
                          accentColor: InclineColors.thermalRed,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Workout Duration Target
                  _buildGoalCard(
                    title: 'DAILY WORKOUT TIME',
                    valueDisplay: '$_workoutGoal min',
                    icon: Icons.timer_outlined,
                    accentColor: InclineColors.accentOrange,
                    child: Column(
                      children: [
                        Slider(
                          value: _workoutGoal.toDouble(),
                          min: 20,
                          max: 120,
                          divisions: 20,
                          activeColor: InclineColors.accentOrange,
                          onChanged: (val) {
                            setState(() => _workoutGoal = (val / 5).round() * 5);
                          },
                        ),
                        _buildPresetRow(
                          presets: const [30, 45, 60, 75, 90],
                          formatter: (val) => '${val}m',
                          current: _workoutGoal,
                          onSelect: (val) => setState(() => _workoutGoal = val),
                          accentColor: InclineColors.accentOrange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Manual Sleep Logger (for off-wrist nights)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: InclineColors.thermalAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bedtime_rounded, color: InclineColors.thermalAmber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'LOG LAST NIGHT\'S SLEEP',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: InclineColors.thermalAmber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Wore watch off-wrist? Enter your approximate sleep duration:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                if (_manualSleepHours > 3.0) {
                                  setState(() => _manualSleepHours -= 0.5);
                                }
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '${_manualSleepHours.toStringAsFixed(1)} Hours',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                if (_manualSleepHours < 14.0) {
                                  setState(() => _manualSleepHours += 0.5);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            InclineScaleButton(
                              onTap: _logManualSleep,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: InclineColors.thermalAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Log Sleep',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: InclineColors.thermalAmber,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Wearable Integration Link Switch
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WEARABLE SENSOR SYNC',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: InclineColors.accentOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isWearableConnected
                                    ? 'Connected to ${WatchSyncService.instance.watchBrand}'
                                    : 'Connect to sync live heart rate & pedometer',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isWearableConnected,
                          activeColor: InclineColors.accentOrange,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            setState(() => _isWearableConnected = val);
                            await WatchSyncService.instance.setWearableConnected(val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: InclineScaleButton(
                      onTap: _isSaving ? null : _saveGoals,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: InclineColors.accentOrange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: InclineColors.textPrimary),
                              )
                            : Text(
                                'Save Target Preferences',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: InclineColors.textPrimary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String title,
    required String valueDisplay,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
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
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                valueDisplay,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildPresetRow<T>({
    required List<T> presets,
    required String Function(T) formatter,
    required T current,
    required void Function(T) onSelect,
    required Color accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: presets.map((p) {
        final isSelected = p == current;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(p);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? accentColor.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              formatter(p),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
