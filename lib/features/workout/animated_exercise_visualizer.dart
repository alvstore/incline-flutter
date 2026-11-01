import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import 'detailed_exercise_sheet.dart';
import 'exercise_biomechanics_data.dart';
import 'exercise_video_card.dart';

/// Clean, Static Exercise Biomechanics & Coaching Guide
/// Replaces legacy canvas stick-figure animations with an executive,
/// battery-efficient, luxury Incline Club Bento specification.
class AnimatedExerciseVisualizer extends StatelessWidget {
  final WorkoutExercise exercise;
  final int exerciseIndex;
  final int totalExercises;
  final bool isResting;
  final bool? showVideo;
  final bool showProtocol;

  const AnimatedExerciseVisualizer({
    super.key,
    required this.exercise,
    required this.exerciseIndex,
    required this.totalExercises,
    this.isResting = false,
    this.showVideo,
    this.showProtocol = true,
  });

  @override
  Widget build(BuildContext context) {
    final profile = ExerciseMappingEngine.getProfile(exercise.name);
    final restPeriod = exercise.rest ?? profile.recommendedRest;
    final effectiveShowVideo = showVideo ?? exercise.showVideo;

    return BentoCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: context.cardElevated,
      border: Border.all(color: context.borderCol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Media Viewport (In-App Video Demo Card vs Static Image / Biomechanics Guide)
          if (effectiveShowVideo && exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty) ...[
            ExerciseVideoCard(
              key: ValueKey('vid_${exercise.name}_${exercise.videoUrl}'),
              videoUrl: exercise.videoUrl!,
              title: exercise.name,
              thumbnailUrl: exercise.imageUrl,
            ),
            const SizedBox(height: 16),
          ] else if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Image.network(
                    exercise.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1. Archetype & Tempo Indicators (Clean Static Pills)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: profile.archetypeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: profile.archetypeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(profile.archetypeIcon, size: 13, color: profile.archetypeColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${profile.archetype.name.toUpperCase()} ARCHETYPE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: profile.archetypeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderCol),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: context.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'REST: $restPeriod',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Exercise Title & Guide Action
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  DetailedExerciseSheet.show(context, exercise);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.brandAccent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: context.brandAccent),
                      const SizedBox(width: 4),
                      Text(
                        'GUIDE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.brandAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Machine / Station Identification Badge
          if (exercise.machineName != null && exercise.machineName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.precision_manufacturing_rounded, size: 13, color: AppTheme.cyan),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      exercise.machineName!.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cyan,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 6),
          Text(
            'Plane: ${profile.movementPlane} • Cadence: ${profile.optimalCadence}',
            style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
          ),

          const SizedBox(height: 18),

          // 4. Target Muscle Activation Grid
          Text(
            'TARGET MUSCLE ACTIVATION',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Primary Muscles (Emerald / Accent)
              ...profile.primaryMuscles.map((muscle) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 11, color: AppTheme.emerald),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          muscle,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Secondary & Stabilizer Muscles
              ...profile.secondaryMuscles.map((muscle) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Text(
                    muscle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 18),

          // 5. Coach Form Pointers & Biomechanical Protocol (Optional inline or placed at bottom)
          if (showProtocol) ...[
            const SizedBox(height: 18),
            CoachProtocolCard(exercise: exercise),
          ],
        ],
      ),
    );
  }
}

/// Standalone Coach Bhagirath Protocol & Biomechanical Pointers Card
class CoachProtocolCard extends StatelessWidget {
  final WorkoutExercise exercise;

  const CoachProtocolCard({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final profile = ExerciseMappingEngine.getProfile(exercise.name);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'COACH BHAGIRATH PROTOCOL',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppTheme.gold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.leadCoachAdvice,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              height: 1.35,
            ),
          ),
          if (profile.coachFormCues.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...profile.coachFormCues.take(2).map((cue) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent, fontWeight: FontWeight.w800)),
                    Expanded(
                      child: Text(
                        cue,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: context.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
