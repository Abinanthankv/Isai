import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lyrics_models.dart';
import '../data/scrapers/lyrics_scraper.dart';

enum LyricsProviderType {
  auto,
  lyricsOvh,
  lrclib,
}

class LyricsState {
  final LyricsData? lyrics;
  final bool isLoading;
  final String? error;
  final LyricsProviderType selectedProvider;

  LyricsState({
    this.lyrics,
    this.isLoading = false,
    this.error,
    this.selectedProvider = LyricsProviderType.auto,
  });

  LyricsState copyWith({
    LyricsData? lyrics,
    bool? isLoading,
    String? error,
    LyricsProviderType? selectedProvider,
  }) {
    return LyricsState(
      lyrics: lyrics ?? this.lyrics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedProvider: selectedProvider ?? this.selectedProvider,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  final LyricsScraper _lyricsOvhScraper = LyricsOvhScraper();
  final LyricsScraper _lrclibScraper = LrclibScraper();
  String? _currentTrackKey;
  int _lastRequestId = 0;
  
  // Cache of trackKey -> Map of providerName -> LyricsData
  final Map<String, Map<String, LyricsData>> _lyricsCache = {};

  @override
  LyricsState build() => LyricsState();

  Future<void> fetchLyrics(String track, String artist, {String? album, int? durationMs, bool force = false}) async {
    final trackKey = '$artist-$track-${durationMs ?? 0}';
    final providerKey = state.selectedProvider.name;

    // Check cache first to avoid refetching loaded lyrics
    final cachedTrack = _lyricsCache[trackKey];
    if (cachedTrack != null) {
      if (state.selectedProvider == LyricsProviderType.auto) {
        final lyricsOvhLyrics = cachedTrack[LyricsProviderType.lyricsOvh.name];
        final lrclibLyrics = cachedTrack[LyricsProviderType.lrclib.name];
        final autoLyrics = lyricsOvhLyrics ?? lrclibLyrics;
        if (autoLyrics != null) {
          state = state.copyWith(lyrics: autoLyrics, isLoading: false, error: null);
          _currentTrackKey = trackKey;
          return;
        }
      } else {
        final cachedLyrics = cachedTrack[providerKey];
        if (cachedLyrics != null) {
          state = state.copyWith(lyrics: cachedLyrics, isLoading: false, error: null);
          _currentTrackKey = trackKey;
          return;
        }
      }
    }

    // Skip if already loading or already have lyrics for this track (unless forced)
    if (!force && _currentTrackKey == trackKey && (state.lyrics != null || state.isLoading)) {
      return;
    }

    _currentTrackKey = trackKey;
    final requestId = ++_lastRequestId;
    
    // Clear previous lyrics but keep the selected provider state on new fetch
    state = state.copyWith(lyrics: null, isLoading: true, error: null);

    // Build the list of scrapers based on selected provider
    final scrapers = <MapEntry<LyricsProviderType, LyricsScraper>>[];
    if (state.selectedProvider == LyricsProviderType.auto || state.selectedProvider == LyricsProviderType.lyricsOvh) {
      scrapers.add(MapEntry(LyricsProviderType.lyricsOvh, _lyricsOvhScraper));
    }
    if (state.selectedProvider == LyricsProviderType.auto || state.selectedProvider == LyricsProviderType.lrclib) {
      scrapers.add(MapEntry(LyricsProviderType.lrclib, _lrclibScraper));
    }

    try {
      LyricsData? lyrics;
      for (final entry in scrapers) {
        // Double check cache for individual scraper
        final cached = _lyricsCache[trackKey]?[entry.key.name];
        if (cached != null) {
          lyrics = cached;
          break;
        }

        lyrics = await entry.value.getLyrics(track, artist, album: album, durationMs: durationMs);
        if (lyrics != null) {
          _lyricsCache.putIfAbsent(trackKey, () => {})[entry.key.name] = lyrics;
          break;
        }
      }
      
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

  void setProvider(LyricsProviderType provider, String track, String artist, {String? album, int? durationMs}) {
    if (state.selectedProvider != provider) {
      state = state.copyWith(selectedProvider: provider);
      fetchLyrics(track, artist, album: album, durationMs: durationMs, force: true);
    }
  }

  void clear() {
    _currentTrackKey = null;
    _lastRequestId++;
    state = LyricsState(selectedProvider: state.selectedProvider);
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(() {
  return LyricsNotifier();
});

