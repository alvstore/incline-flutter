import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

/// Displays the member's HOWBODY OBJ scan, with discrete camera photos as the
/// fallback. Photos are never animated as if they were a continuous 3D model.
class Anatomical3DVolumetricViewer extends StatefulWidget {
  final List<PosturePhoto> photos;
  final String? modelUrl;
  final DateTime? scanDate;

  const Anatomical3DVolumetricViewer({
    super.key,
    this.photos = const [],
    this.modelUrl,
    this.scanDate,
  });

  @override
  State<Anatomical3DVolumetricViewer> createState() =>
      _Anatomical3DVolumetricViewerState();
}

class _Anatomical3DVolumetricViewerState
    extends State<Anatomical3DVolumetricViewer> {
  double _modelProgress = 0;
  bool _isModelLoading = false;
  bool _modelFailed = false;

  @override
  void initState() {
    super.initState();
    _isModelLoading = _prepareObjViewerSource(widget.modelUrl) != null;
  }

  @override
  void didUpdateWidget(covariant Anatomical3DVolumetricViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) {
      _modelProgress = 0;
      _modelFailed = false;
      _isModelLoading = _prepareObjViewerSource(widget.modelUrl) != null;
    }
  }

  PosturePhoto? get _fallbackPhoto {
    if (widget.photos.isEmpty) return null;
    for (final photo in widget.photos) {
      if (photo.angle.toLowerCase() == 'front') return photo;
    }
    return widget.photos.first;
  }

  void _onModelProgress(double progress) {
    if (!mounted) return;
    setState(() => _modelProgress = progress.clamp(0.0, 1.0).toDouble());
  }

  void _onModelLoaded(String _) {
    if (!mounted) return;
    setState(() {
      _isModelLoading = false;
      _modelProgress = 1;
    });
  }

  void _onModelError(String _) {
    if (!mounted || _modelFailed) return;
    setState(() {
      _isModelLoading = false;
      _modelFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelSource = _prepareObjViewerSource(widget.modelUrl);
    final hasModel = modelSource != null && !_modelFailed;
    final fallbackPhoto = _fallbackPhoto;
    final hasPhotoFallback = !hasModel && fallbackPhoto != null;

    final title = hasModel
        ? 'HOWBODY 3D SCAN'
        : hasPhotoFallback
            ? 'HOWBODY SCAN PHOTOS'
            : 'BODY SCAN';
    final statusColor = hasModel
        ? AppTheme.emerald
        : hasPhotoFallback
            ? InclineColors.accentOrange
            : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1418),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222C33)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.scanDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yyyy').format(widget.scanDate!),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFF0B0F12)),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.85,
                          colors: [
                            InclineColors.accentOrange.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasModel)
                    RepaintBoundary(
                      child: Flutter3DViewer.obj(
                        key: ValueKey(modelSource),
                        src: modelSource!,
                        scale: 5,
                        cameraX: 0,
                        cameraY: 0,
                        cameraZ: 10,
                        onProgress: _onModelProgress,
                        onLoad: _onModelLoaded,
                        onError: _onModelError,
                      ),
                    )
                  else if (!hasModel && fallbackPhoto != null)
                    Image.network(
                      fallbackPhoto.url,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: InclineColors.accentOrange,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const _UnavailableScanPhoto(),
                    )
                  else
                    _UnavailableBodyModel(modelFailed: _modelFailed),
                  if (hasModel && _isModelLoading)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: _modelProgress > 0 ? _modelProgress : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          InclineColors.accentOrange,
                        ),
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
}

class _UnavailableScanPhoto extends StatelessWidget {
  const _UnavailableScanPhoto();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 28),
        const SizedBox(height: 6),
        Text(
          'Scan photo unavailable',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

class _UnavailableBodyModel extends StatelessWidget {
  final bool modelFailed;

  const _UnavailableBodyModel({required this.modelFailed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          modelFailed ? Icons.error_outline_rounded : Icons.view_in_ar_outlined,
          color: Colors.white38,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          modelFailed
              ? '3D model unavailable for this scan'
              : 'No 3D model available for this scan',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// HOWBODY sends `murl`, and the web client loads that value with OBJLoader.
/// flutter_3d_controller identifies OBJ sources by a trailing .obj suffix. A
/// fragment provides that suffix without changing the HTTP path or query string.
String? _prepareObjViewerSource(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;

  final path = uri.path.toLowerCase();
  if (path.endsWith('.glb') ||
      path.endsWith('.gltf') ||
      path.endsWith('.fbx') ||
      path.endsWith('.pdf') ||
      path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png')) {
    return null;
  }

  return uri.replace(fragment: 'incline-body.obj').toString();
}

