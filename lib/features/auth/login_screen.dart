import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/session_manager.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/incline_ui.dart';
import '../../core/theme/incline_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../onboarding/components/fitness_login_hero.dart';
import '../onboarding/components/incline_motion_track_background.dart';

/// 2026 World-Class Luxury Authentication Screen for Incline Members
/// Features:
/// - Breathing atmospheric ambient spotlight aura
/// - Staggered physics-driven entrance animations
/// - Dynamic input focus glow halo with haptic touch feedback
/// - Shake animation on invalid authentication attempts
/// - Kinetic specular shimmer sweep across primary CTA button
/// - Supports seamless transparent overlay mode on top of splash video
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool isTransparentBackground;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.isTransparentBackground = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: kDebugMode ? 'mohitgurjarawanaa@gmail.com' : '',
  );
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController(text: 'Incline@2026');

  // Focus nodes for haptic touch feedback and active glow states
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isPhoneMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // 1. Staggered Entrance Animation Controller
  late AnimationController _entryController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _ctaFade;
  late Animation<double> _footerFade;

  // 2. Atmospheric Breathing Ambient Aura Controller
  late AnimationController _auraController;
  late Animation<double> _auraAnimation;

  // 3. Error Shake Physics Controller
  late AnimationController _shakeController;

  // 4. Button Specular Shimmer Sweep Controller
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // 1. Initialize staggered entrance animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _ctaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.45, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.68, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entryController.forward();

    // 2. Ambient Breathing Aura (repeats continuously)
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _auraAnimation = Tween<double>(begin: 0.10, end: 0.22).animate(
      CurvedAnimation(parent: _auraController, curve: Curves.easeInOut),
    );

    // 3. Error Shake Physics
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 4. Specular Shimmer Sweep on CTA
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // Attach haptic feedback listeners to input focus
    _emailFocusNode.addListener(_onEmailFocusChange);
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  void _onEmailFocusChange() {
    if (_emailFocusNode.hasFocus) {
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _onPasswordFocusChange() {
    if (_passwordFocusNode.hasFocus) {
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _triggerErrorShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);

    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();

    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();

    _entryController.dispose();
    _auraController.dispose();
    _shakeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) {
      _triggerErrorShake();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isPhoneMode) {
        final phone = _phoneController.text.trim();
        await SupabaseService.instance.signInWithPhone(
          phone: phone,
          password: _passwordController.text,
        );
      } else {
        final email = _emailController.text.trim();
        await SupabaseService.instance.signInWithEmail(
          email: email,
          password: _passwordController.text,
        );
      }

      SessionManager.instance.clearInvalidSession();
      HapticFeedback.heavyImpact();
      widget.onLoginSuccess();
    } catch (e) {
      _triggerErrorShake();
      setState(() {
        _errorMessage = UserFriendlyErrorMapper.toAuthErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordSheet() {
    HapticFeedback.selectionClick();
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSubmitting = false;
    String? resetError;
    String? resetSuccess;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF141416),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF26262B), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0441C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFFF0441C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Password',
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Powered by Supabase Authentication',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: InclineColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter your registered email address. We will send you a secure link to reset your password.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: InclineColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF19191C),
                    hintText: 'member@theincline.in',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: InclineColors.textMuted,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.email_outlined, color: InclineColors.textSecondary, size: 18),
                    suffixIcon: const SizedBox(width: 48),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF0441C), width: 1.5),
                    ),
                  ),
                ),
                if (resetError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    resetError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: InclineColors.thermalRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (resetSuccess != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    resetSuccess!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF32D74B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setSheetState(() {
                              resetError = 'Please enter a valid email address';
                              resetSuccess = null;
                            });
                            return;
                          }
                          setSheetState(() {
                            isSubmitting = true;
                            resetError = null;
                            resetSuccess = null;
                          });
                          try {
                            await SupabaseService.instance.sendPasswordResetEmail(email: email);
                            HapticFeedback.mediumImpact();
                            setSheetState(() {
                              isSubmitting = false;
                              resetSuccess = 'Password reset link sent! Check your inbox.';
                            });
                            Future.delayed(const Duration(milliseconds: 1800), () {
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            });
                          } catch (e) {
                            HapticFeedback.heavyImpact();
                            setSheetState(() {
                              isSubmitting = false;
                              resetError = UserFriendlyErrorMapper.toAuthErrorMessage(e);
                            });
                          }
                        },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF0441C).withValues(alpha: 0.85),
                          const Color(0xFFD63611).withValues(alpha: 0.85),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF0441C).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Send Reset Instructions',
                            style: GoogleFonts.syne(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showConciergeHelpSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: BoxDecoration(
          color: InclineColors.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: InclineColors.cardBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 40,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: InclineColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: InclineColors.accentOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Concierge',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Direct Front Desk & Credential Assistance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: InclineColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Forgot your password or need access help? Our front desk concierge team is available to verify and reset your credentials instantly.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: InclineColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // WhatsApp Concierge Button
            InkWell(
              onTap: () async {
                final uri = Uri.parse(
                  'https://wa.me/918298293003?text=Hi%20Incline%20Team,%20I%20need%20assistance%20accessing%20my%20member%20account.',
                );
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: InclineColors.cardRecessed,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: InclineColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: InclineColors.accentOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WhatsApp Concierge',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '+91 8298293003 • Instant Support',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: InclineColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: InclineColors.textSecondary,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Direct Call Front Desk
            InkWell(
              onTap: () async {
                final uri = Uri.parse('tel:+918298293003');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: InclineColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: InclineColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Front Desk Hotline',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Available 6:00 AM – 10:00 PM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.plusJakartaSans(
                    color: InclineColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = SessionManager.instance;
    final isSessionInvalid = sessionManager.isSessionInvalid;

    return Scaffold(
      backgroundColor: widget.isTransparentBackground
          ? Colors.transparent
          : const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(child: InclineMotionTrackBackground()),
            ),
          ),

          // 1. ATMOSPHERIC BREATHING AMBIENT RADIAL SPOTLIGHT
          AnimatedBuilder(
            animation: _auraAnimation,
            builder: (context, _) {
              return Positioned(
                top: -120,
                left: 0,
                right: 0,
                height: 460,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.25),
                      radius: 0.90,
                      colors: [
                        const Color(0xFFF0441C).withValues(alpha: _auraAnimation.value),
                        const Color(0xFF141416).withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;

                return Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: isLandscape
                          ? 10
                          : (widget.isTransparentBackground ? 64 : 20),
                      bottom: isLandscape ? 16 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 520 : 440,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: isLandscape
                                ? 4
                                : (widget.isTransparentBackground ? 32 : 8),
                          ),

                      // Fitness Concept 02: aligned brand mark and moving barbell.
                      const FitnessLoginHero(),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome back.',
                        style: GoogleFonts.outfit(
                          color: InclineColors.textPrimary,
                          fontSize: 30,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in with your email or mobile number to continue.',
                        style: GoogleFonts.outfit(
                          color: InclineColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Session Invalidation Banner if session expired
                      if (isSessionInvalid) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AB91C1C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0x44B91C1C),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                color: InclineColors.thermalRed,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sessionManager.invalidReason ??
                                      'Session expired. Please sign in again.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3. OBSIDIAN CREDENTIAL CARD WITH SHAKE ANIMATION & HAPTIC GLOW
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final double shakeOffset =
                                  math.sin(_shakeController.value * math.pi * 6) * 10;
                              return Transform.translate(
                                offset: Offset(shakeOffset, 0),
                                child: child,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: widget.isTransparentBackground
                                        ? const Color(0xFF141416).withValues(alpha: 0.60)
                                        : const Color(0xFF141416),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.10),
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 36,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Segmented Mode Switcher (Email vs Mobile)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D0D0E),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildSegmentButton(
                                              title: 'Email Address',
                                              icon: Icons.alternate_email_rounded,
                                              isSelected: !_isPhoneMode,
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() => _isPhoneMode = false);
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildSegmentButton(
                                              title: 'Mobile Number',
                                              icon: Icons.phone_android_rounded,
                                              isSelected: _isPhoneMode,
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() => _isPhoneMode = true);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // Dynamic Input (Email or Phone) with Animated Glow & Centered Content
                                    if (!_isPhoneMode) ...[
                                      _buildFieldLabel('REGISTERED EMAIL'),
                                      const SizedBox(height: 8),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: _emailFocusNode.hasFocus
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFF0441C).withValues(alpha: 0.28),
                                                    blurRadius: 18,
                                                    spreadRadius: 1.5,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: TextFormField(
                                          controller: _emailController,
                                          focusNode: _emailFocusNode,
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.emailAddress,
                                          onTap: () => HapticFeedback.selectionClick(),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          decoration: _buildInputDecoration(
                                            hintText: 'member@theincline.in',
                                            prefixIcon: Icons.email_outlined,
                                            isFocused: _emailFocusNode.hasFocus,
                                            suffixIcon: const SizedBox(width: 48),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Please enter your registered email';
                                            }
                                            if (!v.contains('@')) {
                                              return 'Please enter a valid email address';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ] else ...[
                                      _buildFieldLabel('MOBILE NUMBER'),
                                      const SizedBox(height: 8),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: _phoneFocusNode.hasFocus
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFF0441C).withValues(alpha: 0.28),
                                                    blurRadius: 18,
                                                    spreadRadius: 1.5,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: TextFormField(
                                          controller: _phoneController,
                                          focusNode: _phoneFocusNode,
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.phone,
                                          onTap: () => HapticFeedback.selectionClick(),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          decoration: _buildInputDecoration(
                                            hintText: '82098 87831',
                                            prefixIcon: Icons.phone_iphone_rounded,
                                            prefixBadge: '+91',
                                            isFocused: _phoneFocusNode.hasFocus,
                                            suffixIcon: const SizedBox(width: 70),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Please enter your 10-digit mobile number';
                                            }
                                            final clean = v.replaceAll(RegExp(r'\D'), '');
                                            if (clean.length < 10) {
                                              return 'Please enter a 10-digit mobile number';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 20),

                                    // Password Field with Haptic Focus & Centered Content
                                    _buildFieldLabel('PASSWORD'),
                                    const SizedBox(height: 8),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: _passwordFocusNode.hasFocus
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFF0441C).withValues(alpha: 0.28),
                                                  blurRadius: 18,
                                                  spreadRadius: 1.5,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocusNode,
                                        textAlign: TextAlign.center,
                                        obscureText: _obscurePassword,
                                        onTap: () => HapticFeedback.selectionClick(),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 14,
                                          letterSpacing: _obscurePassword ? 2.0 : 0.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: _buildInputDecoration(
                                          hintText: '••••••••••••',
                                          prefixIcon: Icons.lock_outline_rounded,
                                          isFocused: _passwordFocusNode.hasFocus,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: InclineColors.textMuted,
                                              size: 19,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              setState(
                                                () => _obscurePassword = !_obscurePassword,
                                              );
                                            },
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),

                                    // Forgot Password Action (Aligned with Supabase auth functions)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _showForgotPasswordSheet,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFF0441C).withValues(alpha: 0.90),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Error Banner with shake hint
                                    if (_errorMessage != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1DB91C1C),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0x44B91C1C),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: InclineColors.thermalRed,
                                              size: 17,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: InclineColors.thermalRed,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // 4. Primary CTA: Get Incline (Smaller text, translucent luxury gradient)
                                    FadeTransition(
                                      opacity: _ctaFade,
                                      child: InclineScaleButton(
                                        onTap: _isLoading ? null : _handleSignIn,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Stack(
                                            children: [
                                              Container(
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 0.18),
                                                    width: 1,
                                                  ),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      const Color(0xFFF0441C).withValues(alpha: 0.78),
                                                      const Color(0xFFD63611).withValues(alpha: 0.78),
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFF0441C).withValues(alpha: 0.30),
                                                      blurRadius: 18,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.0,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            'Get Incline',
                                                            style: GoogleFonts.syne(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w800,
                                                              letterSpacing: 2.0,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          const Icon(
                                                            Icons.arrow_forward_rounded,
                                                            size: 14,
                                                            color: Colors.white,
                                                          ),
                                                        ],
                                                      ),
                                              ),

                                              // Specular Light Sweep Animation across CTA
                                              Positioned.fill(
                                                child: AnimatedBuilder(
                                                  animation: _shimmerController,
                                                  builder: (context, child) {
                                                    final shimmerPos =
                                                        (_shimmerController.value * 2.5) - 0.75;
                                                    return FractionalTranslation(
                                                      translation: Offset(shimmerPos, 0),
                                                      child: child,
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.centerLeft,
                                                        end: Alignment.centerRight,
                                                        colors: [
                                                          Colors.transparent,
                                                          Colors.white.withValues(alpha: 0.18),
                                                          Colors.transparent,
                                                        ],
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                      const SizedBox(height: 24),

                      // 6. CONCIERGE HELP & EDITORIAL FOOTER
                      FadeTransition(
                        opacity: _footerFade,
                        child: Column(
                          children: [
                            Center(
                              child: TextButton.icon(
                                onPressed: _showConciergeHelpSheet,
                                icon: const Icon(
                                  Icons.support_agent_rounded,
                                  size: 16,
                                  color: InclineColors.textSecondary,
                                ),
                                label: Text(
                                  'Need credential assistance?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: InclineColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                '© 2026 THE INCLINE LIFE • MEMBER ACCESS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w600,
                                  color: InclineColors.textMuted,
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
          },
        ),
      ),
    ],
  ),
);
  }

  Widget _buildFieldLabel(String label) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          color: InclineColors.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool isFocused,
    Widget? suffixIcon,
    String? prefixBadge,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: widget.isTransparentBackground
          ? const Color(0xFF19191C).withValues(alpha: 0.50)
          : const Color(0xFF19191C),
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: InclineColors.textMuted,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: prefixBadge != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14),
                Icon(
                  prefixIcon,
                  color: isFocused ? const Color(0xFFF0441C) : InclineColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF0441C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prefixBadge,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF0441C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ],
            )
          : Icon(
              prefixIcon,
              color: isFocused ? const Color(0xFFF0441C) : InclineColors.textSecondary,
              size: 18,
            ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFF0441C),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InclineColors.thermalRed,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InclineColors.thermalRed,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0441C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF0441C).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : InclineColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : InclineColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
