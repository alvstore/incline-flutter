import '../../../core/theme/incline_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';

/// 2026 World-Class Club Concierge & Location Bento Card
class ProfileClubConciergeCard extends StatelessWidget {
  final Branch? branch;

  const ProfileClubConciergeCard({super.key, required this.branch});

  @override
  @override
  Widget build(BuildContext context) {
    final branchName = branch?.name.isNotEmpty == true ? branch!.name : 'INCLINE CLUB';
    final branchAddress = branch?.address ?? '';
    final branchCity = branch?.city ?? '';
    final branchState = branch?.state ?? '';
    final branchPostalCode = branch?.postalCode ?? '';
    final addressParts = [branchAddress, branchCity, branchState, branchPostalCode]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final fullAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Address available via Club Concierge';
    final branchPhone = branch?.phone.isNotEmpty == true ? branch!.phone : '+91 8298293003';
    final branchGstin = branch?.gstin.isNotEmpty == true ? branch!.gstin : '';
    final openingTime = branch?.openingTime.isNotEmpty == true ? branch!.openingTime : '06:00 AM';
    final closingTime = branch?.closingTime.isNotEmpty == true ? branch!.closingTime : '10:00 PM';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: InclineColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: InclineColors.cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location Badge & Open Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0x1AF0441C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.place_outlined,
                        color: InclineColors.accentOrange,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'CLUB LOCATION',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: InclineColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1AF0441C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33F0441C), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: InclineColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'OPEN TODAY',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: InclineColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Club Name & Tagline
          Text(
            branch?.city.isNotEmpty == true ? '$branchName • ${branch!.city.toUpperCase()}' : branchName,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RISE • REFLECT • REPEAT',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: InclineColors.accentOrange,
            ),
          ),
          const SizedBox(height: 12),

          // Full Address
          Text(
            fullAddress,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: InclineColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          // Hours & GSTIN Plaque
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: InclineColors.cardSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: InclineColors.cardBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: InclineColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      '$openingTime – $closingTime',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (branchGstin.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: InclineColors.cardSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: InclineColors.cardBorder, width: 1),
                  ),
                  child: Text(
                    'GSTIN: $branchGstin',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: InclineColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: Google Maps Navigation & WhatsApp Concierge
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final query = Uri.encodeComponent(fullAddress);
                    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: InclineColors.cardRecessed,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: InclineColors.cardBorder, width: 1),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_rounded, color: InclineColors.accentOrange, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Google Maps',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final cleanPhone = branchPhone.replaceAll(RegExp(r'\D'), '');
                    final target = cleanPhone.isNotEmpty ? cleanPhone : '918298293003';
                    final uri = Uri.parse('https://wa.me/$target?text=Hi%20Incline%20Concierge,%20I%20have%20an%20inquiry%20regarding%20my%20club%20membership.');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: InclineColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: InclineColors.cardBorder, width: 1),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.support_agent_rounded, color: InclineColors.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Concierge',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: InclineColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
