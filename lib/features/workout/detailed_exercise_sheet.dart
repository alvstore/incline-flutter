import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import 'exercise_biomechanics_data.dart';

/// Modal Bottom Sheet displaying in-depth biomechanics,
/// anatomical muscle activation diagrams, kinematics, and Coach protocols.
class DetailedExerciseSheet extends StatelessWidget {
  final WorkoutExercise exercise;

  const DetailedExerciseSheet({super.key, required this.exercise});

  static void show(BuildContext context, WorkoutExercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetailedExerciseSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ExerciseMappingEngine.getProfile(exercise.name);
    final restPeriod = exercise.rest ?? profile.recommendedRest;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: context.borderCol),
              left: BorderSide(color: context.borderCol),
              right: BorderSide(color: context.borderCol),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.borderCol,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          if (exercise.machineName != null && exercise.machineName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              exercise.machineName!.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.cyan,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    // Kinematics & Archetype Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: profile.archetypeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: profile.archetypeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${profile.archetype.name.toUpperCase()} ARCHETYPE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: profile.archetypeColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderCol),
                          ),
                          child: Text(
                            'REST: $restPeriod',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Plane: ${profile.movementPlane}  •  Cadence: ${profile.optimalCadence}',
                      style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                    ),

                    const SizedBox(height: 24),

                    // Section 1: Anatomical Target Muscle Activation
                    Text(
                      'TARGET MUSCLE ACTIVATION',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...profile.primaryMuscles.map((muscle) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.emerald),
                                const SizedBox(width: 5),
                                Text(
                                  muscle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.emerald,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        ...profile.secondaryMuscles.map((muscle) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

                    const SizedBox(height: 24),

                    // Section 2: Coach Form Protocol
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.gold),
                              const SizedBox(width: 8),
                              Text(
                                'COACH BHAGIRATH PROTOCOL',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            profile.leadCoachAdvice,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          if (profile.coachFormCues.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...profile.coachFormCues.map((cue) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 14, color: AppTheme.emerald),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cue,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: context.textSecondary,
                                          height: 1.35,
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
