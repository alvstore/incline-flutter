import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/incline_colors.dart';

/// Data model representing a curated Incline Fitness philosophy quote.
class InclineQuote {
  final String text;
  final String author;
  final String category;

  const InclineQuote({
    required this.text,
    required this.author,
    this.category = 'DAILY PERSPECTIVE',
  });
}

/// Curated library of 65 original Incline Fitness quotes.
/// Operates 100% offline without backend requests or push notifications.
const List<InclineQuote> kInclineDailyQuotes = [
  InclineQuote(
    text: 'Progress is not demanded by inspiration, but forged by the repetition you refuse to negotiate.',
    author: 'Incline Performance Creed',
    category: 'DAILY PERSPECTIVE',
  ),
  InclineQuote(
    text: 'Discipline is the quiet bridge between ambition and reality.',
    author: 'Incline Philosophy',
    category: 'MINDSET',
  ),
  InclineQuote(
    text: 'The weight never changes; your capacity to conquer it does.',
    author: 'Incline Iron Standard',
    category: 'STRENGTH',
  ),
  InclineQuote(
    text: 'True recovery is not inaction—it is deliberate preparation for greater load.',
    author: 'Incline Wellness Doctrine',
    category: 'RECOVERY',
  ),
  InclineQuote(
    text: 'Show up when the impulse fades. That is where standard turns into character.',
    author: 'Incline Performance Creed',
    category: 'CONSISTENCY',
  ),
  InclineQuote(
    text: 'Master the fundamental movement before seeking complex variations.',
    author: 'Incline Coaching Standard',
    category: 'TECHNIQUE',
  ),
  InclineQuote(
    text: 'Consistency compounds in silence until performance speaks for itself.',
    author: 'Incline Mindset',
    category: 'MOMENTUM',
  ),
  InclineQuote(
    text: 'A workout is not an obligation to pay; it is a declaration of capability.',
    author: 'Incline Creed',
    category: 'INTENTION',
  ),
  InclineQuote(
    text: 'Precision in form protects longevity in strength.',
    author: 'Incline Biomechanics Rule',
    category: 'LONGEVITY',
  ),
  InclineQuote(
    text: 'Every rep is an investment in the human you are engineering.',
    author: 'Incline Strength Lab',
    category: 'PERFORMANCE',
  ),
  InclineQuote(
    text: 'Fatigue is information, not a barrier. Learn to calibrate your threshold.',
    author: 'Incline Endurance Code',
    category: 'ENDURANCE',
  ),
  InclineQuote(
    text: 'Intensity earns results, but recovery locks them in.',
    author: 'Incline Recovery Philosophy',
    category: 'RECOVERY',
  ),
  InclineQuote(
    text: 'Build the habit first. The momentum will take care of the metric.',
    author: 'Incline Daily Creed',
    category: 'HABIT',
  ),
  InclineQuote(
    text: 'Small incremental loads today construct unshakable platforms tomorrow.',
    author: 'Incline Progression Code',
    category: 'PROGRESSION',
  ),
  InclineQuote(
    text: 'Your physiology responds to what you measure, respect, and repeat.',
    author: 'Incline Science & Motion',
    category: 'SCIENCE',
  ),
  InclineQuote(
    text: 'Leave ego at the threshold; bring intention to the platform.',
    author: 'Incline Floor Protocol',
    category: 'FOCUS',
  ),
  InclineQuote(
    text: 'The standard is what you tolerate when nobody is watching.',
    author: 'Incline Performance Creed',
    category: 'DISCIPLINE',
  ),
  InclineQuote(
    text: 'Strength is a skill. Practice it with the dignity of a craftsman.',
    author: 'Incline Master Coach',
    category: 'STRENGTH',
  ),
  InclineQuote(
    text: 'Hydration, sleep, and tension: master the triad of human output.',
    author: 'Incline Vitality Principles',
    category: 'RECOVERY',
  ),
  InclineQuote(
    text: 'Do not rush the adaptation. The body honors patient, brutal consistency.',
    author: 'Incline Training Standard',
    category: 'ADAPTATION',
  ),
  InclineQuote(
    text: 'Every session is a data point in your lifelong pursuit of mastery.',
    author: 'Incline Telemetry',
    category: 'TELEMETRY',
  ),
  InclineQuote(
    text: 'Tough days do not break momentum; they define your commitment to it.',
    author: 'Incline Resilience Code',
    category: 'RESILIENCE',
  ),
  InclineQuote(
    text: 'Focus on the execution of the single set currently in front of you.',
    author: 'Incline Focus Creed',
    category: 'EXECUTION',
  ),
  InclineQuote(
    text: 'Soreness is transient; adaptations earned under the bar are permanent.',
    author: 'Incline Physiology',
    category: 'PHYSIOLOGY',
  ),
  InclineQuote(
    text: 'Quality over fatigue. We train for neuromuscular output, not exhaustion.',
    author: 'Incline Strength Protocol',
    category: 'NEURO-OUTPUT',
  ),
  InclineQuote(
    text: 'Structure creates freedom. Trust the program and execute the reps.',
    author: 'Incline Programming Creed',
    category: 'PROGRAMMING',
  ),
  InclineQuote(
    text: 'Rest with the same discipline and focus that you bring to the rack.',
    author: 'Incline Contrast & Recovery',
    category: 'RECOVERY',
  ),
  InclineQuote(
    text: 'Discomfort is the currency required for physical adaptation.',
    author: 'Incline Philosophy',
    category: 'MINDSET',
  ),
  InclineQuote(
    text: 'Consistency is the ultimate differentiator in human athletic potential.',
    author: 'Incline Core Standard',
    category: 'CONSISTENCY',
  ),
  InclineQuote(
    text: 'Stand tall under the bar; let posture dictate your mindset.',
    author: 'Incline Platform Standard',
    category: 'STRENGTH',
  ),
  InclineQuote(
    text: 'Yesterday’s victory is today’s baseline. Reset and rise.',
    author: 'Incline Daily Creed',
    category: 'DAILY PERSPECTIVE',
  ),
  InclineQuote(
    text: 'Cold water sharpens focus; heated steam dissolves accumulated tension. Embrace the contrast.',
    author: 'Incline Contrast Recovery',
    category: 'CONTRAST RECOVERY',
  ),
  InclineQuote(
    text: 'Progressive overload is an uncompromising agreement between your ambition and the barbell.',
    author: 'Incline Iron Standard',
    category: 'STRENGTH',
  ),
  InclineQuote(
    text: 'Mobility without stability is vulnerability. Lock the joint and own the active range.',
    author: 'Incline Biomechanics Rule',
    category: 'MOBILITY',
  ),
  InclineQuote(
    text: 'Track your recovery with the same seriousness you track your heavy working sets.',
    author: 'Incline Telemetry Lab',
    category: 'TELEMETRY',
  ),
  InclineQuote(
    text: 'A workout missed is momentum lost; a workout rushed is an injury invited.',
    author: 'Incline Floor Protocol',
    category: 'DISCIPLINE',
  ),
  InclineQuote(
    text: 'The heart rate does not lie. Listen to your cardiovascular telemetry and master Zone 2.',
    author: 'Incline Cardio Engine',
    category: 'CARDIO',
  ),
  InclineQuote(
    text: 'Electrolytes and cellular hydration sustain muscular firing when willpower alone runs thin.',
    author: 'Incline Fuel Bar Protocol',
    category: 'HYDRATION',
  ),
  InclineQuote(
    text: 'Deep sleep is the silent biological laboratory where muscle tissue rebuilds and adapts.',
    author: 'Incline Sleep Science',
    category: 'SLEEP RECOVERY',
  ),
  InclineQuote(
    text: 'Do not negotiate with fatigue in the final third of your working sets. That is where standard lives.',
    author: 'Incline Resilience Code',
    category: 'RESILIENCE',
  ),
  InclineQuote(
    text: 'Your central nervous system commands the load. Respect neural fatigue before muscular strain.',
    author: 'Incline Neuro-Lifting Lab',
    category: 'NEURO-OUTPUT',
  ),
  InclineQuote(
    text: 'Small daily increments compound into unyielding physical and mental sovereignty.',
    author: 'Incline Progression Code',
    category: 'PROGRESSION',
  ),
  InclineQuote(
    text: 'Form is not an aesthetic preference; form is mechanical survival under high load.',
    author: 'Incline Lifting Standard',
    category: 'BIOMECHANICS',
  ),
  InclineQuote(
    text: 'Train with intent today so you can walk into the club stronger twenty years from now.',
    author: 'Incline Longevity Creed',
    category: 'LONGEVITY',
  ),
  InclineQuote(
    text: 'Breathe down into the diaphragm. Bracing begins in the core cylinder, not the shoulders.',
    author: 'Incline Breathwork Rule',
    category: 'BREATHWORK',
  ),
  InclineQuote(
    text: 'Discipline flourishes in structured routine and quietly withers in indecision.',
    author: 'Incline Philosophy',
    category: 'DISCIPLINE',
  ),
  InclineQuote(
    text: 'Sauna heat shock proteins accelerate cellular cleanup. Sweat with measurable purpose.',
    author: 'Incline Wellness Doctrine',
    category: 'RECOVERY',
  ),
  InclineQuote(
    text: 'The iron demands complete humility; the platform rewards honest, unglamorous preparation.',
    author: 'Incline Iron Standard',
    category: 'HONESTY',
  ),
  InclineQuote(
    text: 'Cardiovascular stamina constructs the aerobic base that powers high-volume lifting.',
    author: 'Incline Endurance Code',
    category: 'ENDURANCE',
  ),
  InclineQuote(
    text: 'Rest days are not earned through exhaustion; they are prescribed for biological adaptation.',
    author: 'Incline Recovery Philosophy',
    category: 'RESTORATION',
  ),
  InclineQuote(
    text: 'Strength is not merely moving mass; it is resisting movement where stability is required.',
    author: 'Incline Coaching Standard',
    category: 'STRENGTH',
  ),
  InclineQuote(
    text: 'Measure what matters: resting heart rate, sleep efficiency, and concentric bar velocity.',
    author: 'Incline Telemetry',
    category: 'TELEMETRY',
  ),
  InclineQuote(
    text: 'A quiet, focused mind under maximum load is the unmistakable hallmark of an elite lifter.',
    author: 'Incline Mindset',
    category: 'FOCUS',
  ),
  InclineQuote(
    text: 'Fuel your physiology like the high-output biological engine it was engineered to be.',
    author: 'Incline Fuel Bar Protocol',
    category: 'NUTRITION',
  ),
  InclineQuote(
    text: 'The cold plunge does not get warmer; your mental resolve gets colder, sharper, and unshakeable.',
    author: 'Incline Contrast Standard',
    category: 'DISCIPLINE',
  ),
  InclineQuote(
    text: 'Consistent effort over months always eclipses heroic intensity over days.',
    author: 'Incline Consistency Protocol',
    category: 'CONSISTENCY',
  ),
  InclineQuote(
    text: 'Every repetition completed with technical perfection is an investment in lifelong strength.',
    author: 'Incline Lifting Standard',
    category: 'INTEGRITY',
  ),
  InclineQuote(
    text: 'Hydration is your first defense against premature muscular cramping and neural lag.',
    author: 'Incline Vitality Principles',
    category: 'HYDRATION',
  ),
  InclineQuote(
    text: 'When motivation wanes, let the calendar and the habit dictate your attendance.',
    author: 'Incline Daily Creed',
    category: 'HABIT',
  ),
  InclineQuote(
    text: 'Control the eccentric tempo. True mastery owns the weight on the way down.',
    author: 'Incline Strength Lab',
    category: 'TECHNIQUE',
  ),
  InclineQuote(
    text: 'Optimal recovery is a proactive protocol, not a passive afternoon on the couch.',
    author: 'Incline Wellness Doctrine',
    category: 'ACTIVE RECOVERY',
  ),
  InclineQuote(
    text: 'Kinetic chains are only as durable as their weakest connective link. Train mobility.',
    author: 'Incline Mobility Directive',
    category: 'MOBILITY',
  ),
  InclineQuote(
    text: 'The mirror reflects vanity; continuous telemetry reflects physiological truth.',
    author: 'Incline Telemetry Lab',
    category: 'BIOMETRICS',
  ),
  InclineQuote(
    text: 'Build an engine that refuses to stall when the incline steepens.',
    author: 'Incline Endurance Code',
    category: 'ENDURANCE',
  ),
  InclineQuote(
    text: 'The summit of physical performance has no finish line—only an ever-rising standard.',
    author: 'Incline Performance Creed',
    category: 'EXCELLENCE',
  ),
];

