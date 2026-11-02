import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/native_health_bridge.dart';
import '../../core/services/watch_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import 'attendance_logs_screen.dart';
import 'feedback_screen.dart';
import 'invoices_screen.dart';
import 'member_requests_screen.dart';
import 'widgets/profile_contact_bar.dart';
import 'widgets/profile_dossier_hero.dart';
import 'widgets/profile_plan_bento.dart';
import 'widgets/profile_referral_card.dart';
import 'widgets/profile_registration_details_card.dart';
import 'widgets/profile_security_card.dart';
import 'widgets/profile_services_bento_grid.dart';

/// Member account screen with theme-aware profile, membership, and account sections.
class ProfileScreen extends StatefulWidget {
  final Member? member;
  final VoidCallback onSignOut;
  final Membership? initialMembership;

  const ProfileScreen({
    super.key,
    this.member,
    required this.onSignOut,
    this.initialMembership,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Member? _resolvedMember;
  Membership? _membership;
  Branch? _branch;
  ReferralSettings? _referralSettings;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _resolvedMember = widget.member;
    _membership = widget.initialMembership;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    Member? m = widget.member ?? _resolvedMember;
    if (m == null || m.id.isEmpty) {
      m = await SupabaseService.instance.fetchCurrentMember();
    }
    final memberId = m?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    final branchId = m?.branchId;

    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchActiveMembership(memberId),
        SupabaseService.instance.fetchBranch(branchId),
        SupabaseService.instance.fetchReferralSettings(branchId),
      ]);

      if (mounted) {
        setState(() {
          _resolvedMember = m;
          _membership = (results[0] as Membership?) ?? widget.initialMembership ?? _membership;
          _branch = results[1] as Branch?;
          _referralSettings = results[2] as ReferralSettings?;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] Profile data load notice: $e');
    }
  }

