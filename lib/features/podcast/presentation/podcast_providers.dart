import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isai/main.dart';
import '../data/podcast_models.dart';
import '../data/podcast_api_service.dart';

const podcastGenreNames = [
  'Comedy', 'Technology', 'Science', 'News', 'Music',
  'History', 'True Crime', 'Business', 'Health', 'Education',
  'Sports', 'TV & Film', 'Religion', 'Society', 'Arts',
  'Fiction', 'Kids & Family', 'Leisure', 'Government', 'How To',
];

final podcastApiServiceProvider = Provider<PodcastApiService>((ref) {
  return PodcastApiService();
});

final podcastSearchProvider = FutureProvider.family<List<PodcastSeries>, String>((ref, query) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.searchPodcasts(query);
});

final spotifyTopPodcastsUsProvider = FutureProvider<List<SpotifyChartItem>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.spotifyTopPodcasts('us', limit: 50);
});

final spotifyTopPodcastsInProvider = FutureProvider<List<SpotifyChartItem>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.spotifyTopPodcasts('in', limit: 50);
});

final spotifyTopEpisodesUsProvider = FutureProvider<List<SpotifyChartItem>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.spotifyTopEpisodes('us', limit: 50);
});

final spotifyTopEpisodesInProvider = FutureProvider<List<SpotifyChartItem>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.spotifyTopEpisodes('in', limit: 50);
});

final podcastRecentProvider = FutureProvider<List<PodcastSeries>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.recent(limit: 20);
});

final podcastByGenreProvider = FutureProvider.family<List<PodcastSeries>, String>((ref, genre) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.byGenre(genre, limit: 20);
});

final genrePodcastsProvider = StateNotifierProvider.family<GenrePodcastsNotifier, AsyncValue<List<PodcastSeries>>, String>((ref, genre) {
  return GenrePodcastsNotifier(ref.read(podcastApiServiceProvider), genre);
});

class GenrePodcastsNotifier extends StateNotifier<AsyncValue<List<PodcastSeries>>> {
  final PodcastApiService _api;
  final String _genre;
  bool _loading = false;

  GenrePodcastsNotifier(this._api, this._genre) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    state = const AsyncValue.loading();
    try {
      final results = await _api.byGenre(_genre, limit: 100);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    _loading = false;
  }

  void retry() => _load();
}

final podcastLookupProvider = FutureProvider.family<PodcastSeries?, int>((ref, collectionId) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.lookupPodcast(collectionId);
});

final podcastEpisodesProvider = FutureProvider.family<List<PodcastEpisode>, String>((ref, feedUrl) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.fetchEpisodes(feedUrl);
});

final podcastGenreFilterProvider = StateProvider<String>((ref) => 'All');

final allGenresPodcastsProvider = FutureProvider<Map<String, List<PodcastSeries>>>((ref) async {
  final api = ref.read(podcastApiServiceProvider);
  final futures = podcastGenreNames.map((g) async {
    final results = await api.byGenre(g, limit: 15);
    return MapEntry(g, results);
  });
  final entries = await Future.wait(futures);
  return Map.fromEntries(entries);
});

final podcastDescriptionProvider = FutureProvider.family<String?, String>((ref, feedUrl) async {
  final api = ref.read(podcastApiServiceProvider);
  return api.fetchDescription(feedUrl);
});

final podcastChaptersProvider = FutureProvider.family<List<PodcastChapter>, PodcastEpisode>((ref, episode) async {
  if (episode.chaptersUrl == null || episode.chaptersUrl!.isEmpty) return [];
  return PodcastApiService.fetchChapters(episode.chaptersUrl!);
});

final podcastFollowedProvider = StateNotifierProvider<PodcastFollowedNotifier, Set<int>>((ref) {
  return PodcastFollowedNotifier();
});

final podcastProgressProvider = StateNotifierProvider<PodcastProgressNotifier, Map<String, int>>((ref) {
  return PodcastProgressNotifier();
});

