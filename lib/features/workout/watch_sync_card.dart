import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/watch_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';

/// Riverpod & Flutter-Animate powered Bento Card for Smartwatch & Daily Telemetry
class WatchSyncCard extends ConsumerWidget {
  const WatchSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchData = ref.watch(watchSyncProvider);
    final watchService = WatchSyncService.instance;
    final isSyncing = watchService.isSyncing;

    return BentoCard(
      asymmetricCorners: true,
      backgroundColor: context.cardElevated,
      border: Border.all(
        color: AppTheme.cyan.withValues(alpha: 0.3),
        width: 1.2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(watchService.watchIcon, size: 18, color: AppTheme.cyan),
                    )
                        .animate(target: watchData.isConnected ? 1 : 0)
                        .shimmer(duration: 2.seconds, color: AppTheme.cyan.withValues(alpha: 0.4)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            watchData.isConnected ? watchService.watchBrand.toUpperCase() : 'NO WEARABLE PAIRED',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: watchData.isConnected ? AppTheme.cyan : context.textMuted,
                            ),
                          ),
                          Text(
                            watchData.isConnected ? watchService.ecosystemSubtitle : 'Phone Tracking • Sensor Disconnected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan),
                      )
                    : const Icon(Icons.sync_rounded, color: AppTheme.cyan, size: 22)
                        .animate(onPlay: (controller) => controller.repeat())
                        .rotate(duration: 4.seconds, curve: Curves.linear),
                tooltip: 'Sync with watch now',
                onPressed: isSyncing ? null : () => ref.read(watchSyncProvider.notifier).syncNow(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3-Metric Bento Subgrid with Staggered Fluid Animations
          Row(
            children: [
              // Steps with circular ring
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: watchData.stepProgress,
                              strokeWidth: 4,
                              backgroundColor: context.borderCol,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                            ),
                            const Icon(Icons.directions_walk_rounded, size: 18, color: AppTheme.cyan),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              NumberFormat('#,###').format(watchData.steps),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              '/ ${NumberFormat('#,###').format(watchData.goalSteps)} steps',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ),
              const SizedBox(width: 10),

              // Active Calories
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 16, color: InclineColors.accentOrange),
                          const SizedBox(width: 4),
                          Text(
                            'CALORIES',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${watchData.activeCalories}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '/ ${watchData.goalCalories} kcal',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ),
              const SizedBox(width: 10),

              // Heart Rate
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, size: 16, color: InclineColors.thermalRed)
                              .animate(target: (watchData.isConnected && watchData.heartRate > 0) ? 1 : 0)
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.2, 1.2),
                                duration: 800.ms,
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(width: 4),
                          Text(
                            'PULSE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (watchData.isConnected && watchData.heartRate > 0)
                            ? '${watchData.heartRate}'
                            : '--',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: (watchData.isConnected && watchData.heartRate > 0)
                              ? InclineColors.thermalRed
                              : context.textPrimary,
                        ),
                      ),
                      Text(
                        (watchData.isConnected && watchData.heartRate > 0)
                            ? 'BPM Live'
                            : 'Sensor Idle',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ),
            ],
          ),

          // Bottom Timestamp Info Bar
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                watchData.hasSyncedToday
                    ? 'Synced ${DateFormat('hh:mm a').format(watchData.lastSyncTime)}'
                    : 'Auto-sync active with fitness tracker',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: context.textMuted,
                ),
              ),
              InkWell(
                onTap: isSyncing ? null : () => ref.read(watchSyncProvider.notifier).syncNow(),
                child: Text(
                  'Refresh Now →',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
