import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

/// Member photo, account status, and copyable member code.
class ProfileDossierHero extends StatelessWidget {
  final Member? member;
  final VoidCallback? onAvatarTap;

  const ProfileDossierHero({
    super.key,
    required this.member,
    this.onAvatarTap,
  });

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = member?.profile?.fullName ?? member?.fullName ?? 'Incline Member';
    final memberCode = member?.memberCode ?? 'INC-MEMBER';
    final avatarUrl = member?.avatarUrl;
    final status = member?.status.trim().isNotEmpty == true
        ? member!.status.trim().replaceAll('_', ' ').toUpperCase()
        : 'ACTIVE';
    final isActive = status == 'ACTIVE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: context.isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Biometric Security Identity Photo (Locked to Front-Desk Verification)
          Semantics(
            button: onAvatarTap != null,
            label: 'Biometric Security Photo',
            child: InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [context.brandAccent, context.cardElevated],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.brandAccent.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.startsWith('http')
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildMonogram(fullName, context),
                            )
                          : _buildMonogram(fullName, context),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cardBg, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.verified_user_rounded, size: 11, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 2. Member Name & Passcode Chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isActive ? AppTheme.emerald : context.textMuted)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isActive ? AppTheme.emerald : context.textMuted)
                              .withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.emerald : context.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: isActive ? AppTheme.emerald : context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Copyable Member Passcode Pill
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: memberCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: context.cardElevated,
                        behavior: SnackBarBehavior.floating,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Member code $memberCode copied to clipboard',
                              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.cardElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderCol, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          memberCode,
                          style: GoogleFonts.spaceMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: context.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonogram(String fullName, BuildContext context) {
    return Container(
      color: context.brandAccent.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        _getInitials(fullName),
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppTheme.emerald,
        ),
      ),
    );
  }
}
