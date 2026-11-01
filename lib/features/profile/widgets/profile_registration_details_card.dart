import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

/// 2026 World-Class Member Registration Dossier Card & KYC Synchronization Form
///
/// Designed with an ultra-clean, minimal modern luxury aesthetic for Incline Wellness Club.
/// Authoritative admission records (Legal Name, Phone, Aadhaar, DOB, Emergency Contact)
/// represent certified admission KYC locked in the backend.
/// Correspondence fields (Email, Street Address, City, State, PIN) are member-editable.
class ProfileRegistrationDetailsCard extends StatefulWidget {
  final Member? member;
  final ValueChanged<Profile>? onProfileUpdated;

  const ProfileRegistrationDetailsCard({
    super.key,
    required this.member,
    this.onProfileUpdated,
  });

  @override
  State<ProfileRegistrationDetailsCard> createState() =>
      _ProfileRegistrationDetailsCardState();
}

class _ProfileRegistrationDetailsCardState
    extends State<ProfileRegistrationDetailsCard> {
  bool _showFullAadhaar = false;
  late Profile? _localProfile;

  @override
  void initState() {
    super.initState();
    _localProfile = widget.member?.profile;
  }

  @override
  void didUpdateWidget(ProfileRegistrationDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.member?.profile != oldWidget.member?.profile) {
      _localProfile = widget.member?.profile;
    }
  }

  Profile? get _profile => _localProfile ?? widget.member?.profile;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // Resolves formatted Aadhaar string (masked vs unmasked)
  String _formatAadhaar(String raw, bool showFull) {
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return 'Not Provided';

    if (showFull) {
      final buffer = StringBuffer();
      for (int i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(clean[i]);
      }
      return buffer.toString();
    } else {
      if (clean.length >= 12) {
        final last4 = clean.substring(clean.length - 4);
        return 'XXXX  XXXX  $last4';
      } else if (clean.length >= 4) {
        final last4 = clean.substring(clean.length - 4);
        return 'XXXX  $last4';
      }
      return clean;
    }
  }

  void _callEmergencyContact(String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleanPhone.isEmpty || cleanPhone == 'NotProvided') {
      _showToast(
        icon: Icons.info_outline_rounded,
        iconColor: AppTheme.amber,
        message: 'No emergency phone number available',
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Clipboard.setData(ClipboardData(text: cleanPhone));
        if (mounted) {
          _showToast(
            icon: Icons.copy_rounded,
            iconColor: AppTheme.rose,
            message: 'Emergency phone $phone copied to clipboard',
          );
        }
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: cleanPhone));
      if (mounted) {
        _showToast(
          icon: Icons.copy_rounded,
          iconColor: AppTheme.rose,
          message: 'Emergency phone $phone copied',
        );
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: value));
    _showToast(
      icon: Icons.check_circle_rounded,
      iconColor: AppTheme.emerald,
      message: '$label copied to clipboard',
    );
  }

  void _showToast({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.cardElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: context.borderCol.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: context.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }

  void _openEditSheet() {
    HapticFeedback.mediumImpact();
    final currentProf = _profile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => _EditProfileFormSheet(
        profile: currentProf,
        member: widget.member,
        onSave: (updated) {
          setState(() {
            _localProfile = updated;
          });
          widget.onProfileUpdated?.call(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prof = _profile;
    final isPreview = widget.member == null && prof == null;

    final rawPhone = prof?.phone?.trim();
    final rawEmail = prof?.email?.trim();
    final rawAadhaar = prof?.governmentIdNumber?.trim();
    final rawEmergName = prof?.emergencyContactName?.trim();
    final rawEmergPhone = prof?.emergencyContactPhone?.trim();

    final fullName = prof?.fullName ?? widget.member?.fullName ?? (isPreview ? 'Incline Member' : 'Member');
    final memberCode = widget.member?.memberCode ?? (isPreview ? 'INC-26-0001' : 'INC-MEMBER');
    final phone = (rawPhone != null && rawPhone.isNotEmpty)
        ? rawPhone
        : (isPreview ? '+91 99999 99999' : 'Not Provided');
    final email = (rawEmail != null && rawEmail.isNotEmpty)
        ? rawEmail
        : (isPreview ? 'member@theincline.in' : 'Not Provided');
    final dobStr = prof?.formattedDob ?? (isPreview ? '01 Jan 1995' : 'Not Provided');
    final ageStr = prof?.age != null
        ? '${prof!.age} Years'
        : (isPreview ? '31 Years' : 'Not Provided');
    final addressStr = (prof != null && prof.formattedAddress.isNotEmpty && prof.formattedAddress != 'Not Provided')
        ? prof.formattedAddress
        : (isPreview
            ? 'Plot 44-55, Near Kheda Circle, Hiran Magri Sector 14, Udaipur, Rajasthan 313001'
            : 'Not Provided');
    final aadhaarRaw = (rawAadhaar != null && rawAadhaar.isNotEmpty)
        ? rawAadhaar
        : (isPreview ? '999999999999' : '');
    final formattedAadhaar = _formatAadhaar(aadhaarRaw, _showFullAadhaar);
    final emergName = (rawEmergName != null && rawEmergName.isNotEmpty)
        ? rawEmergName
        : (isPreview ? 'Emergency Contact' : 'Not Provided');
    final emergPhone = (rawEmergPhone != null && rawEmergPhone.isNotEmpty)
        ? rawEmergPhone
        : (isPreview ? '+91 98888 88888' : '');

    final String emergDisplay;
    if (emergName != 'Not Provided' && emergPhone.isNotEmpty) {
      emergDisplay = '$emergName • $emergPhone';
    } else if (emergName != 'Not Provided') {
      emergDisplay = emergName;
    } else if (emergPhone.isNotEmpty) {
      emergDisplay = emergPhone;
    } else {
      emergDisplay = 'Not Provided';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.borderCol.withValues(alpha: context.isDark ? 0.7 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dossier Header Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Tag Pill with glowing emerald indicator
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.5,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.emerald.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                color: AppTheme.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'OFFICIAL KYC DOSSIER',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Member Registration Dossier',
                      style: GoogleFonts.outfit(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: context.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Authoritative KYC & correspondence record',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Refined Minimal Edit Button
              InkWell(
                onTap: _openEditSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.brandAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: context.brandAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Edit',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: context.brandAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Member Identity & Code Quick Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: context.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.borderCol.withValues(alpha: 0.6),
                width: 0.9,
              ),
            ),
            child: Row(
              children: [
                // Executive Monogram Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        context.brandAccent.withValues(alpha: 0.22),
                        context.brandAccent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: context.brandAccent.withValues(alpha: 0.35),
                      width: 1.1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(fullName),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: context.brandAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 11.5,
                            color: AppTheme.emerald,
                          ),
                          const SizedBox(width: 4.5),
                          Expanded(
                            child: Text(
                              'Verified Admission Identity',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Member Code Tap-to-Copy Pill
                InkWell(
                  onTap: () => _copyToClipboard('Member code', memberCode),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.5,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.borderCol.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          memberCode,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: context.brandAccent,
                          ),
                        ),
                        const SizedBox(width: 4.5),
                        Icon(
                          Icons.copy_rounded,
                          size: 11,
                          color: context.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Section: OFFICIAL KYC RECORDS (Locked & Certified)
          _buildSectionHeader(
            context: context,
            icon: Icons.lock_outline_rounded,
            title: 'OFFICIAL KYC RECORDS',
            badge: 'LOCKED',
            badgeColor: context.goldAccent,
          ),

          const SizedBox(height: 10),

          // Row 1: Primary Phone & Govt ID (Aadhaar)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBentoTile(
                  context: context,
                  icon: Icons.phone_android_rounded,
                  iconColor: context.brandAccent,
                  label: 'PRIMARY PHONE',
                  value: phone,
                  trailingBadge: 'VERIFIED',
                  badgeColor: AppTheme.emerald,
                  onCopy: phone != 'Not Provided'
                      ? () => _copyToClipboard('Phone number', phone)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoTile(
                  context: context,
                  icon: Icons.credit_card_rounded,
                  iconColor: AppTheme.emerald,
                  label: 'GOVT ID (AADHAAR)',
                  value: formattedAadhaar,
                  trailingBadge: 'SECURE',
                  badgeColor: AppTheme.emerald,
                  trailingAction: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (aadhaarRaw.isNotEmpty) ...[
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _showFullAadhaar = !_showFullAadhaar);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: Icon(
                              _showFullAadhaar
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 14.5,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            'Aadhaar number',
                            _formatAadhaar(aadhaarRaw, true),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 12.5,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Date of Birth & Dynamically Calculated Age
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBentoTile(
                  context: context,
                  icon: Icons.cake_outlined,
                  iconColor: InclineColors.thermalRed,
                  label: 'DATE OF BIRTH',
                  value: dobStr,
                  subtitle: 'Official age record',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoTile(
                  context: context,
                  icon: Icons.hourglass_top_rounded,
                  iconColor: InclineColors.thermalAmber,
                  label: 'CALCULATED AGE',
                  value: ageStr,
                  trailingBadge: 'ACTIVE',
                  badgeColor: AppTheme.emerald,
                  subtitle: 'Chronological metric',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 3: Primary Emergency Contact (with copy & call actions)
          _buildBentoTile(
            context: context,
            icon: Icons.emergency_outlined,
            iconColor: AppTheme.rose,
            label: 'PRIMARY EMERGENCY CONTACT',
            value: emergDisplay,
            subtitle: 'Certified next of kin for urgent medical response',
            trailingAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emergPhone.isNotEmpty || emergName != 'Not Provided') ...[
                  InkWell(
                    onTap: () => _copyToClipboard(
                      'Emergency contact',
                      emergPhone.isNotEmpty
                          ? (emergName != 'Not Provided'
                              ? '$emergName: $emergPhone'
                              : emergPhone)
                          : emergName,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(3.5),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
                if (emergPhone.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _callEmergencyContact(emergPhone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.5,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.rose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.rose.withValues(alpha: 0.35),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.call_rounded,
                            color: AppTheme.rose,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Call',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.rose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 4. Section: CORRESPONDENCE & RESIDENTIAL DOSSIER (Member Maintained)
          _buildSectionHeader(
            context: context,
            icon: Icons.home_work_outlined,
            title: 'RESIDENTIAL & CORRESPONDENCE',
            badge: 'SELF-SERVICE',
            badgeColor: context.brandAccent,
          ),

          const SizedBox(height: 10),

          // Registered Email Tile
          _buildBentoTile(
            context: context,
            icon: Icons.alternate_email_rounded,
            iconColor: InclineColors.accentOrange,
            label: 'REGISTERED EMAIL',
            value: email,
            subtitle: 'Direct billing & club dispatch notifications',
            onCopy: email != 'Not Provided'
                ? () => _copyToClipboard('Email', email)
                : null,
          ),

          const SizedBox(height: 8),

          // Residential Address Tile
          _buildBentoTile(
            context: context,
            icon: Icons.location_on_outlined,
            iconColor: InclineColors.accentOrange,
            label: 'RESIDENTIAL ADDRESS',
            value: addressStr,
            valueMaxLines: 2,
            subtitle: 'Official correspondence location',
            onCopy: addressStr != 'Not Provided'
                ? () => _copyToClipboard('Address', addressStr)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: context.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4.5),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            badge,
            maxLines: 1,
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtitle,
    String? trailingBadge,
    Color? badgeColor,
    Widget? trailingAction,
    VoidCallback? onCopy,
    int valueMaxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.borderCol.withValues(alpha: 0.6),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label Row with Icon & optional Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? context.brandAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trailingBadge,
                    style: GoogleFonts.outfit(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: badgeColor ?? context.brandAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          // Value Row with trailingAction / copy button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailingAction != null) ...[
                const SizedBox(width: 4),
                trailingAction,
              ],
              if (onCopy != null && trailingAction == null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                color: context.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet allowing members to view official KYC and update self-service records
class _EditProfileFormSheet extends StatefulWidget {
  final Profile? profile;
  final Member? member;
  final ValueChanged<Profile> onSave;

  const _EditProfileFormSheet({
    required this.profile,
    required this.member,
    required this.onSave,
  });

  @override
  State<_EditProfileFormSheet> createState() => _EditProfileFormSheetState();
}

class _EditProfileFormSheetState extends State<_EditProfileFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Member-editable controllers
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _postalCodeCtrl;

  // Official KYC state (read-only in backend)
  late String _officialFullName;
  late String _officialPhone;
  late String _officialAadhaar;
  late String _officialEmergencyName;
  late String _officialEmergencyPhone;
  late String _memberCode;
  DateTime? _selectedDob;

  bool _isSaving = false;
  bool _sheetShowFullAadhaar = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final m = widget.member;
    final isPreview = m == null && p == null;

    final rawPhone = p?.phone?.trim();
    final rawAadhaar = p?.governmentIdNumber?.trim();
    final rawEmergName = p?.emergencyContactName?.trim();
    final rawEmergPhone = p?.emergencyContactPhone?.trim();
    final rawEmail = p?.email?.trim();
    final rawAddress = p?.address?.trim();
    final rawCity = p?.city?.trim();
    final rawState = p?.state?.trim();
    final rawPostalCode = p?.postalCode?.trim();

    _officialFullName = p?.fullName ?? m?.fullName ?? (isPreview ? 'Incline Member' : 'Member');
    _officialPhone = (rawPhone != null && rawPhone.isNotEmpty)
        ? rawPhone
        : (isPreview ? '+91 99999 99999' : 'Not Provided');
    _officialAadhaar = (rawAadhaar != null && rawAadhaar.isNotEmpty)
        ? rawAadhaar
        : (isPreview ? '999999999999' : '');
    _officialEmergencyName = (rawEmergName != null && rawEmergName.isNotEmpty)
        ? rawEmergName
        : (isPreview ? 'Emergency Contact' : 'Not Provided');
    _officialEmergencyPhone = (rawEmergPhone != null && rawEmergPhone.isNotEmpty)
        ? rawEmergPhone
        : (isPreview ? '+91 98888 88888' : '');
    _memberCode = m?.memberCode ?? (isPreview ? 'INC-26-0001' : 'INC-MEMBER');
    _selectedDob = p?.dateOfBirth ?? (isPreview ? DateTime(1995, 1, 1) : null);

    _emailCtrl = TextEditingController(
        text: (rawEmail != null && rawEmail.isNotEmpty)
            ? rawEmail
            : (isPreview ? 'member@theincline.in' : ''));
    _addressCtrl = TextEditingController(
        text: (rawAddress != null && rawAddress.isNotEmpty)
            ? rawAddress
            : (isPreview
                ? 'Indiranagar 100ft Road'
                : ''));
    _cityCtrl = TextEditingController(
        text: (rawCity != null && rawCity.isNotEmpty)
            ? rawCity
            : (isPreview ? 'Bengaluru' : ''));
    _stateCtrl = TextEditingController(
        text: (rawState != null && rawState.isNotEmpty)
            ? rawState
            : (isPreview ? 'Karnataka' : ''));
    _postalCodeCtrl = TextEditingController(
        text: (rawPostalCode != null && rawPostalCode.isNotEmpty)
            ? rawPostalCode
            : (isPreview ? '560038' : ''));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  int? get _previewAge {
    if (_selectedDob == null) return null;
    final now = DateTime.now();
    int a = now.year - _selectedDob!.year;
    if (now.month < _selectedDob!.month ||
        (now.month == _selectedDob!.month && now.day < _selectedDob!.day)) {
      a--;
    }
    return a >= 0 ? a : null;
  }

  String _formatAadhaarDisplay(String raw, bool showFull) {
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return 'Not Provided';
    if (showFull) {
      final buffer = StringBuffer();
      for (int i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(clean[i]);
      }
      return buffer.toString();
    } else {
      final last4 =
          clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
      return 'XXXX  XXXX  $last4';
    }
  }

  Future<void> _submitSave() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final profileId = widget.profile?.id ??
        widget.member?.profile?.id ??
        widget.member?.id ??
        SupabaseService.instance.currentUser?.id ??
        '';

    Profile? updated;
    try {
      if (profileId.isNotEmpty) {
        updated = await SupabaseService.instance.updateMemberProfile(
          profileId: profileId,
          fullName: _officialFullName,
          phone: _officialPhone != 'Not Provided' ? _officialPhone : null,
          email: _emailCtrl.text.trim(),
          dateOfBirth: _selectedDob,
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim(),
          postalCode: _postalCodeCtrl.text.trim(),
          governmentIdNumber:
              _officialAadhaar.isNotEmpty ? _officialAadhaar : null,
          governmentIdType: 'aadhaar',
          emergencyContactName: _officialEmergencyName != 'Not Provided'
              ? _officialEmergencyName
              : null,
          emergencyContactPhone: _officialEmergencyPhone.isNotEmpty
              ? _officialEmergencyPhone
              : null,
        );
      }
    } catch (e) {
      debugPrint('[INCLINE] Update member profile error: $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final finalProfile = updated ??
        (widget.profile?.copyWith(
              fullName: _officialFullName,
              phone: _officialPhone != 'Not Provided'
                  ? _officialPhone
                  : widget.profile?.phone,
              email: _emailCtrl.text.trim(),
              dateOfBirth: _selectedDob,
              address: _addressCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              state: _stateCtrl.text.trim(),
              postalCode: _postalCodeCtrl.text.trim(),
              governmentIdNumber: _officialAadhaar.isNotEmpty
                  ? _officialAadhaar
                  : widget.profile?.governmentIdNumber,
              emergencyContactName:
                  _officialEmergencyName != 'Not Provided'
                      ? _officialEmergencyName
                      : widget.profile?.emergencyContactName,
              emergencyContactPhone: _officialEmergencyPhone.isNotEmpty
                  ? _officialEmergencyPhone
                  : widget.profile?.emergencyContactPhone,
            ) ??
            Profile(
              id: profileId.isNotEmpty
                  ? profileId
                  : 'profile_${DateTime.now().millisecondsSinceEpoch}',
              fullName: _officialFullName,
              phone: _officialPhone != 'Not Provided' ? _officialPhone : null,
              email: _emailCtrl.text.trim(),
              dateOfBirth: _selectedDob,
              address: _addressCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              state: _stateCtrl.text.trim(),
              postalCode: _postalCodeCtrl.text.trim(),
              governmentIdNumber:
                  _officialAadhaar.isNotEmpty ? _officialAadhaar : null,
              emergencyContactName: _officialEmergencyName != 'Not Provided'
                  ? _officialEmergencyName
                  : null,
              emergencyContactPhone: _officialEmergencyPhone.isNotEmpty
                  ? _officialEmergencyPhone
                  : null,
            ));

    widget.onSave(finalProfile);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: context.cardElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: context.borderCol.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.emerald,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registration details updated & synchronized!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: AppTheme.emerald,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dobFormatted = _selectedDob != null
        ? DateFormat('d MMM yyyy').format(_selectedDob!)
        : 'Not Set';
    final ageText = _previewAge != null ? '$_previewAge Yrs' : '29 Yrs';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollCtrl,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.borderCol.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEMBER REGISTRATION DOSSIER',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: context.brandAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update Registration Details',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textMuted,
                      size: 22,
                    ),
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // KYC Security Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.borderCol.withValues(alpha: 0.7),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.brandAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: context.brandAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authoritative KYC Protected',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2.5),
                          Text(
                            'Legal name, primary mobile, Aadhaar ID, and emergency contacts are certified club KYC records. Contact the club desk to amend official admission records.',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: context.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Group 1: Official KYC Records (Read-Only)
              Row(
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: context.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'OFFICIAL KYC RECORDS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.goldAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: context.goldAccent.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 9,
                            color: context.goldAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Official KYC • Read Only',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: context.goldAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Locked Tiles Grid
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderCol.withValues(alpha: 0.7),
                    width: 0.9,
                  ),
                ),
                child: Column(
                  children: [
                    // Legal Name & Member Code
                    _buildLockedItem(
                      icon: Icons.person_outline_rounded,
                      label: 'LEGAL FULL NAME',
                      value: _officialFullName,
                      extra: Text(
                        _memberCode,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: context.brandAccent,
                        ),
                      ),
                    ),
                    Divider(
                      color: context.borderCol.withValues(alpha: 0.6),
                      height: 18,
                    ),

                    // Primary Phone
                    _buildLockedItem(
                      icon: Icons.phone_android_rounded,
                      label: 'PRIMARY MOBILE',
                      value: _officialPhone,
                      extra: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'VERIFIED',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      color: context.borderCol.withValues(alpha: 0.6),
                      height: 18,
                    ),

                    // Aadhaar Govt ID with toggle
                    _buildLockedItem(
                      icon: Icons.credit_card_rounded,
                      label: 'GOVT ID (AADHAAR)',
                      value: _formatAadhaarDisplay(
                        _officialAadhaar,
                        _sheetShowFullAadhaar,
                      ),
                      extra: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(
                            () =>
                                _sheetShowFullAadhaar = !_sheetShowFullAadhaar,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _sheetShowFullAadhaar
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 14,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      color: context.borderCol.withValues(alpha: 0.6),
                      height: 18,
                    ),

                    // Date of Birth & Age (Read-only official record)
                    _buildLockedItem(
                      icon: Icons.cake_outlined,
                      label: 'DATE OF BIRTH & AGE',
                      value: '$dobFormatted ($ageText)',
                      extra: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.goldAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOCKED',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: context.goldAccent,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      color: context.borderCol.withValues(alpha: 0.6),
                      height: 18,
                    ),

                    // Emergency Contact
                    _buildLockedItem(
                      icon: Icons.emergency_outlined,
                      label: 'EMERGENCY NEXT OF KIN',
                      value:
                          '$_officialEmergencyName • $_officialEmergencyPhone',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Group 2: Self-Service Editable Fields
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 15,
                    color: context.brandAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SELF-SERVICE EDITABLE FIELDS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: context.brandAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.emerald.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Direct Supabase Sync',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Editable Email
              _buildTextField(
                label: 'PERSONAL EMAIL ADDRESS',
                controller: _emailCtrl,
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Editable Street Address
              _buildTextField(
                label: 'RESIDENTIAL STREET ADDRESS',
                controller: _addressCtrl,
                icon: Icons.home_outlined,
                keyboardType: TextInputType.streetAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Residential address required'
                    : null,
              ),

              const SizedBox(height: 12),

              // City & State
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'CITY',
                      controller: _cityCtrl,
                      icon: Icons.location_city_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'City' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      label: 'STATE',
                      controller: _stateCtrl,
                      icon: Icons.map_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'State' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // PIN Code
              _buildTextField(
                label: 'PIN CODE',
                controller: _postalCodeCtrl,
                icon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) => (v == null || v.trim().length < 6)
                    ? '6 digits'
                    : null,
              ),

              const SizedBox(height: 22),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandAccent,
                    foregroundColor: context.onBrandAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: context.onBrandAccent,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sync_rounded, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Save & Synchronize Dossier',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedItem({
    required IconData icon,
    required String label,
    required String value,
    Widget? extra,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.textMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (extra != null) extra,
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.textPrimary,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.textMuted,
        ),
        prefixIcon: Icon(icon, size: 16, color: context.brandAccent),
        counterText: '',
        filled: true,
        fillColor: context.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.borderCol.withValues(alpha: 0.7),
            width: 0.9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.brandAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.rose, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.5),
        ),
      ),
    );
  }
}

/// Interactive Widget Previews for Developer & Hot-Preview Verification
///
/// Use these functions to inspect ProfileRegistrationDetailsCard in Dark & Light modes.
Widget previewProfileRegistrationDetailsCardDark() {
  final member = Member(
    id: '00000000-0000-0000-0000-000000000001',
    branchId: 'b1',
    memberCode: 'INC-26-0001',
    status: 'active',
    profile: Profile(
      id: '00000000-0000-0000-0000-000000000001',
      fullName: 'Incline Member',
      phone: '+91 99999 99999',
      email: 'member@theincline.in',
      dateOfBirth: DateTime(1995, 1, 1),
      address: 'Indiranagar 100ft Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      postalCode: '560038',
      governmentIdNumber: 'XXXXXXXX9999',
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '+91 98888 88888',
    ),
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    home: Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ProfileRegistrationDetailsCard(
            member: member,
            onProfileUpdated: (_) {},
          ),
        ),
      ),
    ),
  );
}

Widget previewProfileRegistrationDetailsCardLight() {
  final member = Member(
    id: '00000000-0000-0000-0000-000000000001',
    branchId: 'b1',
    memberCode: 'INC-26-0001',
    status: 'active',
    profile: Profile(
      id: '00000000-0000-0000-0000-000000000001',
      fullName: 'Incline Member',
      phone: '+91 99999 99999',
      email: 'member@theincline.in',
      dateOfBirth: DateTime(1995, 1, 1),
      address: 'Indiranagar 100ft Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      postalCode: '560038',
      governmentIdNumber: 'XXXXXXXX9999',
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '+91 98888 88888',
    ),
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ProfileRegistrationDetailsCard(
            member: member,
            onProfileUpdated: (_) {},
          ),
        ),
      ),
    ),
  );
}
