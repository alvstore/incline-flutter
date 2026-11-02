import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../home/components/inbody_scan_sheet.dart';

/// Official HOWBODY Dual-Unit Height Converter Contract (PROJECT.md § Interface Contracts)
class HowbodyHeightConverter {
  static const double minValidCm = 100.0;
  static const double maxValidCm = 250.0;

  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    if (inches == 12) {
      return (feet: feet + 1, inches: 0);
    }
    return (feet: feet, inches: inches);
  }

  static double feetInchesToCm(int feet, int inches) {
    return ((feet * 12) + inches) * 2.54;
  }

  static bool isValidHeightCm(double cm) {
    return cm >= minValidCm && cm <= maxValidCm;
  }
}

enum HeightUnit { cm, ftIn }

enum _LinkSheetStep { form, polling, error, timeout }

/// Modal bottom sheet for linking member to an active HOWBODY 3D Scanner session.
class HowbodyLinkSheet extends StatefulWidget {
  final String equipmentNo;
  final String scanId;
  final String initialKind;
  final Member? member;
  final Future<HowbodyBindResult> Function({
    required String equipmentNo,
    required String scanId,
    required String kind,
    required double heightCm,
    String? memberId,
  })? onBindScanner;
  final Future<HowbodySessionStatus> Function(String scanId)? onCheckStatus;
  final Future<String?> Function(String equipmentNo)? onFetchDeviceLabel;

  const HowbodyLinkSheet({
    super.key,
    required this.equipmentNo,
    required this.scanId,
    this.initialKind = 'body',
    this.member,
    this.onBindScanner,
    this.onCheckStatus,
    this.onFetchDeviceLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String equipmentNo,
    required String scanId,
    String initialKind = 'body',
    Member? member,
    Future<HowbodyBindResult> Function({
      required String equipmentNo,
      required String scanId,
      required String kind,
      required double heightCm,
      String? memberId,
    })? onBindScanner,
    Future<HowbodySessionStatus> Function(String scanId)? onCheckStatus,
    Future<String?> Function(String equipmentNo)? onFetchDeviceLabel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HowbodyLinkSheet(
        equipmentNo: equipmentNo,
        scanId: scanId,
        initialKind: initialKind,
        member: member,
        onBindScanner: onBindScanner,
        onCheckStatus: onCheckStatus,
        onFetchDeviceLabel: onFetchDeviceLabel,
      ),
    );
  }

  @override
  State<HowbodyLinkSheet> createState() => _HowbodyLinkSheetState();
}