final podcastFollowedDetailsProvider = FutureProvider<List<PodcastSeries>>((ref) async {
  final followed = ref.watch(podcastFollowedProvider);
  if (followed.isEmpty) return [];
  final api = ref.read(podcastApiServiceProvider);
  final results = await Future.wait(followed.map((id) => api.lookupPodcast(id)));
  return results.whereType<PodcastSeries>().toList();
});

class PodcastFollowedNotifier extends StateNotifier<Set<int>> {
  PodcastFollowedNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('podcast_followed');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<int>();
        state = list.toSet();
      } catch (_) {}
    }
  }

  Future<void> toggle(int collectionId) async {
    if (state.contains(collectionId)) {
      state = {...state}..remove(collectionId);
    } else {
      state = {...state, collectionId};
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('podcast_followed', jsonEncode(state.toList()));
  }

  bool isFollowed(int collectionId) => state.contains(collectionId);
}

class PodcastProgressNotifier extends StateNotifier<Map<String, int>> {
  PodcastProgressNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('podcast_progress');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
  }

  Future<void> save(String key, int positionMillis) async {
    state = {...state, key: positionMillis};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('podcast_progress', jsonEncode(state));
  }

  int? get(String key) => state[key];

  Future<void> remove(String key) async {
    state = {...state}..remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('podcast_progress', jsonEncode(state));
  }
}

class ContinueListeningData {
  final String podcastTitle;
  final String podcastArtist;
  final String? podcastArtwork;
  final String? episodeArtwork;
  final String episodeTitle;
  final String episodeId;
  final String audioUrl;
  final Duration duration;
  final Duration position;
  final String? feedUrl;
  final bool isLive;
  final DateTime? lastPlayedAt;

  ContinueListeningData({
    required this.podcastTitle,
    required this.podcastArtist,
    this.podcastArtwork,
    this.episodeArtwork,
    required this.episodeTitle,
    required this.episodeId,
    required this.audioUrl,
    required this.duration,
    this.position = Duration.zero,
    this.feedUrl,
    this.isLive = false,
    this.lastPlayedAt,
  });

  String get episodeKey => '${podcastTitle}_$episodeId';

  ContinueListeningData copyWith({Duration? position, bool? isLive, DateTime? lastPlayedAt}) =>
      ContinueListeningData(
        podcastTitle: podcastTitle,
        podcastArtist: podcastArtist,
        podcastArtwork: podcastArtwork,
        episodeArtwork: episodeArtwork,
        episodeTitle: episodeTitle,
        episodeId: episodeId,
        audioUrl: audioUrl,
        duration: duration,
        position: position ?? this.position,
        feedUrl: feedUrl,
        isLive: isLive ?? this.isLive,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      );

  Map<String, dynamic> toJson() => {
    'podcastTitle': podcastTitle,
    'podcastArtist': podcastArtist,
    'podcastArtwork': podcastArtwork,
    'episodeArtwork': episodeArtwork,
    'episodeTitle': episodeTitle,
    'episodeId': episodeId,
    'audioUrl': audioUrl,
    'durationMillis': duration.inMilliseconds,
    'positionMillis': position.inMilliseconds,
    'feedUrl': feedUrl,
    'lastPlayedAtMs': lastPlayedAt?.millisecondsSinceEpoch,
  };

  static ContinueListeningData fromJson(Map<String, dynamic> json) =>
      ContinueListeningData(
        podcastTitle: json['podcastTitle'] as String? ?? '',
        podcastArtist: json['podcastArtist'] as String? ?? '',
        podcastArtwork: json['podcastArtwork'] as String?,
        episodeArtwork: json['episodeArtwork'] as String?,
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeId: json['episodeId'] as String? ?? '',
        audioUrl: json['audioUrl'] as String? ?? '',
        duration: Duration(milliseconds: (json['durationMillis'] as num?)?.toInt() ?? 0),
        position: Duration(milliseconds: (json['positionMillis'] as num?)?.toInt() ?? 0),
        feedUrl: json['feedUrl'] as String?,
        lastPlayedAt: json['lastPlayedAtMs'] != null
            ? DateTime.fromMillisecondsSinceEpoch((json['lastPlayedAtMs'] as num).toInt())
            : null,
      );
}

