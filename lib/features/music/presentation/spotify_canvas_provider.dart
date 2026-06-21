import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/scrapers/spotify_canvas_resolver.dart';

class SpotifyCanvasState {
  final String? canvasUrl;
  final bool isLoading;
  final String? error;

  SpotifyCanvasState({
    this.canvasUrl,
    this.isLoading = false,
    this.error,
  });

  SpotifyCanvasState copyWith({
    String? canvasUrl,
    bool? isLoading,
    String? error,
  }) {
    return SpotifyCanvasState(
      canvasUrl: canvasUrl ?? this.canvasUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class SpotifyCanvasNotifier extends Notifier<SpotifyCanvasState> {
  final SpotifyCanvasResolver _resolver = SpotifyCanvasResolver();
  final Map<String, String?> _cache = {};
  String? _currentTrackKey;

  @override
  SpotifyCanvasState build() => SpotifyCanvasState();

  Future<void> fetchCanvas(String track, String artist) async {
    final trackKey = '$artist-$track';
    
    if (_currentTrackKey == trackKey) return;
    _currentTrackKey = trackKey;

    if (_cache.containsKey(trackKey)) {
      state = SpotifyCanvasState(canvasUrl: _cache[trackKey]);
      return;
    }

    state = SpotifyCanvasState(isLoading: true);

    try {
      final url = await _resolver.resolveCanvas(artist, track);
      _cache[trackKey] = url;
      if (_currentTrackKey == trackKey) {
        state = SpotifyCanvasState(canvasUrl: url);
      }
    } catch (e) {
      _cache[trackKey] = null;
      if (_currentTrackKey == trackKey) {
        state = SpotifyCanvasState(error: e.toString());
      }
    }
  }

  void clear() {
    _currentTrackKey = null;
    state = SpotifyCanvasState();
  }
}

final spotifyCanvasProvider = NotifierProvider<SpotifyCanvasNotifier, SpotifyCanvasState>(() {
  return SpotifyCanvasNotifier();
});