class _HowbodyLinkSheetState extends State<HowbodyLinkSheet>
    with SingleTickerProviderStateMixin {
  _LinkSheetStep _currentStep = _LinkSheetStep.form;
  late String _selectedKind;
  HeightUnit _unit = HeightUnit.cm;

  final TextEditingController _cmController = TextEditingController();
  final TextEditingController _feetController = TextEditingController();
  final TextEditingController _inchesController = TextEditingController();

  String? _deviceLabel;
  bool _isLoading = false;
  String? _errorMessage;
  int _pollCount = 0;
  Timer? _pollTimer;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind.toLowerCase() == 'posture' ? 'posture' : 'body';

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTestEnvironment) {
      _radarController.repeat();
    } else {
      _radarController.value = 0.5;
    }

    _initHeightValues();
    _loadDeviceLabel();
  }

  Future<void> _initHeightValues() async {
    double initialHeight = 175.0;

    try {
      final recorded = await SupabaseService.instance
          .fetchMemberRecordedHeight(widget.member?.id);
      if (recorded != null && HowbodyHeightConverter.isValidHeightCm(recorded)) {
        initialHeight = recorded;
      }
    } catch (_) {}

    _cmController.text = initialHeight.toStringAsFixed(1);
    final imperial = HowbodyHeightConverter.cmToFeetInches(initialHeight);
    _feetController.text = imperial.feet.toString();
    _inchesController.text = imperial.inches.toString();

    if (mounted) setState(() {});
  }

  Future<void> _loadDeviceLabel() async {
    try {
      final fetchFn = widget.onFetchDeviceLabel ??
          SupabaseService.instance.fetchHowbodyDeviceLabel;
      final label = await fetchFn(widget.equipmentNo);
      if (mounted && label != null) {
        setState(() => _deviceLabel = label);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _radarController.dispose();
    _cmController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  void _onCmChanged(String val) {
    final parsed = double.tryParse(val.trim());
    if (parsed != null && parsed.isFinite && parsed > 0) {
      final imp = HowbodyHeightConverter.cmToFeetInches(parsed);
      _feetController.text = imp.feet.toString();
      _inchesController.text = imp.inches.toString();
    }
  }

  void _onImperialChanged() {
    final feet = int.tryParse(_feetController.text.trim()) ?? 0;
    final inches = int.tryParse(_inchesController.text.trim()) ?? 0;
    final cm = HowbodyHeightConverter.feetInchesToCm(feet, inches);
    _cmController.text = cm.toStringAsFixed(1);
  }

  double? get _resolvedHeightCm {
    if (_unit == HeightUnit.cm) {
      final parsed = double.tryParse(_cmController.text.trim());
      return (parsed != null && parsed.isFinite) ? parsed : null;
    } else {
      final feet = int.tryParse(_feetController.text.trim()) ?? 0;
      final inches = int.tryParse(_inchesController.text.trim()) ?? 0;
      return HowbodyHeightConverter.feetInchesToCm(feet, inches);
    }
  }

  Future<void> _linkScanner() async {
    final height = _resolvedHeightCm;
    if (height == null || !HowbodyHeightConverter.isValidHeightCm(height)) {
      setState(() {
        _errorMessage = 'Height must be between 100 cm and 250 cm (3\'3" – 8\'2")';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bindFn = widget.onBindScanner ??
          SupabaseService.instance.bindHowbodyScanner;
      final result = await bindFn(
        equipmentNo: widget.equipmentNo,
        scanId: widget.scanId,
        kind: _selectedKind,
        heightCm: height,
        memberId: widget.member?.id,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isLoading = false;
          _currentStep = _LinkSheetStep.polling;
        });
        _startPolling();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = UserFriendlyErrorMapper.toGeneralErrorMessage(result.error, action: 'scanner pairing');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = UserFriendlyErrorMapper.toGeneralErrorMessage(e, action: 'scanner pairing');
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollCount++;
      if (_pollCount > 100) {
        // ~5 minutes timeout
        timer.cancel();
        if (mounted) {
          setState(() => _currentStep = _LinkSheetStep.timeout);
        }
        return;
      }

      try {
        final checkFn = widget.onCheckStatus ??
            SupabaseService.instance.checkHowbodySessionStatus;
        final status = await checkFn(widget.scanId);
        if (!mounted) return;

        if (status.isCompleted) {
          timer.cancel();
          HapticFeedback.heavyImpact();
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '3D Body Scan Complete! Your clinical report is ready.',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: InclineColors.accentOrange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );

          InBodyScanSheet.show(context, member: widget.member);
        } else if (status.isFailed) {
          timer.cancel();
          setState(() {
            _currentStep = _LinkSheetStep.error;
            _errorMessage = 'Scan session failed or cancelled at the kiosk.';
          });
        }
      } catch (e) {
        debugPrint('[INCLINE] Polling status notice: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? InclineColors.bgPrimary : InclineColors.lightBgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _buildCurrentContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent(bool isDark) {
    switch (_currentStep) {
      case _LinkSheetStep.form:
        return _buildFormContent(isDark);
      case _LinkSheetStep.polling:
        return _buildPollingContent(isDark);
      case _LinkSheetStep.error:
        return _buildErrorContent(isDark);
      case _LinkSheetStep.timeout:
        return _buildTimeoutContent(isDark);
    }
  }

  Widget _buildFormContent(bool isDark) {
    final label = _deviceLabel ?? 'Incline 3D Scanner — ${widget.equipmentNo}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Pill
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header with Scanner Branding
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: InclineColors.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: InclineColors.accentOrange.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                color: InclineColors.accentOrange,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link to Incline 3D Scanner',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: InclineColors.accentOrange,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: InclineColors.accentOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Unified 3D Volumetric & Posture Scan Information
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AF0441C) : const Color(0x10F0441C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x33F0441C)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: InclineColors.accentOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  size: 18,
                  color: InclineColors.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D Volumetric & Posture Assessment',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Body composition, lean mass & 360° avatar telemetry are captured together in one scan.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Height Header & Unit Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'MEMBER HEIGHT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUnitTogglePill('Metric (cm)', HeightUnit.cm, isDark),
                  _buildUnitTogglePill('Imperial (ft/in)', HeightUnit.ftIn, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Height Input Fields
        if (_unit == HeightUnit.cm)
          TextField(
            controller: _cmController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'Height in Centimeters',
              suffixText: 'cm',
              prefixIcon: const Icon(Icons.height_rounded, color: InclineColors.accentOrange),
              filled: true,
              fillColor: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: InclineColors.accentOrange, width: 2),
              ),
            ),
            onChanged: _onCmChanged,
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _feetController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Feet',
                    suffixText: 'ft',
                    filled: true,
                    fillColor: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: InclineColors.accentOrange, width: 2),
                    ),
                  ),
                  onChanged: (_) => _onImperialChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _inchesController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Inches',
                    suffixText: 'in',
                    filled: true,
                    fillColor: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: InclineColors.accentOrange, width: 2),
                    ),
                  ),
                  onChanged: (_) => _onImperialChanged(),
                ),
              ),
            ],
          ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Action Button: Link Scanner
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _linkScanner,
            style: ElevatedButton.styleFrom(
              backgroundColor: InclineColors.accentOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Link Scanner to Profile',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: Text(
            'Accurate height is required by optical impedance sensors for clinical BMI.',
            style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitTogglePill(String label, HeightUnit unit, bool isDark) {
    final isSelected = _unit == unit;

    return InkWell(
      onTap: () {
        if (_unit != unit) {
          HapticFeedback.selectionClick();
          setState(() {
            _unit = unit;
          });
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? InclineColors.accentOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: "Step on the Scanner" Polling State
  // ---------------------------------------------------------------------------
  Widget _buildPollingContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag Pill
        Container(
          width: 44,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Rotating radar / turntable indicator
        RotationTransition(
          turns: _radarController,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  InclineColors.accentOrange.withValues(alpha: 0.1),
                  InclineColors.accentOrange,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? InclineColors.bgPrimary : InclineColors.lightBgPrimary,
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  size: 36,
                  color: InclineColors.accentOrange,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Step onto the Turntable',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Remain still while the optical 3D sensors rotate and complete your telemetry calibration.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Device & Session Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: InclineColors.accentOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: InclineColors.accentOrange,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Scanner Active · 3D Body & Posture Assessment',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: InclineColors.accentOrange,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Cancel / Dismiss
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              _pollTimer?.cancel();
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Cancel Scan',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildErrorContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
        const SizedBox(height: 14),
        Text(
          'Scanner Session Failed',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'The scanner reported a fault or the session was cancelled.',
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = _LinkSheetStep.polling;
                    _errorMessage = null;
                  });
                  _startPolling();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: InclineColors.accentOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry Polling'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeoutContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, size: 48, color: InclineColors.thermalAmber),
        const SizedBox(height: 14),
        Text(
          'Scanning Timeout',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The scanner did not finish reporting within 5 minutes. You can check the Scan Reports tab once the kiosk finishes.',
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: InclineColors.accentOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Acknowledge & Close'),
          ),
        ),
      ],
    );
  }
}
