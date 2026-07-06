import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
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

final Map<String, Color> _artworkColorCache = {};

Future<Color> _extractDominantColor(String? artworkUrl, Color fallbackColor) async {
  if (artworkUrl == null || artworkUrl.isEmpty) {
    return fallbackColor;
  }
  if (_artworkColorCache.containsKey(artworkUrl)) {
    return _artworkColorCache[artworkUrl]!;
  }
  try {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(artworkUrl),
      maximumColorCount: 8,
    );
    final color = paletteGenerator.mutedColor?.color
        ?? paletteGenerator.dominantColor?.color
        ?? fallbackColor;
    _artworkColorCache[artworkUrl] = color;
    return color;
  } catch (e) {
    print('[VisualizerLayer] Color extraction failed: $e');
    return fallbackColor;
  }
}

Future<bool> requestVisualizerPermission(BuildContext context) async {
  if (!Platform.isAndroid) return false;

  final status = await Permission.microphone.status;
  if (status.isGranted) return true;

  final shouldRequest = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.equalizer_rounded, color: Theme.of(context).colorScheme.primary, size: 48),
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
            backgroundColor: Theme.of(context).colorScheme.primary,
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
  List<double>? _normalizedFft;
  List<double>? _prevFft;
  bool _vizStarted = false;
  Color? _artColor;
  String? _lastArtUrl;

  double _rollingMax = 1.0;

  // Spectral flux beat detection
  double _fluxValue = 0.0;
  double _fluxAvg = 0.0;
  double _beatIntensity = 0.0;

  List<Color>? _barColors;
  int _lastBarColorCount = 0;

  static const double _smoothingFactor = 0.3;

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

            // Step 1: Exponential smoothing
            if (_smoothedFft == null || _smoothedFft!.length != data.length) {
              _smoothedFft = data.map((e) => e.toDouble()).toList();
            } else {
              for (int i = 0; i < data.length; i++) {
                _smoothedFft![i] = (_smoothedFft![i] * (1 - _smoothingFactor)) +
                                   (data[i].toDouble() * _smoothingFactor);
              }
            }

            // Step 2: Spectral flux beat detection
            if (_prevFft != null && _prevFft!.length == _smoothedFft!.length) {
              double flux = 0;
              for (int i = 1; i < _smoothedFft!.length; i++) {
                final delta = _smoothedFft![i] - _prevFft![i];
                if (delta > 0) flux += delta;
              }
              _fluxValue = _fluxValue * 0.6 + flux * 0.4;
              _fluxAvg = _fluxAvg * 0.92 + _fluxValue * 0.08;
              if (_fluxValue > _fluxAvg * 1.8 && flux > 30) {
                _beatIntensity = 1.0;
              }
            }
            _prevFft = List<double>.from(_smoothedFft!);
            _beatIntensity *= 0.88;
            if (_beatIntensity < 0.005) _beatIntensity = 0.0;

            // Step 3: Auto-gain normalization (separate list)
            final double currentMax = _smoothedFft!.reduce(math.max);
            _rollingMax = (_rollingMax * 0.9 + currentMax * 0.1).clamp(15.0, 255.0);
            final double scale = 200.0 / _rollingMax;
            _normalizedFft = _smoothedFft!.map((e) => (e * scale).clamp(0.0, 255.0)).toList();
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
    _normalizedFft = null;
    _prevFft = null;
  }

  Future<void> _updateArtworkColor(String? artUrl, Color fallbackColor) async {
    if (artUrl == _lastArtUrl) return;
    _lastArtUrl = artUrl;
    final color = await _extractDominantColor(artUrl, fallbackColor);
    if (mounted) setState(() => _artColor = color);
  }

  double _getBpm(MediaItem? item) {
    if (item == null) return 120.0;
    final title = item.title;
    final artist = item.artist ?? '';
    final hash = (title + artist).hashCode.abs();
    return 70.0 + (hash % 81);
  }

  List<Color> _generateBarColors(int count) {
    return List.generate(count, (i) {
      final fraction = count > 1 ? i / (count - 1) : 0.0;
      final hue = fraction * 270.0;
      return HSLColor.fromAHSL(1.0, hue, 0.8, 0.55).toColor();
    });
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
        return _artColor ?? Theme.of(context).colorScheme.primary;
      case 'vibrant':
        return const Color(0xFF00E676);
      case 'custom':
        return Theme.of(context).colorScheme.primary;
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

    if (!_vizStarted) _startNativeVisualizer();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnap) {
        final artUrl = mediaSnap.data?.artUri?.toString();
        _updateArtworkColor(artUrl, Theme.of(context).colorScheme.primary);
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

                if (_lastBarColorCount != settings.visualizerPoints && settings.visualizerPoints > 0) {
                  _lastBarColorCount = settings.visualizerPoints;
                  _barColors = _generateBarColors(settings.visualizerPoints);
                }

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
                            fftMagnitudes: _normalizedFft?.map((e) => e.round()).toList() ?? _currentFft,
                            barColors: settings.visualizerColorMode == 'dynamic' ? _barColors : null,
                            beatIntensity: _beatIntensity,
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