/// Offline deterministic Daily Quote Card for Incline Fitness.
/// Features smooth animated reveal, tactile responsiveness, and responsive layout
/// adhering to `flutter-build-responsive-layout` principles.
class DailyQuoteCard extends StatefulWidget {
  final DateTime? date;
  final bool animate;

  const DailyQuoteCard({
    super.key,
    this.date,
    this.animate = true,
  });

  /// Deterministically pick a quote based on the local calendar date.
  static InclineQuote getQuoteForDate([DateTime? targetDate]) {
    final now = targetDate ?? DateTime.now();
    final epoch = DateTime(2026, 1, 1);
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(epoch.year, epoch.month, epoch.day))
        .inDays;
    final index = days.abs() % kInclineDailyQuotes.length;
    return kInclineDailyQuotes[index];
  }

  static String _formatDateTag(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return 'TODAY • ${months[d.month - 1]} ${d.day}';
  }

  @override
  State<DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<DailyQuoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _iconScaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
    ));

    _iconScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutBack),
    ));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = widget.date ?? DateTime.now();
    final quoteItem = DailyQuoteCard.getQuoteForDate(now);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive adaptive layout guidelines
        final isWide = constraints.maxWidth >= 600;
        final isCompact = constraints.maxWidth < 340;
        final horizontalPadding = isWide ? 20.0 : (isCompact ? 12.0 : 16.0);
        final verticalPadding = isWide ? 16.0 : (isCompact ? 11.0 : 13.0);
        final quoteFontSize = isWide ? 14.5 : (isCompact ? 12.0 : 13.5);
        final tagFontSize = isWide ? 11.0 : (isCompact ? 9.5 : 10.0);
        final authorFontSize = isWide ? 12.0 : (isCompact ? 10.0 : 11.0);

        final cardContent = Container(
          decoration: BoxDecoration(
            color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? InclineColors.cardBorder
                  : InclineColors.lightCardBorder,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thermal vermilion accent spine
                  Container(
                    width: 3.5,
                    color: InclineColors.accentOrange,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: Animated Quote icon + Tag + Date
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ScaleTransition(
                                      scale: _iconScaleAnimation,
                                      child: Icon(
                                        Icons.format_quote_rounded,
                                        size: isWide ? 16 : 14,
                                        color: InclineColors.accentOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        quoteItem.category,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: tagFontSize,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                          color: InclineColors.accentOrange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DailyQuoteCard._formatDateTag(now),
                                style: GoogleFonts.inter(
                                  fontSize: tagFontSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: isDark
                                      ? InclineColors.textMuted
                                      : InclineColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isWide ? 9 : 7),

                          // Quote Body
                          Text(
                            '“${quoteItem.text}”',
                            style: GoogleFonts.outfit(
                              fontSize: quoteFontSize,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              height: 1.38,
                              color: isDark
                                  ? InclineColors.textPrimary
                                  : InclineColors.lightTextPrimary,
                            ),
                          ),

                          SizedBox(height: isWide ? 7 : 5),

                          // Attribution
                          Text(
                            '— ${quoteItem.author}',
                            style: GoogleFonts.inter(
                              fontSize: authorFontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? InclineColors.textSecondary
                                  : InclineColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                HapticFeedback.lightImpact();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _isPressed ? 0.985 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: cardContent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
