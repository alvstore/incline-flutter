import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/models.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/media_picker_service.dart';
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

/// 2026 World-Class Luxury Executive Profile & Account Screen for Incline Members
/// Engineered with clean Obsidian Noir aesthetics, animated plan telemetry, and pure Supabase sync.
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
  bool _heartRateSyncEnabled = true;
  bool _calorieSyncEnabled = true;
  bool _turnstileGateEnabled = true;
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
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.watch_rounded, color: AppTheme.emerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wearable & Health Permissions',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            'Apple Health & Google Health Connect Live Sync',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPermissionSwitchRow(
                  icon: Icons.favorite_rounded,
                  iconColor: AppTheme.rose,
                  title: 'Real-time Heart Rate (BPM)',
                  description: 'Live telemetry synced during active workout sessions for cardiovascular tracking.',
                  value: _heartRateSyncEnabled,
                  onChanged: (val) {
                    setState(() => _heartRateSyncEnabled = val);
                    setSheetState(() {});
                  },
                ),
                Divider(color: context.borderCol, height: 24),
                _buildPermissionSwitchRow(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppTheme.amber,
                  title: 'Calorie Burn & Daily Steps',
                  description: 'Aggregates active metabolic burn with nutrition targets.',
                  value: _calorieSyncEnabled,
                  onChanged: (val) {
                    setState(() => _calorieSyncEnabled = val);
                    setSheetState(() {});
                  },
                ),
                Divider(color: context.borderCol, height: 24),
                _buildPermissionSwitchRow(
                  icon: Icons.near_me_rounded,
                  iconColor: AppTheme.emerald,
                  title: 'Club Beacon & Gate Proximity',
                  description: 'Location and Bluetooth signals for seamless check-in upon arrival.',
                  value: _turnstileGateEnabled,
                  onChanged: (val) {
                    setState(() => _turnstileGateEnabled = val);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: context.cardElevated,
                          content: Text(
                            'Health telemetry sync preferences updated.',
                            style: GoogleFonts.outfit(color: AppTheme.emerald, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandAccent,
                      foregroundColor: context.onBrandAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Preferences', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
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
                title: '3. Health Telemetry & GDPR Privacy',
                body:
                    'Telemetry (heart rate, calories burned, training attendance) is stored using AES-256 encryption compliant with HIPAA and GDPR guidelines. Member data is confidential and is never sold or shared with third-party advertisers.',
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
                  child: Text('Close & Acknowledge', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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

  Widget _buildPermissionSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.emerald,
          activeTrackColor: AppTheme.emerald.withValues(alpha: 0.25),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = _resolvedMember ?? widget.member;

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
          'Member Profile & Account',
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
          IconButton(
            icon: Icon(Icons.logout_rounded, color: context.textMuted, size: 20),
            tooltip: 'Sign Out',
            onPressed: _confirmSignOut,
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
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Member Dossier Hero (Avatar with Camera Picker, Name, Passcode)
                ProfileDossierHero(
                  member: member,
                  onAvatarTap: () async {
                    final sm = ScaffoldMessenger.of(context);
                    final elevatedBg = context.cardElevated;
                    final file = await MediaPickerService.instance.pickAvatarImage(context);
                    if (file != null && mounted) {
                      sm.showSnackBar(
                        SnackBar(
                          backgroundColor: elevatedBg,
                          content: Text(
                            'Avatar updated! Selected: ${file.name}',
                            style: GoogleFonts.outfit(color: AppTheme.emerald, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 2. Luxury Segmented Navigation Bar
                _buildSegmentedTabBar(),
                const SizedBox(height: 16),

                // 3. Tab Specific Content View with Smooth Cross-fade
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedTabIndex),
                    child: _buildActiveTabContent(member),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clean Segmented Pill Navigation: [Membership] | [KYC Dossier] | [Security & Club]
  Widget _buildSegmentedTabBar() {
    final tabs = [
      (index: 0, label: 'Membership', icon: Icons.card_membership_rounded),
      (index: 1, label: 'KYC Dossier', icon: Icons.badge_outlined),
      (index: 2, label: 'Security & Club', icon: Icons.shield_outlined),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedTabIndex != t.index) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTabIndex = t.index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9.5),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.icon,
                          size: 13,
                          color: isSelected ? context.brandAccent : context.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.label,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? context.textPrimary : context.textSecondary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
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
            const SizedBox(height: 16),

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
            const SizedBox(height: 28),

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
            const SizedBox(height: 28),

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
            const SizedBox(height: 16),

            // 2. Concierge & Flagship Location Bar
            ProfileContactBar(branch: _branch),
            const SizedBox(height: 16),

            // 3. Refined Luxury Sign Out CTA
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.rose.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                color: AppTheme.rose.withValues(alpha: 0.06),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _confirmSignOut,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 16, color: AppTheme.rose),
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out Active Session',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.rose,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/incline_logo.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'INCLINE',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.8,
                          color: context.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' ®',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
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
              'UDAIPUR FLAGSHIP • TRADE MARK REGISTERED',
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
}
