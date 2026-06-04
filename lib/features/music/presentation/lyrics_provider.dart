import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lyrics_models.dart';
import '../data/scrapers/lyrics_scraper.dart';

class LyricsState {
  final LyricsData? lyrics;
  final bool isLoading;
  final String? error;

  LyricsState({this.lyrics, this.isLoading = false, this.error});

  LyricsState copyWith({LyricsData? lyrics, bool? isLoading, String? error}) {
    return LyricsState(
      lyrics: lyrics ?? this.lyrics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  final LyricsScraper _scraper = LrclibScraper();
  String? _currentTrackKey;
  int _lastRequestId = 0;

  @override
  LyricsState build() => LyricsState();

  Future<void> fetchLyrics(String track, String artist, {String? album, int? durationMs, bool force = false}) async {
    final trackKey = '$artist-$track-${durationMs ?? 0}';
    
    // Skip if already loading or already have lyrics for this track
    if (!force && _currentTrackKey == trackKey && (state.lyrics != null || state.isLoading)) {
      return;
    }

    _currentTrackKey = trackKey;
    final requestId = ++_lastRequestId;
    
    // Clear previous state on new fetch
    state = LyricsState(isLoading: true);

    try {
      final lyrics = await _scraper.getLyrics(track, artist, album: album, durationMs: durationMs);
      
      // Only update if this is still the latest request
      if (requestId == _lastRequestId) {
        if (lyrics != null) {
          state = state.copyWith(lyrics: lyrics, isLoading: false);
        } else {
          state = state.copyWith(isLoading: false, error: 'Lyrics not found');
        }
      }
    } catch (e) {
      if (requestId == _lastRequestId) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void clear() {
    _currentTrackKey = null;
    _lastRequestId++;
    state = LyricsState();
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(() {
  return LyricsNotifier();
});
