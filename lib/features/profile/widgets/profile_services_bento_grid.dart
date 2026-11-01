import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// 2026 World-Class 2x2 Member Services & Financials Bento Grid
/// Theme-adaptive with Incline tokens (light & dark).
class ProfileServicesBentoGrid extends StatelessWidget {
  final VoidCallback onOpenInvoices;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenFeedback;

  const ProfileServicesBentoGrid({
    super.key,
    required this.onOpenInvoices,
    required this.onOpenAttendance,
    required this.onOpenRequests,
    required this.onOpenFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: AppTheme.emerald,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'MEMBER SERVICES & ACCOUNT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: context.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 1: Invoices & Turnstile Attendance
        Row(
          children: [
            Expanded(
              child: _buildBentoTile(
                context: context,
                title: 'Invoices & Receipts',
                subtitle: 'Past invoices & receipts',
                badge: 'VERIFIED',
                badgeColor: AppTheme.emerald,
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.emerald,
                onTap: onOpenInvoices,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoTile(
                context: context,
                title: 'Turnstile Logs',
                subtitle: 'Optical check-ins & streak',
                badge: 'ENROLLED',
                badgeColor: InclineColors.accentOrange,
                icon: Icons.history_rounded,
                iconColor: InclineColors.accentOrange,
                onTap: onOpenAttendance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Service Requests & Member Feedback
        Row(
          children: [
            Expanded(
              child: _buildBentoTile(
                context: context,
                title: 'Desk Requests',
                subtitle: 'Inquiries, freeze, lockers',
                badge: 'PRIORITY',
                badgeColor: InclineColors.thermalAmber,
                icon: Icons.assignment_outlined,
                iconColor: InclineColors.thermalAmber,
                onTap: onOpenRequests,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoTile(
                context: context,
                title: 'Club Feedback',
                subtitle: 'Rate amenities & coaches',
                badge: '5★ RATED',
                badgeColor: InclineColors.accentOrange,
                icon: Icons.star_outline_rounded,
                iconColor: InclineColors.accentOrange,
                onTap: onOpenFeedback,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
