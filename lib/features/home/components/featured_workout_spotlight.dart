import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/incline_colors.dart';

/// Data model for the Featured Workout Spotlight.
class FeaturedWorkoutData {
  final String title;
  final String category;
  final String durationText;
  final String intensity;
  final int exerciseCount;
  final String? coachName;
  final String? tag;
  final List<String> muscleGroups;

  const FeaturedWorkoutData({
    this.title = 'Hypertrophy Push & Core Stability',
    this.category = 'UPPER BODY SPLIT',
    this.durationText = '45 min',
    this.intensity = 'High Intensity',
    this.exerciseCount = 6,
    this.coachName = 'Incline Coaching Team',
    this.tag = 'RECOMMENDED TODAY',
    this.muscleGroups = const ['Pectorals', 'Anterior Delts', 'Triceps', 'Core'],
  });
}

/// 2026 Animated Luxury Featured Workout Spotlight
/// Features a subtle breathing ambient glow, kinetic pulse badge,
/// interactive muscle group chips, and responsive tactile CTA button.
class FeaturedWorkoutSpotlight extends StatefulWidget {
  final FeaturedWorkoutData data;
  final VoidCallback onStartSession;
  final VoidCallback? onViewDetails;

  const FeaturedWorkoutSpotlight({
    super.key,
    required this.data,
    required this.onStartSession,
    this.onViewDetails,
  });

  @override
  State<FeaturedWorkoutSpotlight> createState() => _FeaturedWorkoutSpotlightState();
}

class _FeaturedWorkoutSpotlightState extends State<FeaturedWorkoutSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final onAccentText = isDark ? Colors.black : Colors.white;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      InclineColors.cardSurface,
                      InclineColors.cardRecessed,
                    ]
                  : const [
                      InclineColors.lightCardSurface,
                      InclineColors.lightCardRecessed,
                    ],
            ),
            border: Border.all(
              color: primaryColor.withValues(
                alpha: 0.25 + (_pulseAnimation.value - 0.85) * 1.5,
              ),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(
                  alpha: isDark ? 0.08 * _pulseAnimation.value : 0.06,
                ),
                blurRadius: 28 * _pulseAnimation.value,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onViewDetails?.call();
              },
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Category Pill & Animated Live Spotlight Badge
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.data.category,
                                style: GoogleFonts.outfit(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.data.tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: InclineColors.accentOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Pulsing beacon dot
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: InclineColors.accentOrange,
                                    boxShadow: [
                                      BoxShadow(
                                        color: InclineColors.accentOrange.withValues(alpha: 0.8),
                                        blurRadius: 6 * _pulseAnimation.value,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.data.tag!,
                                  style: GoogleFonts.outfit(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Workout Title
                    Text(
                      widget.data.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: isDark ? Colors.white : InclineColors.lightTextPrimary,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),

                    if (widget.data.coachName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.data.coachName!,
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Animated Muscle Target Group Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.data.muscleGroups.map((group) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(
                            group,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // Meta Attributes (Duration, Exercises, Intensity)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                          isDark: isDark,
                          icon: Icons.schedule_rounded,
                          text: widget.data.durationText,
                        ),
                        _buildMetaChip(
                          isDark: isDark,
                          icon: Icons.format_list_bulleted_rounded,
                          text: '${widget.data.exerciseCount} Exercises',
                        ),
                        _buildMetaChip(
                          isDark: isDark,
                          icon: Icons.bolt_rounded,
                          text: widget.data.intensity,
                          iconColor: InclineColors.thermalAmber,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Kinetic CTA Action Button: "Start Session"
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(
                                alpha: 0.25 + 0.15 * _pulseAnimation.value,
                              ),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            widget.onStartSession();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: onAccentText,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: Text(
                            'Start Session',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: onAccentText,
                              letterSpacing: 0.4,
                            ),
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
      },
    );
  }

  Widget _buildMetaChip({
    required bool isDark,
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? (isDark ? Colors.white60 : InclineColors.lightTextMuted)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
