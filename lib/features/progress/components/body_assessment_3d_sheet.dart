import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/theme/app_theme.dart';
import 'howbody_qr_scanner_sheet.dart';
import 'anatomical_3d_volumetric_viewer.dart';

/// 2026 Incline 3D Body & Posture Assessment Hub (HOWBODY Scanner Integration)
/// Fetches authentic clinical body composition metrics, postural telemetry,
/// circumference data, and multi-angle camera images directly from Supabase.
class BodyAssessment3DSheet extends StatefulWidget {
  final Member? member;
  final bool isEmbeddedView;

  const BodyAssessment3DSheet({
    super.key,
    this.member,
    this.isEmbeddedView = false,
  });

  static Future<void> show(BuildContext context, {Member? member}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BodyAssessment3DSheet(member: member),
    );
  }

  @override
  State<BodyAssessment3DSheet> createState() => _BodyAssessment3DSheetState();
}

/// Backward compatibility alias for existing tests and call sites
typedef InBodyScanSheet = BodyAssessment3DSheet;

class _BodyAssessment3DSheetState extends State<BodyAssessment3DSheet> {
  Color _surfaceFor(bool isDark) => isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface;
  Color _borderFor(bool isDark) => isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
  Color _recessedFor(bool isDark) => isDark ? InclineColors.cardRecessed : Colors.white;
  Color _primaryTextFor(bool isDark) => isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;

  bool _isLoading = true;
  bool _isSavingManual = false;
  bool _showManualEntry = false;
  int _selectedTabIndex = 0;

