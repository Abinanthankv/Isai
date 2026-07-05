import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/youtube_video_service.dart';
import '../data/youtube_models.dart';

class YoutubeMusicVideoState {
  final YoutubeVideoInfo? videoInfo;
  final bool isLoading;
  final String? error;
  final bool enabled;

  YoutubeMusicVideoState({
    this.videoInfo,
    this.isLoading = false,
    this.error,
    this.enabled = false,
  });

  YoutubeMusicVideoState copyWith({
    YoutubeVideoInfo? videoInfo,
    bool? isLoading,
    String? error,
    bool? enabled,
  }) {
    return YoutubeMusicVideoState(
      videoInfo: videoInfo ?? this.videoInfo,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      enabled: enabled ?? this.enabled,
    );
  }
}

class YoutubeMusicVideoNotifier extends Notifier<YoutubeMusicVideoState> {
  final YoutubeVideoService _service = YoutubeVideoService();
  final Map<String, YoutubeVideoInfo?> _cache = {};
  String? _currentTrackKey;

  @override
  YoutubeMusicVideoState build() => YoutubeMusicVideoState();

  Future<void> fetchVideo(String title, String artist) async {
    final trackKey = '$artist - $title';
    if (_currentTrackKey == trackKey) return;
    _currentTrackKey = trackKey;

    if (_cache.containsKey(trackKey)) {
      final cached = _cache[trackKey];
      if (cached != null) {
        state = YoutubeMusicVideoState(videoInfo: cached);
      }
      return;
    }

    state = YoutubeMusicVideoState(isLoading: true);

    try {
      final results = await _service.search('$title $artist official music video');
      if (results.isEmpty) {
        _cache[trackKey] = null;
        if (_currentTrackKey == trackKey) {
          state = YoutubeMusicVideoState(error: 'No results');
        }
        return;
      }

      final best = results.first;
      final info = await _service.getVideoInfo(best.id);
      _cache[trackKey] = info;
      if (_currentTrackKey == trackKey) {
        state = YoutubeMusicVideoState(videoInfo: info);
      }
    } catch (e) {
      _cache[trackKey] = null;
      if (_currentTrackKey == trackKey) {
        state = YoutubeMusicVideoState(error: e.toString());
      }
    }
  }

  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
  }

  void clear() {
    _currentTrackKey = null;
    state = YoutubeMusicVideoState();
  }

  void dispose() {
    _service.dispose();
  }
}

final youtubeMusicVideoProvider = NotifierProvider<YoutubeMusicVideoNotifier, YoutubeMusicVideoState>(() {
  return YoutubeMusicVideoNotifier();
});
