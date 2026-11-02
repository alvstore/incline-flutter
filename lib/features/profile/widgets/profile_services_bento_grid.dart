import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Member service shortcuts in a compact, theme-aware grid.
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
        const SizedBox(height: 14),

        // Row 1: Invoices & Turnstile Attendance
        Row(
          children: [
            Expanded(
              child: _buildBentoTile(
                context: context,
                title: 'Invoices & Receipts',
                subtitle: 'Past invoices & receipts',
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
            height: 132,
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
                        color: iconColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: context.textMuted, size: 18),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
