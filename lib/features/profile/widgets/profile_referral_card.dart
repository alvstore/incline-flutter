import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dumbbell_loader.dart';

/// 2026 World-Class Member Referral & Tracking Card
/// Dynamically respects Incline theme tokens (light & dark).
/// Features 44px accessible touch targets, deep link formatting (`/register?ref=...`),
/// WhatsApp intent sharing, branch reward status gating, and server-authoritative claim workflow.
class ProfileReferralCard extends StatelessWidget {
  final Member? member;
  final bool rewardsEnabled;

  const ProfileReferralCard({
    super.key,
    required this.member,
    this.rewardsEnabled = false,
  });

  void _openReferralModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    final mCode = member?.memberCode;
    final memberCode = (mCode != null && mCode.isNotEmpty)
        ? mCode
        : (member != null && member!.id.length >= 8
            ? 'INC-${member!.id.substring(0, 8).toUpperCase()}'
            : 'INCLINE');
    final inviteLink = 'https://theincline.in/register?ref=${Uri.encodeComponent(memberCode)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.86,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (scrollCtx, scrollCtrl) => _ReferralSheetContent(
          member: member,
          memberCode: memberCode,
          inviteLink: inviteLink,
          initialRewardsEnabled: rewardsEnabled,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppTheme.emerald,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVITE & TRACK',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppTheme.emerald,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Refer Friends & Earn',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  rewardsEnabled
                      ? 'Track invites & earn rewards'
                      : 'Priority guest passes • Verified access',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: context.textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Open Refer and Earn privileges',
            child: ElevatedButton(
              onPressed: () => _openReferralModal(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Invite',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralSheetContent extends StatefulWidget {
  final Member? member;
  final String memberCode;
  final String inviteLink;
  final bool initialRewardsEnabled;
  final ScrollController scrollController;

  const _ReferralSheetContent({
    required this.member,
    required this.memberCode,
    required this.inviteLink,
    required this.initialRewardsEnabled,
    required this.scrollController,
  });

  @override
  State<_ReferralSheetContent> createState() => _ReferralSheetContentState();
}

class _ReferralSheetContentState extends State<_ReferralSheetContent> {
  bool _isLoading = true;
  bool _isRewardsEnabled = false;
  List<MemberReferral> _referrals = [];
  List<ReferralReward> _rewards = [];
  String? _claimingRewardId;

  @override
  void initState() {
    super.initState();
    _isRewardsEnabled = widget.initialRewardsEnabled;
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    final memberId = widget.member?.id ??
        SupabaseService.instance.cachedMember?.id ??
        SupabaseService.instance.currentUser?.id ??
        '';
    final branchId = widget.member?.branchId;

    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchMemberReferrals(memberId),
        SupabaseService.instance.fetchMemberRewards(memberId),
        SupabaseService.instance.getReferralRewardsEnabled(branchId),
      ]);

      if (mounted) {
        setState(() {
          _referrals = results[0] as List<MemberReferral>;
          _rewards = results[1] as List<ReferralReward>;
          _isRewardsEnabled = results[2] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _claimReward(ReferralReward reward) async {
    final memberId = widget.member?.id ??
        SupabaseService.instance.cachedMember?.id ??
        SupabaseService.instance.currentUser?.id ??
        '';
    if (memberId.isEmpty) return;

    setState(() => _claimingRewardId = reward.id);
    HapticFeedback.mediumImpact();

    final res = await SupabaseService.instance.requestReferralRewardClaim(
      rewardId: reward.id,
      memberId: memberId,
    );

    if (mounted) {
      setState(() => _claimingRewardId = null);
      if (res['success'] == true) {
        final status = res['status'] ?? 'pending_approval';
        final msg = status == 'claimed'
            ? 'Reward claimed! Wallet credit processed.'
            : 'Claim submitted. Awaiting manager approval.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
        _loadReferralData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Unable to process claim request.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    HapticFeedback.mediumImpact();
    final message =
        'Hey! Join me at Incline and get rewarded! Register with my referral link:\n${widget.inviteLink}';
    final encodedMsg = Uri.encodeComponent(message);
    final waApp = Uri.parse('whatsapp://send?text=$encodedMsg');
    final waWeb = Uri.parse('https://wa.me/?text=$encodedMsg');

    if (await canLaunchUrl(waApp)) {
      await launchUrl(waApp);
    } else if (await canLaunchUrl(waWeb)) {
      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite message & link copied to clipboard!'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(22, 16, 22, 120 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Grab Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderCol,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Sheet Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFER & EARN',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: AppTheme.emerald,
                      ),
                    ),
                    Text(
                      'Invite Friends to Incline',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Referral Code & Registration Link Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR EXCLUSIVE PASSCODE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.memberCode,
                        style: GoogleFonts.spaceMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: context.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Copy referral registration link',
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: widget.inviteLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Registration link copied to clipboard!\n${widget.inviteLink}'),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(
                          'Copy Link',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.inviteLink,
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. WhatsApp Share Action (44px target)
          Semantics(
            button: true,
            label: 'Share referral invite via WhatsApp',
            child: OutlinedButton.icon(
              onPressed: _shareWhatsApp,
              icon: const Icon(Icons.share_rounded, size: 18, color: AppTheme.emerald),
              label: Text(
                'Share via WhatsApp',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: AppTheme.emerald,
                side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Notice Banner when rewards paused
          if (!_isRewardsEnabled) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pause_circle_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rewards Paused',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Referral reward payouts are currently paused for this branch. Tracking remains active, and your invitees still receive priority registration passes.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 6. Live Tracker Stats Section
          Text(
            'REFERRAL TRACKER',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'Invited',
                  value: _isLoading ? '...' : '${_referrals.length}',
                  subtitle: 'Contacts Shared',
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Joined',
                  value: _isLoading ? '...' : '${_referrals.where((r) => r.isConverted).length}',
                  subtitle: 'Active Members',
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Rewards',
                  value: _isLoading ? '...' : '${_rewards.where((r) => !r.isClaimed).length}',
                  subtitle: _isRewardsEnabled ? 'Available' : 'Paused',
                  color: _isRewardsEnabled ? InclineColors.accentOrange : InclineColors.thermalAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 7. Member Rewards List Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MY REFERRAL REWARDS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: context.textMuted,
                ),
              ),
              if (!_isLoading)
                Text(
                  '${_rewards.length} recorded',
                  style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: DumbbellLoader(text: 'Loading rewards...', size: DumbbellLoaderSize.sm),
              ),
            )
          else if (_rewards.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderCol),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: context.textMuted, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No rewards earned yet. Share your registration link to start earning when friends join!',
                      style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._rewards.map((r) => _buildRewardCard(r)),

          const SizedBox(height: 24),

          // 8. Referral History List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INVITED CONTACTS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: context.textMuted,
                ),
              ),
              if (!_isLoading)
                Text(
                  '${_referrals.length} guests',
                  style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: DumbbellLoader(text: 'Loading invites...', size: DumbbellLoaderSize.sm),
              ),
            )
          else if (_referrals.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderCol),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline_rounded, color: context.textMuted, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No referrals yet. Send your passcode or link to friends to track registrations here in real time.',
                      style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._referrals.map((ref) => _buildReferralRow(ref)),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(ReferralReward reward) {
    final formattedDate = DateFormat('d MMM yyyy').format(reward.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monetization_on_rounded, color: AppTheme.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.description ?? 'Referral Reward',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${reward.rewardValue.toStringAsFixed(0)} • $formattedDate',
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge or Claim Action Button (>= 44px touch target)
          if (reward.isAwaitingApproval)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Awaiting approval',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber),
                  ),
                ],
              ),
            )
          else if (reward.isClaimed || reward.claimStatus == 'approved')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Claimed',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                  ),
                ],
              ),
            )
          else if (_isRewardsEnabled)
            Semantics(
              button: true,
              label: 'Claim referral reward',
              child: ElevatedButton(
                onPressed: _claimingRewardId == reward.id ? null : () => _claimReward(reward),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: _claimingRewardId == reward.id
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Claim',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: context.cardElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderCol),
              ),
              child: Text(
                'Rewards paused',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: context.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferralRow(MemberReferral ref) {
    final dateStr = DateFormat('d MMM yyyy').format(ref.createdAt);
    final isConverted = ref.isConverted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isConverted
                ? AppTheme.emerald.withValues(alpha: 0.15)
                : context.cardElevated,
            child: Icon(
              isConverted ? Icons.check_circle_outline_rounded : Icons.person_outline_rounded,
              size: 16,
              color: isConverted ? AppTheme.emerald : context.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.referredName.isNotEmpty ? ref.referredName : 'Invited Guest',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConverted
                  ? AppTheme.emerald.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isConverted
                    ? AppTheme.emerald.withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConverted ? Icons.check_rounded : Icons.schedule_rounded,
                  size: 11,
                  color: isConverted ? AppTheme.emerald : Colors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  isConverted ? 'JOINED' : 'PENDING',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isConverted ? AppTheme.emerald : Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
