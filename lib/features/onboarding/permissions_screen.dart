import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/native_health_bridge.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// Permissions and telemetry choices for Incline app launch.
/// - Explicit user opt-in before requesting system-level permissions
/// - Granular controls for Location, Health, Notifications, and Camera
/// - Graceful fallback to App Settings if permissions were previously denied
class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  bool _proximityEnabled = true;
  bool _biometricsEnabled = true;
  bool _notificationsEnabled = true;
  bool _cameraEnabled = true;
  bool _isSubmitting = false;

  /// Requests native system permissions based on user selections
  Future<void> _grantPermissionsAndProceed() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Notifications (Android 13+ POST_NOTIFICATIONS & iOS APNs/Local)
      if (_notificationsEnabled && !kIsWeb) {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await Permission.notification.request();
        }
        await PushNotificationService.instance.init();
      }

      // 2. Proximity & Turnstile Access (Location When In Use & Bluetooth)
      if (_proximityEnabled && !kIsWeb) {
        final locStatus = await Permission.locationWhenInUse.status;
        if (!locStatus.isGranted) {
          await Permission.locationWhenInUse.request();
        }

        // Bluetooth permissions on modern platforms
        if (Platform.isAndroid) {
          final bluetoothScan = await Permission.bluetoothScan.status;
          if (!bluetoothScan.isGranted) {
            await [
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
            ].request();
          }
        }
      }

      // 3. Camera (InBody Scans & Member Verification)
      if (_cameraEnabled && !kIsWeb) {
        final camStatus = await Permission.camera.status;
        if (!camStatus.isGranted) {
          await Permission.camera.request();
        }
      }

      // 4. Biometrics, Activity & Health Telemetry
      if (_biometricsEnabled && !kIsWeb) {
        if (Platform.isAndroid) {
          final activityStatus = await Permission.activityRecognition.status;
          if (!activityStatus.isGranted) {
            await Permission.activityRecognition.request();
          }
          final sensorsStatus = await Permission.sensors.status;
          if (!sensorsStatus.isGranted) {
            await Permission.sensors.request();
          }
        }
        await NativeHealthBridge.instance.requestPermissions();
      }

      // 5. Persist Member Choices
      AppRouter.hasGrantedPermissions = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_granted_permissions', true);
      await prefs.setBool('seen_onboarding', true);
      await prefs.setBool('perm_proximity', _proximityEnabled);
      await prefs.setBool('perm_biometrics', _biometricsEnabled);
      await prefs.setBool('perm_notifications', _notificationsEnabled);
      await prefs.setBool('perm_camera', _cameraEnabled);

      if (mounted) {
        if (SupabaseService.instance.isAuthenticated) {
          context.go(AppRoutePaths.home);
        } else {
          context.go(AppRoutePaths.login);
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] Permission request error: $e');
      if (mounted) {
        AppRouter.hasGrantedPermissions = true;
        if (SupabaseService.instance.isAuthenticated) {
          context.go(AppRoutePaths.home);
        } else {
          context.go(AppRoutePaths.login);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Skip and proceed to home screen (Apple Guideline 5.1.1 compliance)
  Future<void> _skipAndProceed() async {
    HapticFeedback.lightImpact();
    AppRouter.hasGrantedPermissions = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_granted_permissions', true);
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      if (SupabaseService.instance.isAuthenticated) {
        context.go(AppRoutePaths.home);
      } else {
        context.go(AppRoutePaths.login);
      }
    }
  }

  void _showPrivacyDisclosure() {
    showModalBottomSheet(
      context: context,
      backgroundColor: InclineColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: InclineColors.accentOrange, size: 24),
                const SizedBox(width: 10),
                Text(
                  '2026 Privacy Charter',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Incline Club enforces stringent zero-knowledge and on-device telemetry protocols:\n\n'
              '• Location is used strictly while using the app to unlock turnstile gates at Incline Udaipur.\n'
              '• Health metrics (steps, heart rate, calories) stay local to your session logs and Apple Health / Google Health Connect.\n'
              '• Camera access is used solely for member identity badges and HowBody 3D posture reports.\n'
              '• Zero telemetry is sold, brokered, or transferred to third-party ad networks.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.55,
                color: InclineColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: InclineColors.accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'UNDERSTOOD',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
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
    return Scaffold(
      backgroundColor: InclineColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // 1. Incline Trademark Brand Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/incline_logo.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'INCLINE',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: ' ®',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: InclineColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF0441C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x33F0441C)),
                    ),
                    child: Text(
                      'STEP 2 OF 2',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: InclineColors.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 2. Title & Subtitle
              Text(
                'Member Telemetry & Permissions',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Activate instant turnstile access, cardiovascular biometric syncing, and private concierge reminders with 2026 privacy compliance.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: InclineColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 3. Permission Tile 1: Turnstile & Proximity (Location & BLE)
              _buildPermissionCard(
                icon: Icons.near_me_rounded,
                iconColor: InclineColors.accentOrange,
                badge: 'GATE & CLUB ENTRY',
                title: 'Turnstile & Proximity',
                description: 'Foreground location and BLE beacons for automated turnstile gate pass check-in at Incline Udaipur.',
                value: _proximityEnabled,
                onChanged: (val) => setState(() => _proximityEnabled = val),
              ),
              const SizedBox(height: 12),

              // 4. Permission Tile 2: Health & Biometrics
              _buildPermissionCard(
                icon: Icons.favorite_rounded,
                iconColor: AppTheme.rose,
                badge: 'LIVE WORKOUT TELEMETRY',
                title: 'Biometrics & Wearables',
                description: 'Live sync with Apple HealthKit or Google Health Connect for steps, cardiovascular load, and active calories.',
                value: _biometricsEnabled,
                onChanged: (val) => setState(() => _biometricsEnabled = val),
              ),
              const SizedBox(height: 12),

              // 5. Permission Tile 3: Notifications & Reminders
              _buildPermissionCard(
                icon: Icons.notifications_active_rounded,
                iconColor: AppTheme.amber,
                badge: 'CONCIERGE & BOOKINGS',
                title: 'Club & Suite Alerts',
                description: 'Instant updates for confirmed Cold Plunge & Sauna suites, missed workout reminders, and coach cues.',
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
              const SizedBox(height: 12),

              // 6. Permission Tile 4: Camera & InBody Scans
              _buildPermissionCard(
                icon: Icons.camera_alt_rounded,
                iconColor: InclineColors.thermalAmber,
                badge: 'DIAGNOSTICS & IDENTITY',
                title: 'Camera & Body Scans',
                description: 'Required for HowBody 3D posture report imports and member security avatar photos.',
                value: _cameraEnabled,
                onChanged: (val) => setState(() => _cameraEnabled = val),
              ),
              const SizedBox(height: 28),

              // 7. Primary Action CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _grantPermissionsAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InclineColors.accentOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: const Color(0x66F0441C),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ACTIVATE TELEMETRY & ENTER CLUB',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // 8. Secondary Actions
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : _skipAndProceed,
                    child: Text(
                      'Review Later in Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: InclineColors.textSecondary,
                      ),
                    ),
                  ),
                  const Text('•', style: TextStyle(color: InclineColors.textMuted)),
                  TextButton(
                    onPressed: _showPrivacyDisclosure,
                    child: Text(
                      'Privacy Charter',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: InclineColors.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 9. Privacy Charter Micro-Badge
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: InclineColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'You can review or change these permissions in device settings.',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: InclineColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: InclineColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? iconColor.withValues(alpha: 0.35) : InclineColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: InclineColors.accentOrange,
                activeTrackColor: const Color(0x33F0441C),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: InclineColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
