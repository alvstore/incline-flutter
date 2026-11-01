import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

/// 2026 World-Class Animated "Your Plan" Bento
/// Shows strictly: Days Left (with 2026 luxury motion physics) & Date of Joining. Nothing else.
class ProfilePlanBento extends StatefulWidget {
  final Membership? membership;

  const ProfilePlanBento({
    super.key,
    required this.membership,
  });

  @override
  State<ProfilePlanBento> createState() => _ProfilePlanBentoState();
}

class _ProfilePlanBentoState extends State<ProfilePlanBento> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;
  late Animation<int> _daysCountAnim;

  int _resolveTargetDays(Membership? membership) {
    final days = membership?.daysRemaining;
    return (days != null && days > 0) ? days : 0;
  }

  @override
  void initState() {
    super.initState();
    final targetDays = _resolveTargetDays(widget.membership);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _daysCountAnim = IntTween(begin: 0, end: targetDays).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ProfilePlanBento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership != widget.membership) {
      final targetDays = _resolveTargetDays(widget.membership);
      _daysCountAnim = IntTween(begin: _daysCountAnim.value, end: targetDays).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membership = widget.membership;
    final hasActive = membership != null && membership.daysRemaining > 0;
    final planName = hasActive
        ? membership.planName
        : (membership?.planName ?? 'No Active Membership');
    final targetDays = _resolveTargetDays(membership);

    // Date of joining: membership start date or current date
    final joinDate = membership?.startDate;
    final formattedJoinDate = joinDate != null ? DateFormat('d MMM yyyy').format(joinDate) : null;

    // Total subscription timeline (365 days)
    const totalDays = 365.0;
    final targetFraction = (targetDays / totalDays).clamp(0.0, 1.0);

    final statusColor = hasActive ? AppTheme.emerald : context.textMuted;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentDays = _daysCountAnim.value;
        final animatedProgress = _progressAnim.value * targetFraction;

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.borderCol,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: YOUR PLAN badge & Active/Inactive Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasActive ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                          color: statusColor,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'YOUR PLAN',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Text(
                      hasActive ? 'Active' : (membership != null ? 'Expired' : 'No Plan'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Plan Title
              Text(
                planName,
                style: GoogleFonts.outfit(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Animated Days Left Display with Emerald Glow
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$currentDays',
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DAYS LEFT',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedJoinDate != null
                              ? 'Joined $formattedJoinDate'
                              : 'Membership not started',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Animated Precision Progress Track
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.cardElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: animatedProgress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [InclineColors.accentOrange, InclineColors.thermalAmber],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