  HowbodyScanResult _scanResult = const HowbodyScanResult.empty();
  List<Map<String, dynamic>> _manualLogs = [];

  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBiometricsData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricsData() async {
    setState(() => _isLoading = true);

    try {
      final res = await SupabaseService.instance.fetchLatestHowbodyScan(widget.member?.id);
      if (mounted) {
        setState(() {
          _scanResult = res;
          _manualLogs = res.manualLogs;
          if (res.body == null && res.posture != null) {
            _selectedTabIndex = res.photos.isNotEmpty ? 2 : 1;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] HowBody biometrics fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveManualMeasurement() async {
    final weightStr = _weightController.text.trim();
    if (weightStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your weight in kg.')),
      );
      return;
    }

    final weight = double.tryParse(weightStr);
    if (weight == null || weight <= 20 || weight >= 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight (e.g. 74.5).')),
      );
      return;
    }

    final bodyFat = double.tryParse(_bodyFatController.text.trim());
    final waist = double.tryParse(_waistController.text.trim());
    final notes = _notesController.text.trim();

    setState(() => _isSavingManual = true);
    HapticFeedback.mediumImpact();

    try {
      final client = SupabaseService.instance.client;
      String? memberId = widget.member?.id;
      if (memberId == null || memberId.isEmpty) {
        final currentMember = await SupabaseService.instance.fetchCurrentMember();
        memberId = currentMember?.id;
      }

      if (memberId != null) {
        final newRow = {
          'member_id': memberId,
          'weight_kg': weight,
          'body_fat_percentage': bodyFat,
          'waist_cm': waist,
          'notes': notes.isNotEmpty ? notes : 'Manual member app log',
          'recorded_at': DateTime.now().toIso8601String(),
        };

        await client.from('member_measurements').insert(newRow);

        setState(() {
          _manualLogs.insert(0, newRow);
          _weightController.clear();
          _bodyFatController.clear();
          _waistController.clear();
          _notesController.clear();
          _showManualEntry = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: InclineColors.accentOrange,
              content: Text('✓ Biometric measurement recorded successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] Save measurement notice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyErrorMapper.toGeneralErrorMessage(e, action: 'measurement save'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingManual = false);
    }
  }

  void _openPhotoZoom(BuildContext context, PosturePhoto photo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${photo.label} (${photo.angle})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    photo.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 360,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: InclineColors.accentOrange),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Container(
                        height: 300,
                        color: _recessedFor(isDark),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined, color: isDark ? Colors.white54 : Colors.black45, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Unable to load scan image',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pinch to zoom • Drag to pan',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchPdf(String url) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open scan report document.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentGold = InclineColors.accentOrange;
    final onAccent = isDark ? Colors.black : Colors.white;

    final body = _scanResult.body;
    final posture = _scanResult.posture;
    final photos = _scanResult.photos;
    final hasAnyData = _scanResult.hasData;

    final content = Column(
      children: [
        if (!widget.isEmbeddedView) ...[
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x1AF0441C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33F0441C)),
                        ),
                        child: const Icon(
                          Icons.view_in_ar_rounded,
                          color: InclineColors.accentOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3D Body Assessment',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _primaryTextFor(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'HOWBODY Volumetric Composition & Posture Telemetry',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(
            color: _borderFor(isDark),
            height: 1,
          ),
        ],

        // Main Body
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: InclineColors.accentOrange),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, widget.isEmbeddedView ? 8 : 16, 20, widget.isEmbeddedView ? 110 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Diagnostic Scanner Status & Document Pill
                      _buildScannerStatusBanner(
                        isDark: isDark,
                        accentGold: accentGold,
                        body: body,
                        posture: posture,
                        pdfUrl: _scanResult.pdfUrl,
                      ),

                      const SizedBox(height: 16),

                      // Render the model and date from the same HOWBODY posture scan.
                      Anatomical3DVolumetricViewer(
                        photos: photos,
                        modelUrl: posture?.modelUrl,
                        scanDate: posture?.testTime,
                      ),

                      const SizedBox(height: 18),

                      if (!hasAnyData)
                        _buildAuthenticEmptyState(isDark: isDark, accentGold: accentGold)
                      else ...[
                        // Interactive Tab Navigation
                        _buildSegmentedTabSelector(
                          isDark: isDark,
                          accentGold: accentGold,
                          photoCount: photos.length,
                        ),

                        const SizedBox(height: 18),

                        // Tab Content
                        if (_selectedTabIndex == 0)
                          _buildBodyCompositionTab(isDark: isDark, accentGold: accentGold, body: body)
                        else if (_selectedTabIndex == 1)
                          _buildPostureAlignmentTab(isDark: isDark, accentGold: accentGold, posture: posture)
                        else if (_selectedTabIndex == 2)
                          _buildPhotosTab(isDark: isDark, accentGold: accentGold, photos: photos)
                        else if (_selectedTabIndex == 3)
                          _buildCircumferenceTab(isDark: isDark, accentGold: accentGold, posture: posture),
                      ],

                      const SizedBox(height: 24),

                      // Section 2: Manual Measurements Log & Entry
                      _buildManualMeasurementsSection(
                        isDark: isDark,
                        accentGold: accentGold,
                        onAccent: onAccent,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );

    if (widget.isEmbeddedView) {
      return content;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: _borderFor(isDark),
          width: 1,
        ),
      ),
      child: content,
    );
  }

  // ---------------------------------------------------------------------------
  // Top Banner: Scanner & Timestamp Information
  // ---------------------------------------------------------------------------
  Widget _buildScannerStatusBanner({
    required bool isDark,
    required Color accentGold,
    required HowbodyBodyReport? body,
    required HowbodyPostureReport? posture,
    required String? pdfUrl,
  }) {
    final equipment = body?.equipmentNo ?? posture?.equipmentNo ?? 'Flagship Udaipur Scanner';
    final testDate = body?.testTime ?? posture?.testTime;
    final dateStr = testDate != null
        ? '${testDate.day.toString().padLeft(2, '0')}/${testDate.month.toString().padLeft(2, '0')}/${testDate.year} · ${testDate.hour % 12 == 0 ? 12 : testDate.hour % 12}:${testDate.minute.toString().padLeft(2, '0')} ${testDate.hour >= 12 ? 'PM' : 'AM'}'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceFor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x33F0441C),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                size: 18,
                color: InclineColors.accentOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Incline HowBody 3D · $equipment',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InclineScaleButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  HowbodyQrScannerSheet.show(context, member: widget.member);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentGold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 13, color: accentGold),
                      const SizedBox(width: 4),
                      Text(
                        'Link Scanner',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InclineScaleButton(
                onTap: () {
                  if (pdfUrl != null && pdfUrl.isNotEmpty) {
                    _launchPdf(pdfUrl);
                  } else {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No exported clinical PDF report generated yet. Step onto the HOWBODY scanner to calibrate.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (pdfUrl != null && pdfUrl.isNotEmpty)
                        ? AppTheme.emerald.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (pdfUrl != null && pdfUrl.isNotEmpty)
                          ? AppTheme.emerald.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 13,
                        color: (pdfUrl != null && pdfUrl.isNotEmpty) ? AppTheme.emerald : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Export PDF',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: (pdfUrl != null && pdfUrl.isNotEmpty) ? AppTheme.emerald : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (dateStr != null) ...[
            const SizedBox(height: 4),
            Text(
              'Latest automated diagnostic sync: $dateStr',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Authentic Empty State (Zero Mock Data)
  // ---------------------------------------------------------------------------
  Widget _buildAuthenticEmptyState({
    required bool isDark,
    required Color accentGold,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _surfaceFor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderFor(isDark),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x1AF0441C),
              border: Border.all(color: const Color(0x33F0441C)),
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              size: 36,
              color: InclineColors.accentOrange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No 3D Assessment On File Yet',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Step onto the HowBody 3D scanner at Incline Udaipur Flagship to calibrate your full volumetric body contour, posture deviations, and body composition.\n\nAll automated data and multi-angle photos will instantly sync to your app profile.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          InclineScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              HowbodyQrScannerSheet.show(context, member: widget.member);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: accentGold,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentGold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Link Incline 3D Scanner (QR)',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InclineScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showManualEntry = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: accentGold),
                  const SizedBox(width: 6),
                  Text(
                    'Record Manual Measurements',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accentGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Segmented Navigation Tabs
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector({
    required bool isDark,
    required Color accentGold,
    required int photoCount,
  }) {
    final tabs = [
      {'title': 'Composition', 'icon': Icons.scale_rounded},
      {'title': 'Posture', 'icon': Icons.accessibility_new_rounded},
      {'title': 'Photos ($photoCount)', 'icon': Icons.camera_alt_outlined},
      {'title': 'Circumference', 'icon': Icons.straighten_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceFor(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            final tab = tabs[index];
            return InclineScaleButton(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = index);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _recessedFor(isDark) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 13,
                      color: isSelected
                          ? accentGold
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab['title'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Body Composition (Weight, Fat %, SMM, BMR, Coaching Targets)
  // ---------------------------------------------------------------------------
  Widget _buildBodyCompositionTab({
    required bool isDark,
    required Color accentGold,
    required HowbodyBodyReport? body,
  }) {
    if (body == null) {
      return _buildSubSectionEmpty('No body composition metrics available in this scan.', isDark: isDark);
    }

    final weightStr = body.weight != null ? '${body.weight!.toStringAsFixed(1)} kg' : '-- kg';
    final pbfStr = body.pbf != null ? '${body.pbf!.toStringAsFixed(1)}%' : '--%';
    final smmStr = body.smm != null ? '${body.smm!.toStringAsFixed(1)} kg' : '-- kg';
    final bmrStr = body.bmr != null ? '${body.bmr!.toStringAsFixed(0)} kcal' : '-- kcal';

    final bmiStr = body.bmi != null ? body.bmi!.toStringAsFixed(1) : '--';
    final vfrStr = body.vfr != null ? '${body.vfr}' : '--';
    final tbwStr = body.tbw != null ? '${body.tbw!.toStringAsFixed(1)} kg' : '--';
    final whrStr = body.whr != null ? body.whr!.toStringAsFixed(2) : '--';
    final metAgeStr = body.metabolicAge != null ? '${body.metabolicAge} yrs' : '--';
    final healthScore = body.healthScore != null ? '${body.healthScore}/100' : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary 4-card Bento
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                label: 'BODY WEIGHT',
                value: weightStr,
                subtext: body.targetWeight != null ? 'Target: ${body.targetWeight} kg' : 'Total Mass',
                icon: Icons.scale_rounded,
                iconColor: InclineColors.thermalAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                label: 'BODY FAT (PBF)',
                value: pbfStr,
                subtext: 'Optimal: 10-20%',
                icon: Icons.pie_chart_rounded,
                iconColor: InclineColors.thermalAmber,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12, height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                label: 'SKELETAL MUSCLE',
                value: smmStr,
                subtext: 'Muscle Mass Index',
                icon: Icons.fitness_center_rounded,
                iconColor: InclineColors.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                label: 'METABOLIC RATE',
                value: bmrStr,
                subtext: 'Daily Basal Calories',
                icon: Icons.local_fire_department_rounded,
                iconColor: InclineColors.thermalRed,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Diagnostic Breakdown
        Text(
          'DIAGNOSTIC METABOLIC BREAKDOWN',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: accentGold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceFor(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _borderFor(isDark),
            ),
          ),
          child: Column(
            children: [
              _buildKeyValueRow(isDark, 'Body Mass Index (BMI)', bmiStr, 'Healthy: 18.5 - 24.9'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Visceral Fat Rating (VFR)', vfrStr, 'Target: 1 - 9 Level'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Total Body Water (TBW)', tbwStr, 'Hydration Mass'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Waist-to-Hip Ratio (WHR)', whrStr, 'Healthy: 0.70 - 0.90'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Metabolic Bio Age', metAgeStr, 'Biological Cellular Age'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Overall Health Score', healthScore, 'Incline Clinical Score'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Coaching Target Recommendations
        if (body.targetWeight != null || body.fatControl != null || body.muscleControl != null) ...[
          Text(
            'COACHING TARGET RECOMMENDATIONS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: accentGold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceFor(isDark),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x33F0441C)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTargetItem(
                  isDark: isDark,
                  label: 'Target Weight',
                  value: body.targetWeight != null ? '${body.targetWeight} kg' : '--',
                  color: InclineColors.thermalAmber,
                ),
                _buildTargetItem(
                  isDark: isDark,
                  label: 'Fat Adjust',
                  value: body.fatControl != null ? '${body.fatControl! > 0 ? "+" : ""}${body.fatControl} kg' : '--',
                  color: InclineColors.thermalAmber,
                ),
                _buildTargetItem(
                  isDark: isDark,
                  label: 'Muscle Adjust',
                  value: body.muscleControl != null ? '${body.muscleControl! > 0 ? "+" : ""}${body.muscleControl} kg' : '--',
                  color: InclineColors.accentOrange,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Posture & Alignment ("Prossurement" / Posture Telemetry)
  // ---------------------------------------------------------------------------
  Widget _buildPostureAlignmentTab({
    required bool isDark,
    required Color accentGold,
    required HowbodyPostureReport? posture,
  }) {
    if (posture == null) {
      return _buildSubSectionEmpty('No posture alignment data available in this scan session.', isDark: isDark);
    }

    final score = posture.score ?? 0;
    final scoreLabel = score >= 85 ? 'Optimal Alignment' : (score >= 70 ? 'Moderate Alignment' : 'Correction Needed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Posture Score Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceFor(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x33F0441C),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: InclineColors.accentOrange.withValues(alpha: 0.15),
                  border: Border.all(color: InclineColors.accentOrange, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$score',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: InclineColors.accentOrange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSTURE ALIGNMENT SCORE',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: accentGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scoreLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (posture.postureType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Category: ${posture.postureType}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'POSTURAL DEVIATION MATRIX',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: accentGold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceFor(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _borderFor(isDark),
            ),
          ),
          child: Column(
            children: [
              _buildDeviationRow(isDark, 'Body Slope', posture.bodySlope, 'Deviation from vertical plumb line'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Head Forward Shift', posture.headForward, 'Cervical protrusion measure'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Head Tilt Angle', posture.headSlant, 'Lateral cranial tilt'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Shoulder Balance', posture.highLowShoulder, 'Shoulder level asymmetry'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Pelvic Tilt', posture.pelvisForward, 'Anterior/Posterior pelvic inclination'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Left Knee Alignment', posture.kneeLeft, 'Left patellar track deviation'),
              const Divider(height: 18),
              _buildDeviationRow(isDark, 'Right Knee Alignment', posture.kneeRight, 'Right patellar track deviation'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Scanner Multi-Angle Photos ("DEVICE IS SENDING BODY DATA PHOTS")
  // ---------------------------------------------------------------------------
  Widget _buildPhotosTab({
    required bool isDark,
    required Color accentGold,
    required List<PosturePhoto> photos,
  }) {
    if (photos.isEmpty) {
      return _buildSubSectionEmpty('No multi-angle camera images saved for this scan session.', isDark: isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1AF0441C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x33F0441C)),
          ),
          child: Row(
            children: [
              const Icon(Icons.photo_camera_rounded, size: 18, color: InclineColors.accentOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Multi-angle body telemetry captured by the HowBody camera array. Tap any image to inspect in full-screen zoom.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index];
            return InclineScaleButton(
              onTap: () => _openPhotoZoom(context, photo),
              child: Container(
                decoration: BoxDecoration(
                  color: _surfaceFor(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _borderFor(isDark),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        photo.url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: InclineColors.accentOrange),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  'Photo unavailable',
                                  style: GoogleFonts.outfit(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              photo.label,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Body Circumference Tape Measurements
  // ---------------------------------------------------------------------------
  Widget _buildCircumferenceTab({
    required bool isDark,
    required Color accentGold,
    required HowbodyPostureReport? posture,
  }) {
    if (posture == null) {
      return _buildSubSectionEmpty('No circumference measurements recorded in this scan.', isDark: isDark);
    }

    String cStr(double? val) => val != null ? '${val.toStringAsFixed(1)} cm' : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANATOMICAL CIRCUMFERENCE TELEMETRY',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: accentGold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceFor(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _borderFor(isDark),
            ),
          ),
          child: Column(
            children: [
              _buildKeyValueRow(isDark, 'Chest / Bust Circumference', cStr(posture.bust), 'Thoracic contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Waist Circumference', cStr(posture.waist), 'Abdominal narrow point'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Hip Circumference', cStr(posture.hip), 'Gluteal maximum width'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Left Thigh', cStr(posture.leftThigh), 'Upper femur contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Right Thigh', cStr(posture.rightThigh), 'Upper femur contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Left Calf', cStr(posture.calfLeft), 'Gastrocnemius contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Right Calf', cStr(posture.calfRight), 'Gastrocnemius contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Left Upper Arm (Biceps)', cStr(posture.upArmLeft), 'Flexed brachii contour'),
              const Divider(height: 18),
              _buildKeyValueRow(isDark, 'Right Upper Arm (Biceps)', cStr(posture.upArmRight), 'Flexed brachii contour'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Manual Measurements Log & Entry
  // ---------------------------------------------------------------------------
  Widget _buildManualMeasurementsSection({
    required bool isDark,
    required Color accentGold,
    required Color onAccent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MANUAL HEALTH MEASUREMENTS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: accentGold,
              ),
            ),
            InclineScaleButton(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showManualEntry = !_showManualEntry);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showManualEntry ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      size: 16,
                      color: accentGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showManualEntry ? 'Cancel' : 'Record Now',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accentGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Manual Entry Form
        if (_showManualEntry) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surfaceFor(isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _borderFor(isDark),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        isDark: isDark,
                        controller: _weightController,
                        label: 'Weight (kg)*',
                        hint: '74.5',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        isDark: isDark,
                        controller: _bodyFatController,
                        label: 'Body Fat (%)',
                        hint: '14.2',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        isDark: isDark,
                        controller: _waistController,
                        label: 'Waist (cm)',
                        hint: '82.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        isDark: isDark,
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Morning, fasted',
                        keyboardType: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: InclineScaleButton(
                    onTap: _isSavingManual ? null : _saveManualMeasurement,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: accentGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _isSavingManual
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              'Save to Member Health Profile',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: onAccent,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Historical Manual Logs List
        if (_manualLogs.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _manualLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = _manualLogs[idx];
              final dateStr = item['recorded_at'] != null
                  ? item['recorded_at'].toString().split('T').first
                  : 'Recently';
              final weightVal = item['weight_kg'] ?? '--';
              final fatVal = item['body_fat_percentage'];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _surfaceFor(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: InclineColors.accentOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$weightVal kg',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (fatVal != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $fatVal% Fat',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets & Component Builders
  // ---------------------------------------------------------------------------
  Widget _buildSubSectionEmpty(String message, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceFor(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderFor(isDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _primaryTextFor(isDark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(bool isDark, String label, String value, String sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: InclineColors.accentOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviationRow(bool isDark, String label, double? val, String hint) {
    final str = val != null ? (val > 0 ? '+$val°' : '$val°') : 'Normal';
    final isAltered = val != null && val.abs() > 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              hint,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isAltered
                ? InclineColors.thermalAmber.withValues(alpha: 0.15)
                : InclineColors.accentOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            str,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isAltered ? InclineColors.thermalAmber : InclineColors.accentOrange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetItem({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            isDense: true,
            filled: true,
            fillColor: _surfaceFor(isDark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _borderFor(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
