import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';
import '../../core/widgets/floating_paths_background.dart';

/// 2026 World-Class Luxury Onboarding Screen
/// Clean, kinetic, zero-redundancy design with interactive dumbbell loader.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlideData> _slides = [
    const OnboardingSlideData(
      eyebrow: '',
      title: 'Where Ambition\nMeets Ascendance',
      subtitle:
          'Where elite athletic performance meets mindful contrast recovery. Crafted exclusively for those who demand uncompromising excellence.',
      icon: Icons.fitness_center_rounded,
      highlightColor: AppTheme.gold,
      badgeText: 'INCLINE • RISE. REFLECT. REPEAT.',
      useFitnessLoader: true,
    ),
    const OnboardingSlideData(
      eyebrow: 'STEAM • SAUNA • COLD PLUNGE',
      title: 'Contrast Therapy\n& Recovery Suites',
      subtitle:
          'Aromatherapy steam included with select memberships, with flexible on-demand add-ons for private infrared saunas and contrast cold plunges.',
      icon: Icons.hot_tub_rounded,
      highlightColor: AppTheme.cyan,
      badgeText: 'RECOVERY SUITES & ADD-ONS',
      useFitnessLoader: false,
    ),
    const OnboardingSlideData(
      eyebrow: 'SMART EXECUTION',
      title: 'Day-Wise Routines\n& Watch Sync',
      subtitle:
          'Complete assigned sets with smart rest timers, interactive reps logging, and real-time smartwatch step & calorie sync.',
      icon: Icons.watch_rounded,
      highlightColor: AppTheme.emerald,
      badgeText: 'SMARTWATCH SYNC',
      useFitnessLoader: false,
    ),
    const OnboardingSlideData(
      eyebrow: 'ELEVATE YOUR LIFE',
      title: 'Your Journey\nAscends Today',
      subtitle:
          'Access your member passport, reserve recovery suites, track your progress, and connect with your master trainer.',
      icon: Icons.diamond_rounded,
      highlightColor: AppTheme.gold,
      badgeText: 'MEMBER PASSPORT',
      useFitnessLoader: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: FloatingPathsBackground(
        color: context.brandAccent,
        intensity: 0.85,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar with Brand Logo & Skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage('assets/incline_logo.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: EnvConfig.appName.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: ' ®',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.brandAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_currentPage < _slides.length - 1)
                      TextButton(
                        onPressed: widget.onComplete,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.outfit(
                            color: context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Middle Carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Bento Hero Card for Slide Icon / Kinetic Loader
                          BentoCard(
                            asymmetricCorners: true,
                            height: 250,
                            backgroundColor: InclineColors.cardSurface,
                            border: Border.all(
                              color: slide.highlightColor.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            child: Center(
                              child: slide.useFitnessLoader
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Iconic kinetic bouncing & spinning dumbbell loader with NO redundant text
                                        DumbbellLoader(
                                          text: null,
                                          size: DumbbellLoaderSize.lg,
                                          color: slide.highlightColor,
                                        ),
                                        const SizedBox(height: 18),
                                        // Refined stacked brand badge (No dot, two distinct lines)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: slide.highlightColor.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: slide.highlightColor.withValues(alpha: 0.28),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'INCLINE',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 3.5,
                                                  color: slide.highlightColor,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'RISE.REFLECT.REPEAT',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 2.0,
                                                  color: slide.highlightColor.withValues(alpha: 0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(22),
                                          decoration: BoxDecoration(
                                            color: slide.highlightColor.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: slide.highlightColor.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Icon(
                                            slide.icon,
                                            size: 56,
                                            color: slide.highlightColor,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: slide.highlightColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: slide.highlightColor.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            slide.badgeText,
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.5,
                                              color: slide.highlightColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Eyebrow
                          if (slide.eyebrow.isNotEmpty) ...[
                            Text(
                              slide.eyebrow,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                                color: slide.highlightColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Title
                          Text(
                            slide.title,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.15,
                              color: context.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              slide.subtitle,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                height: 1.5,
                                color: context.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 3. Bottom Navigation & Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  children: [
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (idx) {
                        final isActive = idx == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: isActive ? 30 : 8,
                          decoration: BoxDecoration(
                            color: isActive ? context.brandAccent : context.borderCol,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Next / Get Started Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.onComplete();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InclineColors.accentOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: const Color(0x66F0441C),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1
                                  ? 'GET STARTED • ENTER INCLINE'
                                  : 'CONTINUE',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSlideData {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color highlightColor;
  final String badgeText;
  final bool useFitnessLoader;

  const OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlightColor,
    required this.badgeText,
    this.useFitnessLoader = false,
  });
}
