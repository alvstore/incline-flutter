import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// Luxury 16:9 Aspect Ratio In-App Exercise Video & Form Visualizer
///
/// Features:
/// - Plays MP4 and WebP animations directly INSIDE the app without redirecting or external links.
/// - WebP/GIF animations render natively with zero buffer overhead.
/// - MP4 streams utilize VideoPlayerController with auto-looping and form guidance.
/// - Default 0.75× slow-motion tempo for biomechanics study.
/// - In-place tap-to-play/pause and audio mute/unmute controls.
class ExerciseVideoCard extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final String? thumbnailUrl;

  const ExerciseVideoCard({
    super.key,
    required this.videoUrl,
    this.title,
    this.thumbnailUrl,
  });

  @override
  State<ExerciseVideoCard> createState() => _ExerciseVideoCardState();
}

class _ExerciseVideoCardState extends State<ExerciseVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _hasError = false;
  double _playbackSpeed = 0.75;

  bool get _isWebpOrImage {
    final lower = widget.videoUrl.toLowerCase();
    return lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg');
  }

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.trim().isEmpty) {
      _hasError = true;
    } else if (!_isWebpOrImage) {
      _initVideoPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      if (widget.videoUrl.trim().isEmpty) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _isInitialized = false;
        });
      } else if (!_isWebpOrImage) {
        _initVideoPlayer();
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initVideoPlayer() async {
    final trimmed = widget.videoUrl.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _isInitialized = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _hasError = false;
      });
    }

    String playUrl = trimmed;
    final uri = Uri.tryParse(trimmed);
    final hasScheme = uri != null && uri.hasScheme;

    // Gracefully handle relative storage paths without flashing errors
    if (!hasScheme || trimmed.startsWith('exercisedb/') || trimmed.startsWith('/exercisedb/')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      try {
        if (SupabaseService.instance.isClientAvailable) {
          final signed = await SupabaseService.instance.client.storage
              .from('inclineexercisedb')
              .createSignedUrl(cleanPath, 86400);
          if (signed.isNotEmpty) {
            playUrl = signed;
          }
        }
      } catch (e) {
        debugPrint('[INCLINE] ExerciseVideoCard dynamic signing notice: $e');
      }
    }

    final playUri = Uri.tryParse(playUrl);
    if (playUri == null || !playUri.hasScheme) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _isInitialized = false;
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(playUri);
      _controller = controller;
      controller.addListener(_onControllerUpdate);

      await controller.initialize();
      if (!mounted) {
        controller.removeListener(_onControllerUpdate);
        controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(0.0); // Muted by default for gym privacy
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] ExerciseVideoCard player error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _isInitialized = false;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isInitializing = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlayPause() {
    if (widget.videoUrl.trim().isEmpty || _hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video demo URL is unavailable',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isInitializing || _controller == null || !_isInitialized) {
      // Currently loading / buffering: safely ignore tap instead of flashing error SnackBar
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _toggleSpeed() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.selectionClick();
    final nextSpeed = _playbackSpeed == 0.75 ? 1.0 : 0.75;
    _controller!.setPlaybackSpeed(nextSpeed);
    setState(() => _playbackSpeed = nextSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderCol),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Media Content (WebP Image vs In-App MP4 VideoPlayer vs Fallback)
              if (widget.videoUrl.trim().isEmpty || _hasError)
                _buildFallbackBackground(context, errorMessage: 'Form video stream unavailable')
              else if (_isWebpOrImage)
                _buildWebpContent()
              else if (_isInitialized && _controller != null)
                _buildVideoContent()
              else
                _buildLoadingBackground(context),

              // 2. Play / Pause Tap Overlay for MP4 Videos
              if (!_isWebpOrImage)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePlayPause,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: AnimatedOpacity(
                        opacity: (_isInitializing || (_controller != null && _controller!.value.isPlaying)) ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: context.brandAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 34,
                                color: context.brandAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Top-Right Badge: Slow-Mo Speed Toggle Pill
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: (!_isWebpOrImage && _isInitialized) ? _toggleSpeed : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: context.brandAccent.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.slow_motion_video_rounded, size: 12, color: context.brandAccent),
                        const SizedBox(width: 4),
                        Text(
                          _isWebpOrImage
                              ? '0.75× SLOW-MO'
                              : (_playbackSpeed == 0.75 ? '0.75× SLOW-MO' : '1.0× SPEED'),
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: context.brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Bottom-Left Title & Tag Pill (Semi-Transparent so machine animation shows through)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${widget.title ?? 'Form video'} · 0.75×',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Video Progress Bar at the bottom
              if (!_isWebpOrImage && _isInitialized && _controller != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: SizedBox(
                      height: 3,
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: context.brandAccent,
                          bufferedColor: Colors.white.withValues(alpha: 0.2),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebpContent() {
    return Image.network(
      widget.videoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackBackground(context),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingBackground(context);
      },
    );
  }

  Widget _buildVideoContent() {
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
        height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildLoadingBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          Image.network(
            widget.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackBackground(context),
          )
        else
          _buildFallbackBackground(context),
        Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(context.brandAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBackground(BuildContext context, {String? errorMessage}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cardElevated,
            context.cardBg,
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 40,
              color: context.textMuted.withValues(alpha: 0.3),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                errorMessage,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  color: context.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
