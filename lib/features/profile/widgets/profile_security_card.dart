import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/watch_sync_service.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// 2026 World-Class Health Telemetry, Privacy & Sign Out Bento Card
/// Fully adaptive with InclineThemeX design tokens.
class ProfileSecurityCard extends StatelessWidget {
  final VoidCallback onOpenHealthPermissions;
  final VoidCallback onOpenPrivacyCharter;
  final VoidCallback onSignOut;

  const ProfileSecurityCard({
    super.key,
    required this.onOpenHealthPermissions,
    required this.onOpenPrivacyCharter,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
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
                  Icons.security_rounded,
                  color: AppTheme.emerald,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURITY & PRIVACY',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tile 1: Smartwatch Telemetry
          ListenableBuilder(
            listenable: WatchSyncService.instance,
            builder: (ctx, _) {
              final watchSync = WatchSyncService.instance;
              final isConnected = watchSync.data.isConnected;
              return _buildActionRow(
                context: context,
                icon: Icons.watch_rounded,
                iconColor: isConnected ? AppTheme.emerald : context.textMuted,
                title: 'Health Telemetry Sync',
                subtitle: isConnected
                    ? '${watchSync.watchBrand} paired & active'
                    : 'No watch paired • Manual tracking',
                badge: isConnected ? 'PAIRED' : 'UNLINKED',
                onTap: onOpenHealthPermissions,
              );
            },
          ),
          Divider(color: context.borderCol, height: 20),

          // Tile 2: Biometric App Lock (Face ID / Fingerprint)
          FutureBuilder<bool>(
            future: BiometricAuthService.instance.isBiometricLockEnabled(),
            builder: (ctx, snapshot) {
              final enabled = snapshot.data ?? false;
              return _buildActionRow(
                context: context,
                icon: Icons.fingerprint_rounded,
                iconColor: enabled ? AppTheme.emerald : context.textMuted,
                title: 'Biometric App Lock',
                subtitle: enabled ? 'Active on app launch' : 'Disabled (Tap to enable Face ID / Fingerprint)',
                badge: enabled ? 'ENABLED' : 'OFF',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final authenticated = await BiometricAuthService.instance.authenticate(
                    reason: 'Authorize biometric authentication for Incline',
                  );
                  if (authenticated) {
                    await BiometricAuthService.instance.setBiometricLockEnabled(!enabled);
                    (context as Element).markNeedsBuild();
                  }
                },
              );
            },
          ),
          Divider(color: context.borderCol, height: 20),

          // Tile 3: Privacy Charter
          _buildActionRow(
            context: context,
            icon: Icons.shield_outlined,
            iconColor: InclineColors.accentOrange,
            title: 'Data Privacy & Charter',
            subtitle: 'AES-256 encrypted, data never sold',
            badge: 'HIPAA/GDPR',
            onTap: onOpenPrivacyCharter,
          ),
          Divider(color: context.borderCol, height: 20),

          // Tile 4: End Session / Sign Out
          _buildActionRow(
            context: context,
            icon: Icons.logout_rounded,
            iconColor: AppTheme.rose,
            title: 'Sign Out Session',
            subtitle: 'Safely disconnect from this device',
            badge: 'EXIT',
            onTap: () {
              HapticFeedback.heavyImpact();
              onSignOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Text(
                badge,
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded, color: context.textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}