  void _confirmSignOut() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.borderCol, width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.rose, size: 22),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your active Incline member session on this device?',
          style: GoogleFonts.outfit(color: context.textSecondary, height: 1.4, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.instance.signOut();
              widget.onSignOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showHealthPermissionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.brandAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.watch_rounded, color: context.brandAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect health data',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          NativeHealthBridge.instance.activeProvider?.name ?? 'Health provider',
                          style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Incline reads only the categories you approve: steps, active calories, workouts, heart rate, sleep, and HRV. New records appear when your wearable or health app writes them. Incline refreshes while the app is open.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.5,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _connectHealthProvider();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandAccent,
                    foregroundColor: context.onBrandAccent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Choose health access', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectHealthProvider() async {
    final provider = NativeHealthBridge.instance.activeProvider;
    final isAvailable = provider != null && await provider.isAvailable();
    if (!mounted) return;
    if (!isAvailable) {
      final message = provider is AndroidHealthConnectProvider
          ? 'Health Connect is unavailable. Install or update it, then try again.'
          : 'Apple Health is not available on this device.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final granted = await NativeHealthBridge.instance
        .showPermissionsRationaleDialog(context);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health access was not enabled. You can try again in device health settings.')),
      );
      return;
    }
    await WatchSyncService.instance.syncNow();
    if (!mounted) return;
    final data = WatchSyncService.instance.data;
    final hasSamples = data.isConnected && (data.steps >= 0 ||
        data.activeCalories >= 0 ||
        data.workoutMinutes >= 0 ||
        data.heartRate > 0 ||
        data.heartRateVariabilityMs > 0 ||
        (data.sleepHours > 0 && !data.isManualSleep));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasSamples
              ? 'Health access connected. Latest saved records are loaded.'
              : data.isConnected
                  ? 'Health access is available. New records appear when your provider saves them.'
                  : 'Connection request completed. Check device health settings if no records appear.',
        ),
      ),
    );
  }

  void _showPrivacyPolicySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppTheme.emerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms & Conditions & Privacy',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Incline Athletic Club Rules & Data Charter',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTermsSection(
                context: context,
                title: '1. Membership Access & Biometrics',
                body:
                    'Access to Incline facilities is granted strictly to active members holding a valid pass. Touchless biometric optical turnstiles verify admission. Membership passes are personal, non-transferable, and non-refundable once activated.',
              ),
              const SizedBox(height: 12),
              _buildTermsSection(
                context: context,
                title: '2. Contrast Suites & Bookings',
                body:
                    'Cold Plunge, Infrared Sauna, and Recovery Suites require advance slot booking via the Incline Member OS. Facility cancellation deadlines apply to all booked recovery sessions.',
              ),
              const SizedBox(height: 12),
              _buildTermsSection(
                context: context,
                title: '3. Health data & privacy',
                body:
                    'The member app reads health records only for the categories you approve in Apple Health or Health Connect. You can review or revoke that access in your device health settings. Incline reads saved records and does not create health samples.',
              ),
              const SizedBox(height: 12),
              _buildTermsSection(
                context: context,
                title: '4. Invoicing, Taxes & GST',
                body:
                    'Official GST Tax Invoices are issued under Section 31 of CGST Act, 2017 (SAC Code: 999723). All fees once paid are non-refundable as per the Incline Club Charter.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brandAccent,
                    side: BorderSide(color: context.brandAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection({
    required BuildContext context,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.outfit(fontSize: 11.5, color: context.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = _resolvedMember ?? widget.member;
    final tabContent = _buildActiveTabContent(member);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutePaths.home);
            }
          },
          tooltip: 'Back to Home',
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: context.brandAccent,
              size: 20,
            ),
            tooltip: context.isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              HapticFeedback.mediumImpact();
              ThemeController.instance.toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          color: AppTheme.emerald,
          backgroundColor: context.cardElevated,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Member Dossier Hero (Biometric Access ID, Name, Passcode)
                ProfileDossierHero(
                  member: member,
                  onAvatarTap: () => _showBiometricPhotoSecuritySheet(context),
                ),
                const SizedBox(height: 14),

                // 2. Luxury Segmented Navigation Bar
                _buildSegmentedTabBar(),
                const SizedBox(height: 14),

                // Tab transitions stay subtle and respect the system's reduced-motion setting.
                if (disableAnimations)
                  KeyedSubtree(
                    key: ValueKey<int>(_selectedTabIndex),
                    child: tabContent,
                  )
                else
                  tabContent
                      .animate(key: ValueKey<int>(_selectedTabIndex))
                      .fadeIn(duration: 220.ms, curve: Curves.easeOutCubic)
                      .slideY(
                        begin: 0.02,
                        end: 0,
                        duration: 220.ms,
                        curve: Curves.easeOutCubic,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact, clearly labeled navigation for profile sections.
  Widget _buildSegmentedTabBar() {
    final tabs = [
      (index: 0, label: 'Membership'),
      (index: 1, label: 'Personal'),
      (index: 2, label: 'Account'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.borderCol.withValues(alpha: context.isDark ? 0.7 : 0.8),
          width: 1.0,
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _selectedTabIndex == t.index;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: t.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (_selectedTabIndex != t.index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTabIndex = t.index);
                  }
                },
                child: AnimatedContainer(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : 200.ms,
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (context.isDark ? context.cardElevated : context.scaffoldBg)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: context.brandAccent.withValues(alpha: 0.35),
                            width: 1.0,
                          )
                        : Border.all(color: Colors.transparent, width: 1.0),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? context.textPrimary : context.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Renders dedicated content by user intent without vertical monolith clutter
  Widget _buildActiveTabContent(Member? member) {
    switch (_selectedTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Animated Plan Bento (Days Left & Date of Joining)
            ProfilePlanBento(membership: _membership),
            const SizedBox(height: 14),

            // 2. 2x2 Member Services Grid (Invoices, Attendance, Requests, Feedback)
            ProfileServicesBentoGrid(
              onOpenInvoices: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoicesScreen(
                      member: member,
                      branch: _branch,
                    ),
                  ),
                );
              },
              onOpenAttendance: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceLogsScreen(
                      member: member,
                    ),
                  ),
                );
              },
              onOpenRequests: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberRequestsScreen(
                      member: member,
                    ),
                  ),
                );
              },
              onOpenFeedback: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. Referral Privileges Card
            ProfileReferralCard(
              member: member,
              rewardsEnabled: _referralSettings?.isEnabled ?? false,
            ),
            const SizedBox(height: 24),

            // Trademark Registered Brand Footer
            _buildBrandFooter(context),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Certified KYC Dossier & Self-Service Correspondence Form Card
            ProfileRegistrationDetailsCard(
              member: member,
              onProfileUpdated: (updatedProf) {
                setState(() {
                  _resolvedMember = (member ?? widget.member)?.copyWith(
                    profile: updatedProf,
                  );
                });
              },
            ),
            const SizedBox(height: 24),

            // Trademark Registered Brand Footer
            _buildBrandFooter(context),
          ],
        );

      case 2:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Security & Health Telemetry Card
            ProfileSecurityCard(
              onOpenHealthPermissions: _showHealthPermissionsSheet,
              onOpenPrivacyCharter: _showPrivacyPolicySheet,
              onSignOut: _confirmSignOut,
            ),
            const SizedBox(height: 14),

            // 2. Concierge & Club Location Bar
            ProfileContactBar(branch: _branch),
            const SizedBox(height: 24),

            // Trademark Registered Brand Footer
            _buildBrandFooter(context),
          ],
        );
    }
  }

  /// Official Incline Brand Tagline Footer
  Widget _buildBrandFooter(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INCLINE',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.8,
                    color: context.textPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3, top: 1),
                  child: Text(
                    '®',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'RISE • REFLECT • REPEAT',
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: AppTheme.emerald,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${(_branch?.city.isNotEmpty == true ? _branch!.city : _branch?.name ?? "INCLINE CLUB").toUpperCase()} • MEMBER ACCOUNT',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Informs members of club physical security policy regarding biometric turnstile photos.
  void _showBiometricPhotoSecuritySheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                'Biometric Turnstile Identity',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your profile photo is synchronized with Incline\'s optical turnstiles and MIPS biometric access gates. To maintain facility safety and prevent pass sharing, member photos cannot be altered from mobile devices.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.45,
                  color: context.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderCol, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'To update your facial ID photo, please speak with the front desk concierge during your next visit.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Understood',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
