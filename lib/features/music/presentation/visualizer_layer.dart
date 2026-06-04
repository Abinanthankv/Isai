import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:isai/main.dart';
import 'music_providers.dart';
import 'audio_visualizer_painter.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../player/data/audio_handler.dart';
import '../../player/data/visualizer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Album art color extraction cache
// ─────────────────────────────────────────────────────────────────────────────

/// Global cache so we only extract colors once per artwork URL.
final Map<String, Color> _artworkColorCache = {};

Future<Color> _extractDominantColor(String? artworkUrl) async {
  if (artworkUrl == null || artworkUrl.isEmpty) {
    return AppleMusicTheme.primaryPink;
  }
  if (_artworkColorCache.containsKey(artworkUrl)) {
    return _artworkColorCache[artworkUrl]!;
  }
  try {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(artworkUrl),
      maximumColorCount: 8,
    );
    // Prefer muted color for a more subtle, blended look (like the screenshot)
    final color = paletteGenerator.mutedColor?.color
        ?? paletteGenerator.dominantColor?.color
        ?? AppleMusicTheme.primaryPink;
    _artworkColorCache[artworkUrl] = color;
    return color;
  } catch (e) {
    print('[VisualizerLayer] Color extraction failed: $e');
    return AppleMusicTheme.primaryPink;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission helper — only called when user enables the visualizer
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> requestVisualizerPermission(BuildContext context) async {
  if (!Platform.isAndroid) return false;

  final status = await Permission.microphone.status;
  if (status.isGranted) return true;

  // Show rationale before requesting
  final shouldRequest = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.equalizer_rounded, color: AppleMusicTheme.primaryPink, size: 48),
      title: const Text(
        'Audio Visualizer',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'To make the visualizer react to your music in real-time, '
        'Isai needs microphone access.\n\n'
        'This is required by Android\'s audio analysis API — '
        'we never record or store any audio.\n\n'
        'Without this permission, the visualizer will use '
        'animated patterns instead.',
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppleMusicTheme.primaryPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Allow', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  ) ?? false;

  if (!shouldRequest) return false;

  final result = await Permission.microphone.request();
  return result.isGranted;
}

// ─────────────────────────────────────────────────────────────────────────────
// VisualizerOverlay — full Now Playing overlay
// ─────────────────────────────────────────────────────────────────────────────

class VisualizerOverlay extends ConsumerStatefulWidget {
  final Color? albumArtColor;

  const VisualizerOverlay({super.key, this.albumArtColor});

  @override
  ConsumerState<VisualizerOverlay> createState() => _VisualizerOverlayState();
}

class _VisualizerOverlayState extends ConsumerState<VisualizerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final VisualizerService _vizService = VisualizerService();
  StreamSubscription<List<int>>? _fftSub;
  List<int>? _currentFft;
  List<double>? _smoothedFft;
  bool _vizStarted = false;
  Color _artColor = AppleMusicTheme.primaryPink;
  String? _lastArtUrl;

  static const double _smoothingFactor = 0.2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  void _startNativeVisualizer() {
    if (!Platform.isAndroid || _vizStarted) return;
    _vizStarted = true;

    final handler = audioHandler as MyAudioHandler;
    final sessionId = handler.androidAudioSessionIdSync;
    if (sessionId != null) {
      _vizService.start(sessionId);
      _fftSub = _vizService.fftStream.listen((data) {
        if (mounted) {
          setState(() {
            _currentFft = data;
            
            // Apply smoothing
            if (_smoothedFft == null || _smoothedFft!.length != data.length) {
              _smoothedFft = data.map((e) => e.toDouble()).toList();
            } else {
              for (int i = 0; i < data.length; i++) {
                _smoothedFft![i] = (_smoothedFft![i] * (1 - _smoothingFactor)) + 
                                   (data[i].toDouble() * _smoothingFactor);
              }
            }
          });
        }
      });
    }
  }

  void _stopNativeVisualizer() {
    _fftSub?.cancel();
    _fftSub = null;
    _vizService.stop();
    _vizStarted = false;
    _currentFft = null;
    _smoothedFft = null;
  }

  Future<void> _updateArtworkColor(String? artUrl) async {
    if (artUrl == _lastArtUrl) return;
    _lastArtUrl = artUrl;
    final color = await _extractDominantColor(artUrl);
    if (mounted) setState(() => _artColor = color);
  }

  double _getBpm(MediaItem? item) {
    if (item == null) return 120.0;
    final title = item.title;
    final artist = item.artist ?? '';
    final hash = (title + artist).hashCode.abs();
    return 70.0 + (hash % 81);
  }

  void _updateBpm(MediaItem? item) {
    if (item == null) return;
    final bpm = _getBpm(item);
    final durationMs = (120.0 / bpm * 3000).round().clamp(1500, 6000);
    
    if (_controller.duration?.inMilliseconds != durationMs) {
      _controller.duration = Duration(milliseconds: durationMs);
      if (_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _stopNativeVisualizer();
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor(SettingsState settings) {
    switch (settings.visualizerColorMode) {
      case 'albumArt':
        return _artColor;
      case 'vibrant':
        return const Color(0xFF00E676);
      case 'custom':
        return AppleMusicTheme.primaryPink;
      case 'dynamic':
      default:
        final hue = (_controller.value * 360) % 360;
        return HSLColor.fromAHSL(1.0, hue, 0.8, 0.55).toColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (!settings.visualizerEnabled || !settings.visualizerShowNowPlaying) {
      _stopNativeVisualizer();
      return const SizedBox.shrink();
    }

    // Start native visualizer on demand
    if (!_vizStarted) _startNativeVisualizer();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnap) {
        final artUrl = mediaSnap.data?.artUri?.toString();
        _updateArtworkColor(artUrl);
        _updateBpm(mediaSnap.data);

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final color = _resolveColor(settings);
                final screenHeight = MediaQuery.of(context).size.height;
                final vizHeight = screenHeight * settings.visualizerHeightPct;

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: settings.visualizerBaseLift,
                  height: vizHeight,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: AudioVisualizerPainter(
                          style: settings.visualizerStyle,
                          pointCount: settings.visualizerPoints,
                          sensitivity: settings.visualizerSensitivity * 10,
                          amplitude: settings.visualizerAmplitude * 8,
                          animationValue: _controller.value,
                          color: color,
                          alpha: settings.visualizerAlpha,
                          barSpacing: settings.visualizerBarSpacing,
                          cornerRadius: settings.visualizerCornerRadius,
                          isPlaying: isPlaying,
                          bpm: _getBpm(mediaSnap.data),
                          fftMagnitudes: _smoothedFft?.map((e) => e.round()).toList() ?? _currentFft,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
