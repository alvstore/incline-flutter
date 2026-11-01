import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';

class FeedbackScreen extends StatefulWidget {
  final Member? member;

  const FeedbackScreen({super.key, this.member});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 5;
  String _category = 'facility';
  final _commentCtrl = TextEditingController();
  bool _consentTestimonial = true;
  bool _isSubmitting = false;

  List<MemberFeedbackItem> _myFeedback = [];
  bool _isLoadingFeedback = true;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'facility', 'label': 'Club Facilities & Recovery', 'icon': Icons.spa_rounded},
    {'id': 'equipment', 'label': 'Equipment & Weights', 'icon': Icons.fitness_center_rounded},
    {'id': 'trainer', 'label': 'Trainer & Coaching', 'icon': Icons.sports_gymnastics_rounded},
    {'id': 'classes', 'label': 'Studio & Yoga Classes', 'icon': Icons.self_improvement_rounded},
    {'id': 'staff', 'label': 'Staff & Front Desk', 'icon': Icons.support_agent_rounded},
    {'id': 'cleanliness', 'label': 'Hygiene & Cleanliness', 'icon': Icons.cleaning_services_rounded},
    {'id': 'suggestion', 'label': 'Idea / Suggestion', 'icon': Icons.lightbulb_outline_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedbackHistory();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbackHistory() async {
    setState(() => _isLoadingFeedback = true);
    try {
      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      final list = await SupabaseService.instance.fetchMyFeedback(memberId);
      if (mounted) {
        setState(() {
          _myFeedback = list;
          _isLoadingFeedback = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingFeedback = false);
      }
    }
  }

  String _getRatingLabel(int r) {
    switch (r) {
      case 5:
        return 'World-Class Club Experience ⭐⭐⭐⭐⭐';
      case 4:
        return 'Very Good • Exceeds Expectations ⭐⭐⭐⭐';
      case 3:
        return 'Good • Satisfactory Standards ⭐⭐⭐';
      case 2:
        return 'Fair • Room for Improvement ⭐⭐';
      case 1:
        return 'Needs Immediate Management Attention ⭐';
      default:
        return 'Rate your experience';
    }
  }

  Future<void> _submitFeedback() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share a few words about your experience.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    final branchId = widget.member?.branchId;

    final success = await SupabaseService.instance.submitFeedback(
      memberId: memberId,
      branchId: branchId,
      rating: _rating,
      category: _category,
      comment: comment,
      consentForTestimonial: _consentTestimonial,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _commentCtrl.clear();
        _loadFeedbackHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been delivered to Incline management.'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit feedback. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Club Feedback',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
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
                      child: Icon(Icons.star_rate_rounded, color: context.brandAccent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXECUTIVE MEMBER VOICES',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: context.brandAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Shape Your Incline Experience',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your ratings and reviews directly guide club maintenance and coaching standards.',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Rating Section
              BentoCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: context.cardElevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW WAS YOUR EXPERIENCE TODAY?',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: context.brandAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          final isFilled = star <= _rating;
                          return IconButton(
                            iconSize: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: Icon(
                              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isFilled ? AppTheme.amber : context.borderCol,
                            ),
                            onPressed: () => setState(() => _rating = star),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _getRatingLabel(_rating),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.brandAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Category Filter Pills
                    Text(
                      'CATEGORY',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: context.brandAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final isSelected = _category == c['id'];
                        return GestureDetector(
                          onTap: () => setState(() => _category = c['id'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? context.brandAccent : context.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? context.brandAccent : context.borderCol,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  c['icon'] as IconData,
                                  size: 14,
                                  color: isSelected ? context.onBrandAccent : context.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c['label'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? context.onBrandAccent : context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Comments
                    Text(
                      'YOUR THOUGHTS & OBSERVATIONS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: context.brandAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentCtrl,
                      maxLines: 4,
                      style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.cardBg,
                        hintText: 'Share compliments, equipment requests, or areas for improvement...',
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

                    const SizedBox(height: 12),

                    // Testimonial Consent Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _consentTestimonial,
                          activeColor: context.brandAccent,
                          checkColor: context.onBrandAccent,
                          onChanged: (v) => setState(() => _consentTestimonial = v ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'Allow Incline to feature this review as an anonymous member testimonial',
                            style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitFeedback,
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
                                'Submit Feedback to Management',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Past Feedback Section
              Text(
                'YOUR PAST SUBMISSIONS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              if (_isLoadingFeedback)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: context.brandAccent),
                  ),
                )
              else if (_myFeedback.isEmpty)
                BentoCard(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: context.cardElevated,
                  child: Center(
                    child: Text(
                      'No previous feedback submitted yet. Your voice helps us raise the bar.',
                      style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._myFeedback.map((f) => _buildFeedbackHistoryCard(f)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackHistoryCard(MemberFeedbackItem f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: context.cardElevated,
        border: Border.all(color: context.borderCol),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16,
                      color: index < f.rating ? AppTheme.amber : context.borderCol,
                    );
                  }),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Text(
                    f.category.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: context.brandAccent),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(f.createdAt),
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
            if (f.feedbackText != null && f.feedbackText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                f.feedbackText!,
                style: GoogleFonts.outfit(fontSize: 12, color: context.textPrimary),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.emerald),
                const SizedBox(width: 4),
                Text(
                  f.status == 'pending' ? 'Delivered to Branch Manager' : 'Reviewed by Management',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.emerald),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
