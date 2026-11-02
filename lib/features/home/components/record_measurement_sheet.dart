import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/theme/app_theme.dart';

/// Dedicated Bottom Sheet for Members to Log Manual Body Measurements.
/// Conforms to Incline Member App Guide §19 (Manual progress updates and private photos).
/// Writes directly to `member_measurements` table and supports prefilling.
class RecordMeasurementSheet extends StatefulWidget {
  final Member? member;
  final VoidCallback? onSaved;

  const RecordMeasurementSheet({
    super.key,
    this.member,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    Member? member,
    VoidCallback? onSaved,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordMeasurementSheet(
        member: member,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<RecordMeasurementSheet> createState() => _RecordMeasurementSheetState();
}

class _RecordMeasurementSheetState extends State<RecordMeasurementSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showCircumferences = true;

  // Controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _chestController = TextEditingController();
  final _hipsController = TextEditingController();
  final _bicepsController = TextEditingController();
  final _thighsController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousMeasurements();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _chestController.dispose();
    _hipsController.dispose();
    _bicepsController.dispose();
    _thighsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousMeasurements() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      String? memberId = widget.member?.id;
      if (memberId == null || memberId.isEmpty) {
        final currentMember = await SupabaseService.instance.fetchCurrentMember();
        memberId = currentMember?.id;
      }

      if (memberId != null) {
        final rows = await client
            .from('member_measurements')
            .select('*')
            .eq('member_id', memberId)
            .order('recorded_at', ascending: false)
            .limit(5);

        if (mounted) {
          final list = List<Map<String, dynamic>>.from(rows as List);
          _recentLogs = list;

          // Prefill height from latest record if available
          if (list.isNotEmpty) {
            final latest = list.first;
            if (latest['height_cm'] != null && _heightController.text.isEmpty) {
              _heightController.text = latest['height_cm'].toString();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] Load previous measurements error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveMeasurement() async {
    final weightStr = _weightController.text.trim();
    if (weightStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your body weight in kg.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final weight = double.tryParse(weightStr);
    if (weight == null || weight < 25 || weight > 350) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a realistic weight (25 - 350 kg).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final height = double.tryParse(_heightController.text.trim());
    if (height != null && (height < 100 || height > 250)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Height must be between 100 cm and 250 cm.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final bodyFat = double.tryParse(_bodyFatController.text.trim());
    if (bodyFat != null && (bodyFat < 2 || bodyFat > 70)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Body fat must be between 2% and 70%.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final waist = double.tryParse(_waistController.text.trim());
    final chest = double.tryParse(_chestController.text.trim());
    final hips = double.tryParse(_hipsController.text.trim());
    final biceps = double.tryParse(_bicepsController.text.trim());
    final thighs = double.tryParse(_thighsController.text.trim());
    final notes = _notesController.text.trim();

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final client = SupabaseService.instance.client;
      String? memberId = widget.member?.id;
      if (memberId == null || memberId.isEmpty) {
        final currentMember = await SupabaseService.instance.fetchCurrentMember();
        memberId = currentMember?.id;
      }

      if (memberId == null) {
        throw Exception('Member profile not found. Please log in again.');
      }

      final payload = <String, dynamic>{
        'member_id': memberId,
        'weight_kg': weight,
        if (height != null) 'height_cm': height,
        if (bodyFat != null) 'body_fat_percentage': bodyFat,
        if (waist != null) 'waist_cm': waist,
        if (chest != null) 'chest_cm': chest,
        if (hips != null) 'hips_cm': hips,
        if (biceps != null) 'biceps_left_cm': biceps,
        if (thighs != null) 'thighs_left_cm': thighs,
        'notes': notes.isNotEmpty ? notes : 'Manual member app log',
        'recorded_at': DateTime.now().toIso8601String(),
      };

      // 1. Attempt official RPC `record_member_measurement`
      bool rpcSuccess = false;
      try {
        await client.rpc('record_member_measurement', params: {
          'p_member_id': memberId,
          'p_payload': payload,
        });
        rpcSuccess = true;
      } catch (rpcErr) {
        debugPrint('[INCLINE] record_member_measurement RPC fallback to table insert: $rpcErr');
      }

      // 2. Direct table insert fallback if RPC does not exist
      if (!rpcSuccess) {
        await client.from('member_measurements').insert(payload);
      }

      if (mounted) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: InclineColors.accentOrange,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Measurements saved: ${weight.toStringAsFixed(1)} kg logged',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[INCLINE] Error recording measurements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFriendlyErrorMapper.toGeneralErrorMessage(e, action: 'measurement save')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.brandAccent;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.borderCol),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: context.borderCol,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_note_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Body Measurements',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Track Weight, Body Fat & Circumferences',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: context.textMuted),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: context.borderCol),
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Core Metrics (Weight, Height, Body Fat)
                      Text(
                        'CORE BODY METRICS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Weight Field (Primary)
                      _buildNumberField(
                        controller: _weightController,
                        label: 'Current Weight (kg) *',
                        hint: 'e.g. 67.7',
                        icon: Icons.scale_rounded,
                        isPrimary: true,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _heightController,
                              label: 'Height (cm)',
                              hint: 'e.g. 175.0',
                              icon: Icons.height_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              controller: _bodyFatController,
                              label: 'Body Fat (%)',
                              hint: 'e.g. 15.5',
                              icon: Icons.pie_chart_outline_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section 2: Circumferences
                      InkWell(
                        onTap: () => setState(() => _showCircumferences = !_showCircumferences),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CIRCUMFERENCE MEASUREMENTS (CM)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: accent,
                                ),
                              ),
                              Icon(
                                _showCircumferences
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_showCircumferences) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberField(
                                controller: _chestController,
                                label: 'Chest (cm)',
                                hint: 'e.g. 98.4',
                                icon: Icons.straighten_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildNumberField(
                                controller: _waistController,
                                label: 'Waist (cm)',
                                hint: 'e.g. 79.9',
                                icon: Icons.straighten_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberField(
                                controller: _hipsController,
                                label: 'Hips (cm)',
                                hint: 'e.g. 102.3',
                                icon: Icons.straighten_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildNumberField(
                                controller: _bicepsController,
                                label: 'Arms / Biceps (cm)',
                                hint: 'e.g. 34.8',
                                icon: Icons.fitness_center_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberField(
                                controller: _thighsController,
                                label: 'Thighs (cm)',
                                hint: 'e.g. 70.1',
                                icon: Icons.straighten_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section 3: Notes
                      Text(
                        'NOTES & CONDITIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Fasted morning weight, post-workout hydration...',
                          hintStyle: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                          filled: true,
                          fillColor: context.cardBg,
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
                            borderSide: BorderSide(color: accent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Primary Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveMeasurement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Save Biometric Record',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // Recent Logs Section
                      if (_recentLogs.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          'RECENT MANUAL LOGS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentLogs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final row = _recentLogs[idx];
                            final date = row['recorded_at'] != null
                                ? row['recorded_at'].toString().split('T').first
                                : 'Recent';
                            final wt = row['weight_kg'] != null ? '${row['weight_kg']} kg' : '--';
                            final bf = row['body_fat_percentage'] != null ? '${row['body_fat_percentage']}% BF' : null;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.borderCol),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        wt,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      if (bf != null)
                                        Text(
                                          bf,
                                          style: GoogleFonts.outfit(fontSize: 11, color: accent),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    date,
                                    style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPrimary = false,
    bool isRequired = false,
  }) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? InclineColors.accentOrange
        : const Color(0xFFD97706);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: isPrimary ? accent : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(
            fontSize: isPrimary ? 16 : 13.5,
            fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 12.5,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF16191E)
                : const Color(0xFFF3F4F6),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isPrimary ? 14 : 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isPrimary ? accent.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isPrimary ? accent.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
