import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

/// 2026 World-Class Quick Action Bar: Google Maps Location & Call Concierge
/// Positioned directly above the brand footer, fully theme-adaptive.
class ProfileContactBar extends StatelessWidget {
  final Branch? branch;

  const ProfileContactBar({
    super.key,
    this.branch,
  });

  Future<void> _openGoogleMaps(BuildContext context) async {
    HapticFeedback.lightImpact();
    final address = branch?.address ?? 'Incline Flagship, Sukhadia Circle, Udaipur, Rajasthan 313001';
    final query = Uri.encodeComponent('Incline Flagship Fitness Club Udaipur $address');
    final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(mapsUrl);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening club location on Google Maps...'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
  }

  Future<void> _makeClubCall(BuildContext context) async {
    HapticFeedback.lightImpact();
    final phone = branch?.phone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club frontdesk phone number is not available.')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final telUri = Uri.parse('tel:$cleanPhone');

    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        Clipboard.setData(ClipboardData(text: cleanPhone));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Concierge phone $phone copied to clipboard'),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: cleanPhone));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Concierge phone $phone copied to clipboard'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Google Maps Location Button
        Expanded(
          child: InkWell(
            onTap: () => _openGoogleMaps(context),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderCol, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Maps',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Club Location',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
        const SizedBox(width: 12),

        // 2. Call Concierge Button
        Expanded(
          child: InkWell(
            onTap: () => _makeClubCall(context),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderCol, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: AppTheme.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call Club',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Concierge Desk',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
      ],
    );
  }
}