final lastPlayedPodcastProvider = StateNotifierProvider<LastPlayedPodcastNotifier, Map<String, ContinueListeningData>>((ref) {
  return LastPlayedPodcastNotifier();
});

class LastPlayedPodcastNotifier extends StateNotifier<Map<String, ContinueListeningData>> {
  LastPlayedPodcastNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('podcast_last_played');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      final map = <String, ContinueListeningData>{};
      for (final item in list) {
        final json = item as Map<String, dynamic>;
        final data = ContinueListeningData.fromJson(json);
        map[data.episodeKey] = data;
      }
      state = map;
    } catch (_) {}
  }

  Future<void> save(ContinueListeningData data) async {
    final entry = data.copyWith(lastPlayedAt: DateTime.now());
    state = {...state, entry.episodeKey: entry};
    if (state.length > 20) {
      final sorted = state.entries.toList()
        ..sort((a, b) => (b.value.lastPlayedAt ?? DateTime(0))
            .compareTo(a.value.lastPlayedAt ?? DateTime(0)));
      final trimmed = Map.fromEntries(sorted.take(20));
      state = trimmed;
    }
    await _persist();
  }

  Future<void> remove(String episodeKey) async {
    state = {...state}..remove(episodeKey);
    await _persist();
  }

  Future<void> clear() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('podcast_last_played');
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.values.map((e) => e.toJson()).toList();
    await prefs.setString('podcast_last_played', jsonEncode(list));
  }
}

final continueListeningProvider = Provider<List<ContinueListeningData>>((ref) {
  final mediaItem = ref.watch(playerMediaItemProvider).asData?.value;
  final isLive = mediaItem != null && mediaItem.extras?['mediaType'] == 'podcast';
  final all = ref.watch(lastPlayedPodcastProvider);
  final progressMap = ref.watch(podcastProgressProvider);

  final results = <ContinueListeningData>[];

  if (isLive) {
    final extras = mediaItem!.extras!;
    final epArtwork = (extras['episodeArtwork'] as String?)?.isNotEmpty == true
        ? extras['episodeArtwork'] as String?
        : null;
    results.add(ContinueListeningData(
      podcastTitle: extras['podcastTitle'] as String? ?? '',
      podcastArtist: extras['podcastArtist'] as String? ?? '',
      podcastArtwork: extras['podcastArtwork'] as String?,
      episodeArtwork: epArtwork,
      episodeTitle: mediaItem.title,
      episodeId: mediaItem.id,
      audioUrl: mediaItem.id,
      duration: mediaItem.duration ?? Duration.zero,
      feedUrl: extras['feedUrl'] as String?,
      isLive: true,
    ));
  }

  final liveKey = isLive ? '${mediaItem!.extras!['podcastTitle'] as String? ?? ''}_${mediaItem.id}' : null;

  final saved = all.entries.toList()
    ..sort((a, b) => (b.value.lastPlayedAt ?? DateTime(0))
        .compareTo(a.value.lastPlayedAt ?? DateTime(0)));

  for (final entry in saved) {
    if (entry.key == liveKey) continue;
    final latestPosMs = progressMap[entry.key];
    final position = latestPosMs != null
        ? Duration(milliseconds: latestPosMs)
        : entry.value.position;

    if (entry.value.duration.inMilliseconds > 0) {
      final fraction = position.inMilliseconds / entry.value.duration.inMilliseconds;
      if (fraction > 0.95) continue;
    }

    results.add(entry.value.copyWith(position: position));
  }

  return results;
});

final showAllContinueProvider = StateNotifierProvider<ShowAllContinueNotifier, bool>((_) => ShowAllContinueNotifier());

class ShowAllContinueNotifier extends StateNotifier<bool> {
  ShowAllContinueNotifier() : super(false);

  void toggle() => state = !state;
}
