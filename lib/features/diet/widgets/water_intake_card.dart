import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bento_card.dart';

/// Interactive Hydration & Water Intake Tracker Bento Card
/// Supports quick logging, daily progress visualizer, and push notification reminders.
class WaterIntakeCard extends StatefulWidget {
  final int currentMl;
  final int targetMl;
  final Function(int deltaMl) onAddWater;
  final VoidCallback onReset;

  const WaterIntakeCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.onAddWater,
    required this.onReset,
  });

  @override
  State<WaterIntakeCard> createState() => _WaterIntakeCardState();
}

class _WaterIntakeCardState extends State<WaterIntakeCard> {
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    final enabled = await PushNotificationService.instance.isHydrationRemindersEnabled();
    if (mounted) {
      setState(() => _remindersEnabled = enabled);
    }
  }

  Future<void> _toggleReminders(bool val) async {
    setState(() => _remindersEnabled = val);
    await PushNotificationService.instance.setHydrationRemindersEnabled(val);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.targetMl > 0 ? (widget.currentMl / widget.targetMl).clamp(0.0, 1.0) : 0.0;
    final glasses = (widget.currentMl / 250).floor();
    final remainingMl = (widget.targetMl - widget.currentMl).clamp(0, widget.targetMl);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: InclineColors.accentOrange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.water_drop_rounded, size: 16, color: InclineColors.accentOrange),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'DAILY HYDRATION',
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
                  ],
                ),
              ),
              Row(
                children: [
                  if (progress >= 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'OPTIMAL',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emerald,
                        ),
                      ),
                    )
                  else
                    Text(
                      '$remainingMl ml to goal',
                      style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 16, color: context.textMuted),
                    onPressed: widget.onReset,
                    tooltip: 'Reset hydration',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Numbers & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          (widget.currentMl / 1000).toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: InclineColors.accentOrange,
                          ),
                        ),
                        Text(
                          ' / ${(widget.targetMl / 1000).toStringAsFixed(1)} L',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$glasses glasses logged • Essential for Sauna & Cryo flush',
                      style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: progress >= 1.0 ? AppTheme.emerald : InclineColors.accentOrange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Smooth Hydration Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.cardBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppTheme.emerald : InclineColors.accentOrange,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Quick Tap Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => widget.onAddWater(250),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: InclineColors.accentOrange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_drink_rounded, size: 14, color: InclineColors.accentOrange),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '+250 ml (Glass)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => widget.onAddWater(500),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    decoration: BoxDecoration(
                      color: InclineColors.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: InclineColors.accentOrange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_bar_rounded, size: 14, color: InclineColors.accentOrange),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '+500 ml (Shaker)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: InclineColors.accentOrange,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Hydration Push Notification Reminder Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderCol.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _remindersEnabled
                        ? InclineColors.accentOrange.withValues(alpha: 0.15)
                        : context.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _remindersEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    size: 14,
                    color: _remindersEnabled ? InclineColors.accentOrange : context.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hydration Push Reminders',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        _remindersEnabled ? 'Periodic cues • 1-tap logging' : 'Alerts paused',
                        style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch.adaptive(
                    value: _remindersEnabled,
                    activeColor: InclineColors.accentOrange,
                    onChanged: _toggleReminders,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
