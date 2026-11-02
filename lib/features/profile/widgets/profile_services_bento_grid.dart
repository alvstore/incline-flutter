import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Member service shortcuts rendered as clean, high-density icon action cards
/// that match the Quick Actions and Contact Bar language, saving vertical space
/// and delivering a cohesive, responsive 2x2 layout.
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
                color: context.brandAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                color: context.brandAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your club services',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 1: Invoices & Receipts + Attendance
        Row(
          children: [
            Expanded(
              child: _buildServiceActionCard(
                context: context,
                title: 'Invoices',
                subtitle: 'Past payments',
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.emerald,
                onTap: onOpenInvoices,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceActionCard(
                context: context,
                title: 'Attendance',
                subtitle: 'Optical check-ins',
                icon: Icons.history_rounded,
                iconColor: InclineColors.accentOrange,
                onTap: onOpenAttendance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Desk Requests + Club Feedback
        Row(
          children: [
            Expanded(
              child: _buildServiceActionCard(
                context: context,
                title: 'Desk Requests',
                subtitle: 'Inquiries & lockers',
                icon: Icons.assignment_outlined,
                iconColor: InclineColors.thermalAmber,
                onTap: onOpenRequests,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceActionCard(
                context: context,
                title: 'Club Feedback',
                subtitle: 'Rate amenities',
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

  Widget _buildServiceActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderCol, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.14 : 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
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
                          fontWeight: FontWeight.w400,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
