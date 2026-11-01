import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import 'howbody_link_sheet.dart';

/// Official HOWBODY QR Code Payload Contract (PROJECT.md § Interface Contracts)
class HowbodyQrPayload {
  final String equipmentNo;
  final String scanId;
  final String kind; // 'body' or 'posture'

  const HowbodyQrPayload({
    required this.equipmentNo,
    required this.scanId,
    required this.kind,
  });

  static HowbodyQrPayload? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    // 1. URI query parsing (e.g., https://inclinegym.com/scan-login?equipmentNo=... or /howbody-login)
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasQuery) {
        final q = uri.queryParameters;
        final eq = (q['equipmentNo'] ?? q['equipment_no'] ?? q['device'] ?? '').trim();
        final sid = (q['scanId'] ?? q['scan_id'] ?? q['session'] ?? '').trim();
        final kind = (q['kind'] ?? q['scanType'] ?? 'body').trim().toLowerCase();
        if (eq.isNotEmpty && sid.isNotEmpty) {
          return HowbodyQrPayload(
            equipmentNo: eq,
            scanId: sid,
            kind: kind == 'posture' ? 'posture' : 'body',
          );
        }
      }
    } catch (_) {}

    // 2. Direct query string (e.g., equipmentNo=INC-HOWBODY-UDR-01&scanId=1029384&kind=posture)
    try {
      final q = Uri.splitQueryString(trimmed);
      final eq = (q['equipmentNo'] ?? q['equipment_no'] ?? q['device'] ?? '').trim();
      final sid = (q['scanId'] ?? q['scan_id'] ?? q['session'] ?? '').trim();
      final kind = (q['kind'] ?? q['scanType'] ?? 'body').trim().toLowerCase();
      if (eq.isNotEmpty && sid.isNotEmpty) {
        return HowbodyQrPayload(
          equipmentNo: eq,
          scanId: sid,
          kind: kind == 'posture' ? 'posture' : 'body',
        );
      }
    } catch (_) {}

    // 3. JSON format
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final eq = (decoded['equipmentNo'] ?? decoded['equipment_no'] ?? decoded['device'])?.toString().trim() ?? '';
        final sid = (decoded['scanId'] ?? decoded['scan_id'] ?? decoded['session'])?.toString().trim() ?? '';
        final kind = (decoded['kind'] ?? decoded['scanType'] ?? 'body').toString().trim().toLowerCase();
        if (eq.isNotEmpty && sid.isNotEmpty) {
          return HowbodyQrPayload(
            equipmentNo: eq,
            scanId: sid,
            kind: kind == 'posture' ? 'posture' : 'body',
          );
        }
      }
    } catch (_) {}

    return null;
  }
}

/// Modal bottom sheet with camera viewfinder for scanning Incline 3D Scanner QR codes.
class HowbodyQrScannerSheet extends StatefulWidget {
  final Member? member;
  final void Function(HowbodyQrPayload payload)? onPayloadDetected;

  const HowbodyQrScannerSheet({
    super.key,
    this.member,
    this.onPayloadDetected,
  });

  static Future<void> show(
    BuildContext context, {
    Member? member,
    void Function(HowbodyQrPayload payload)? onPayloadDetected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HowbodyQrScannerSheet(
        member: member,
        onPayloadDetected: onPayloadDetected,
      ),
    );
  }

  @override
  State<HowbodyQrScannerSheet> createState() => _HowbodyQrScannerSheetState();
}

class _HowbodyQrScannerSheetState extends State<HowbodyQrScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  bool _isDispatched = false;
  bool _torchActive = false;
  DateTime? _lastInvalidToast;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTestEnvironment) {
      _laserController.repeat(reverse: true);
    } else {
      _laserController.value = 0.5;
    }

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDispatched || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        final payload = HowbodyQrPayload.parse(raw);
        if (payload != null) {
          _isDispatched = true;
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop();

          if (widget.onPayloadDetected != null) {
            widget.onPayloadDetected!(payload);
          } else {
            HowbodyLinkSheet.show(
              context,
              equipmentNo: payload.equipmentNo,
              scanId: payload.scanId,
              initialKind: payload.kind,
              member: widget.member,
            );
          }
          break;
        } else {
          // Polite notification when an unrecognized or non-HOWBODY barcode is in viewfinder
          final now = DateTime.now();
          if (_lastInvalidToast == null || now.difference(_lastInvalidToast!).inSeconds >= 3) {
            _lastInvalidToast = now;
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: InclineColors.accentOrange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unrecognized QR Code. Please point at the active Incline 3D Scanner screen.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1E1E20),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _torchActive = !_torchActive);
    } catch (e) {
      debugPrint('[INCLINE] Torch toggle notice: $e');
    }
  }

  void _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (e) {
      debugPrint('[INCLINE] Camera switch notice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Camera Viewfinder
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return Container(
                    color: InclineColors.bgPrimary,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off_rounded, size: 48, color: InclineColors.thermalAmber),
                          const SizedBox(height: 12),
                          Text(
                            'Camera Simulation Mode',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please align the QR code displayed on the kiosk screen.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Dark Gradient Vignette for HUD Contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Central HUD Reticle Frame
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // Corner Guides
                  Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
                  Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
                  Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
                  Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, _) {
                      return Positioned(
                        top: _laserAnimation.value * 256,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: InclineColors.accentOrange,
                            boxShadow: [
                              BoxShadow(
                                color: InclineColors.accentOrange.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // HUD Helper Text
          Positioned(
            left: 20,
            right: 20,
            top: (size.height * 0.44) + 145,
            child: Column(
              children: [
                Text(
                  'Align Incline 3D Scanner QR Code within the frame',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Displays instantly on the kiosk screen before starting your scan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white70,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Top App Bar Controls
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleTorch,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _torchActive
                                ? InclineColors.accentOrange
                                : Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _torchActive
                                  ? InclineColors.accentOrange
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            _torchActive ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _switchCamera,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    const double length = 28;
    const double thickness = 3.5;
    const color = InclineColors.accentOrange;

    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          isTop: isTop,
          isLeft: isLeft,
          color: color,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;
  final double thickness;

  _CornerBracketPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
