import '../../../core/theme/incline_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/incline_ui.dart';

/// 2026 World-Class Personal Coaching & Wellness Team Bento Card
class ProfileCoachCard extends StatelessWidget {
  final MyTrainer? trainer;
  final VoidCallback onRequestConsultation;

  const ProfileCoachCard({
    super.key,
    required this.trainer,
    required this.onRequestConsultation,
  });

  @override
  Widget build(BuildContext context) {
    final hasTrainer = trainer != null && trainer!.fullName.trim().isNotEmpty;
    final coachName = hasTrainer ? trainer!.fullName : 'Incline Coaching Team';
    final coachCode = hasTrainer ? (trainer!.trainerCode ?? 'TRAINER') : 'CONCIERGE';
    final coachSpecialization = hasTrainer && trainer!.specializations.isNotEmpty
        ? trainer!.specializations.join(' • ')
        : 'Lead Athletic & Biomechanics Coaching';

    final targetPhone = trainer?.phone ?? EnvConfig.supportPhone;
    final cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');

    return Container(
      padding: const EdgeInsets.all(20),
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
                        Icons.sports_rounded,
                        color: InclineColors.accentOrange,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'PERSONAL COACH',
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
                  color: InclineColors.cardBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  coachCode,
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: InclineColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Coach Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: InclineColors.cardRecessed,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InclineColors.cardBorder, width: 1),
                ),
                child: Center(
                  child: Text(
                    'BG',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: InclineColors.accentOrange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coachName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      coachSpecialization,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: InclineColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: WhatsApp Coach & Consult
          Row(
            children: [
              Expanded(
                child: InclineScaleButton(
                  onTap: () async {
                    final message = hasTrainer
                        ? 'Hi ${trainer!.fullName}, I would like to consult regarding my workout and training routine.'
                        : 'Hi Incline Team, I would like to consult regarding personal training and workout routines.';
                    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                          const Icon(Icons.chat_outlined, color: InclineColors.accentOrange, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp',
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
                child: InclineScaleButton(
                  onTap: onRequestConsultation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                          const Icon(Icons.tune_rounded, color: InclineColors.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Consultation',
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
