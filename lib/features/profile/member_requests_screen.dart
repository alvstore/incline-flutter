import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';

class MemberRequestsScreen extends StatefulWidget {
  final Member? member;
  final String? initialCategory;

  const MemberRequestsScreen({
    super.key,
    this.member,
    this.initialCategory,
  });

  @override
  State<MemberRequestsScreen> createState() => _MemberRequestsScreenState();
}

class _MemberRequestsScreenState extends State<MemberRequestsScreen> {
  List<MemberRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'pending', 'resolved'

  @override
  void initState() {
    super.initState();
    _loadRequests();
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openRequestComposer(defaultCategory: widget.initialCategory);
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      final data = await SupabaseService.instance.fetchMyRequests(memberId);
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to connect to requests service. Please check your network and retry.';
          _isLoading = false;
        });
      }
    }
  }

  List<MemberRequest> get _filteredRequests {
    if (_selectedFilter == 'pending') {
      return _requests.where((r) => r.isPending).toList();
    }
    if (_selectedFilter == 'resolved') {
      return _requests.where((r) => !r.isPending).toList();
    }
    return _requests;
  }

  void _openRequestComposer({String? defaultCategory}) {
    final curMember = widget.member ?? SupabaseService.instance.cachedMember;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequestComposerSheet(
        member: curMember,
        initialCategory: defaultCategory ?? 'trainer_change',
        onRequestSubmitted: () {
          _loadRequests();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request submitted to Incline team.'),
              backgroundColor: AppTheme.emerald,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r.isPending).length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Desk & Service Requests',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.brandAccent),
            onPressed: _loadRequests,
            tooltip: 'Refresh requests',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequestComposer(),
        backgroundColor: context.brandAccent,
        foregroundColor: context.onBrandAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Request',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.brandAccent,
          onRefresh: _loadRequests,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bento Banner
                BentoCard(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: context.cardElevated,
                  border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.brandAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.support_agent_rounded, color: context.brandAccent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INCLINE MEMBER SERVICES',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: context.brandAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track & Submit Inquiries',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pendingCount > 0
                                  ? '$pendingCount active request(s) awaiting review'
                                  : 'All your desk requests are up to date',
                              style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All (${_requests.length})'),
                      const SizedBox(width: 8),
                      _filterChip('pending', 'Pending ($pendingCount)'),
                      const SizedBox(width: 8),
                      _filterChip('resolved', 'Resolved (${_requests.length - pendingCount})'),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Requests List or Empty State
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: DumbbellLoader(text: 'Loading service requests...'),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_filteredRequests.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredRequests.map((req) => _buildRequestCard(req)),

                const SizedBox(height: 80), // Fab space
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.brandAccent : context.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? context.brandAccent : context.borderCol,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.onBrandAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      backgroundColor: context.cardElevated,
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_turned_in_rounded, color: context.brandAccent, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'No Requests Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Need personal training, freeze, locker, or workout plans? Submit a request anytime.',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openRequestComposer(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Raise Service Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandAccent,
                foregroundColor: context.onBrandAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      backgroundColor: context.cardElevated,
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'Failed to Load Requests',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unable to connect to service requests stream.',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandAccent,
                foregroundColor: context.onBrandAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(MemberRequest req) {
    Color statusColor;
    String statusLabel;
    final isPt = req.referenceType == 'pt_purchase' || req.referenceType.contains('pt');

    if (isPt) {
      if (req.isPending) {
        statusColor = AppTheme.amber;
        statusLabel = 'PURCHASE QUEUED';
      } else if (req.isApproved) {
        statusColor = AppTheme.emerald;
        statusLabel = 'PURCHASE COMPLETED';
      } else {
        statusColor = AppTheme.rose;
        statusLabel = 'CANCELLED';
      }
    } else if (req.isPending) {
      statusColor = AppTheme.amber;
      statusLabel = 'PENDING REVIEW';
    } else if (req.isApproved) {
      statusColor = AppTheme.emerald;
      statusLabel = 'APPROVED';
    } else {
      statusColor = AppTheme.rose;
      statusLabel = 'DECLINED';
    }

    IconData categoryIcon;
    Color iconColor;
    if (isPt) {
      categoryIcon = Icons.stars_rounded;
      iconColor = context.brandAccent;
    } else if (req.referenceType == 'trainer_change') {
      categoryIcon = Icons.fitness_center_rounded;
      iconColor = AppTheme.gold;
    } else if (req.referenceType.contains('freeze')) {
      categoryIcon = Icons.ac_unit_rounded;
      iconColor = AppTheme.sky;
    } else if (req.referenceType == 'locker') {
      categoryIcon = Icons.lock_outline_rounded;
      iconColor = AppTheme.amber;
    } else if (req.referenceType == 'diet') {
      categoryIcon = Icons.restaurant_menu_rounded;
      iconColor = AppTheme.emerald;
    } else if (req.referenceType == 'workout') {
      categoryIcon = Icons.sports_gymnastics_rounded;
      iconColor = AppTheme.gold;
    } else {
      categoryIcon = Icons.support_agent_rounded;
      iconColor = AppTheme.cyan;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: context.cardElevated,
        border: Border.all(
          color: req.isPending ? AppTheme.amber.withValues(alpha: 0.3) : context.borderCol,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy • hh:mm a').format(req.createdAt),
                        style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (req.reason != null && req.reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderCol),
                ),
                child: Text(
                  req.reason!,
                  style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                ),
              ),
            ],
            if (req.reviewNotes != null && req.reviewNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: context.brandAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Desk Note: ${req.reviewNotes}',
                      style: GoogleFonts.outfit(fontSize: 11, color: context.brandAccent),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestComposerSheet extends StatefulWidget {
  final Member? member;
  final String initialCategory;
  final VoidCallback onRequestSubmitted;

  const _RequestComposerSheet({
    required this.member,
    required this.initialCategory,
    required this.onRequestSubmitted,
  });

  @override
  State<_RequestComposerSheet> createState() => _RequestComposerSheetState();
}

class _RequestComposerSheetState extends State<_RequestComposerSheet> {
  late String _category;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _preferredSlot = 'Morning (06:00 AM - 11:00 AM)';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'trainer_change',
      'label': 'Trainer Consultation / Allocation',
      'icon': Icons.fitness_center_rounded,
      'color': AppTheme.gold,
      'hint': 'Personal trainer allocation, 1-on-1 coaching consultation, coach switch',
    },
    {
      'id': 'membership_freeze',
      'label': 'Membership Freeze / Hold',
      'icon': Icons.ac_unit_rounded,
      'color': AppTheme.sky,
      'hint': 'Pause membership duration due to travel, medical or work commitments',
    },
    {
      'id': 'locker_request',
      'label': 'Club Locker Allocation',
      'icon': Icons.lock_outline_rounded,
      'color': AppTheme.amber,
      'hint': 'Request personal day/monthly locker in changing suite',
    },
    {
      'id': 'diet',
      'label': 'Personalised Diet Plan Request',
      'icon': Icons.restaurant_menu_rounded,
      'color': AppTheme.emerald,
      'hint': 'Custom macro-calculated nutrition plan curated by Incline nutritionist',
    },
    {
      'id': 'workout',
      'label': 'Personalised Workout Split Request',
      'icon': Icons.sports_gymnastics_rounded,
      'color': AppTheme.gold,
      'hint': 'Custom periodised exercise regimen assigned by lead coach',
    },
    {
      'id': 'general_inquiry',
      'label': 'Front Desk General Inquiry',
      'icon': Icons.support_agent_rounded,
      'color': AppTheme.cyan,
      'hint': 'General club queries, recovery suite inquiries, billing questions',
    },
  ];

  @override
  void initState() {
    super.initState();
    String norm = widget.initialCategory;
    if (norm == 'workout_plan' || norm == 'workout' || norm == 'diet_and_workout') {
      norm = 'workout';
    } else if (norm == 'diet_plan' || norm == 'diet') {
      norm = 'diet';
    }
    if (!_categories.any((c) => c['id'] == norm)) {
      norm = 'workout';
    }
    _category = norm;
    _syncDefaultTitle();

    if (_category == 'workout') {
      _descCtrl.text = 'Requesting an updated personalized workout split and training plan from coach.';
    } else if (_category == 'diet') {
      _descCtrl.text = 'Requesting an updated personalized nutrition and macro-calculated diet plan.';
    }
  }

  void _syncDefaultTitle() {
    final match = _categories.firstWhere((c) => c['id'] == _category, orElse: () => _categories.first);
    _titleCtrl.text = match['label'] as String;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter details or reasons for your request.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final curMember = widget.member ?? SupabaseService.instance.cachedMember ?? await SupabaseService.instance.fetchCurrentMember();
    final memberId = curMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    final branchId = curMember?.branchId;

    final success = await SupabaseService.instance.submitServiceRequest(
      memberId: memberId,
      branchId: branchId,
      category: _category,
      title: _titleCtrl.text.trim(),
      description: desc,
      preferredTime: _category == 'trainer_change' ? _preferredSlot : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        widget.onRequestSubmitted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit request. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            Text(
              'Submit Service Request',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            Text(
              'Directly dispatched to Incline front desk & management team',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
            ),
            const SizedBox(height: 20),

            // Category Picker
            Text(
              'REQUEST CATEGORY',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.brandAccent,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: context.cardElevated,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.brandAccent),
                  items: _categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Row(
                        children: [
                          Icon(c['icon'] as IconData, size: 18, color: c['color'] as Color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c['label'] as String,
                              style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                        _syncDefaultTitle();
                        if (_descCtrl.text.isEmpty ||
                            _descCtrl.text.contains('Requesting an updated personalized')) {
                          if (_category == 'workout') {
                            _descCtrl.text = 'Requesting an updated personalized workout split and training plan from coach.';
                          } else if (_category == 'diet') {
                            _descCtrl.text = 'Requesting an updated personalized nutrition and macro-calculated diet plan.';
                          } else {
                            _descCtrl.text = '';
                          }
                        }
                      });
                    }
                  },
                ),
              ),
            ),

            if (_category == 'trainer_change') ...[
              const SizedBox(height: 16),
              Text(
                'PREFERRED TRAINING TIME SLOT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.brandAccent,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  'Morning (06:00 AM - 11:00 AM)',
                  'Evening (05:00 PM - 10:00 PM)',
                  'Flexible / Any Slot',
                ].map((slot) {
                  final isSelected = _preferredSlot == slot;
                  return ChoiceChip(
                    label: Text(slot, style: GoogleFonts.outfit(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: context.brandAccent,
                    labelStyle: TextStyle(color: isSelected ? context.onBrandAccent : context.textPrimary),
                    backgroundColor: context.cardBg,
                    onSelected: (s) => setState(() => _preferredSlot = slot),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              'DETAILS / NOTES',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.brandAccent,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.cardBg,
                hintText: _category == 'trainer_change'
                    ? 'State your fitness goals (e.g. Muscle Gain, Fat Loss, Strength) or trainer preference...'
                    : 'Provide details, dates, or reason for your request...',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.brandAccent),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandAccent,
                  foregroundColor: context.onBrandAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: context.onBrandAccent, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Request to Front Desk',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
