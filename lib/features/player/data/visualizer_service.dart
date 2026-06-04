import 'dart:async';
import 'package:flutter/services.dart';

/// Dart-side bridge to the native Android Visualizer.
///
/// Provides a stream of FFT magnitude data (List<int>, 0–255 per bin)
/// that updates ~10 times per second while music is playing.
///
/// Usage:
/// ```dart
/// final service = VisualizerService();
/// await service.start(audioSessionId);
/// service.fftStream.listen((magnitudes) { ... });
/// ```
class VisualizerService {
  static const _methodChannel = MethodChannel('com.isai.music/visualizer');
  static const _eventChannel = EventChannel('com.isai.music/visualizer_fft');

  static final VisualizerService _instance = VisualizerService._internal();
  factory VisualizerService() => _instance;
  VisualizerService._internal();

  Stream<List<int>>? _fftStream;
  bool _isStarted = false;

  /// A broadcast stream of FFT magnitude values.
  /// Each event is a List<int> where each element is 0–255 representing
  /// the magnitude of a frequency bin.
  Stream<List<int>> get fftStream {
    _fftStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((data) {
          if (data is List) {
            return data.cast<int>();
          }
          return <int>[];
        })
        .asBroadcastStream();
    return _fftStream!;
  }

  /// Start capturing FFT data for the given audio session.
  /// [audioSessionId] comes from `AudioPlayer.androidAudioSessionId`.
  Future<void> start(int audioSessionId) async {
    if (_isStarted) return;
    try {
      await _methodChannel.invokeMethod('start', audioSessionId);
      _isStarted = true;
    } on PlatformException catch (e) {
      print('[VisualizerService] Failed to start: $e');
    }
  }

  /// Stop capturing FFT data and release native resources.
  Future<void> stop() async {
    if (!_isStarted) return;
    try {
      await _methodChannel.invokeMethod('stop');
      _isStarted = false;
    } on PlatformException catch (e) {
      print('[VisualizerService] Failed to stop: $e');
    }
  }

  bool get isStarted => _isStarted;
}
