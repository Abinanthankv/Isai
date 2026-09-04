import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isai/main.dart';
import '../../../core/di/injection.dart';
import '../../../core/database/database.dart';
import '../data/podcast_models.dart';
import '../data/podcast_api_service.dart';
import '../data/podcast_repository.dart';

const podcastGenreNames = [
  'Comedy', 'Technology', 'Science', 'News', 'Music',
  'History', 'True Crime', 'Business', 'Health', 'Education',
  'Sports', 'TV & Film', 'Religion', 'Society', 'Arts',
  'Fiction', 'Kids & Family', 'Leisure', 'Government', 'How To',
];

final podcastApiServiceProvider = Provider<PodcastApiService>((ref) {
  return PodcastApiService();
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  final db = getIt<AppDatabase>();
  final api = ref.read(podcastApiServiceProvider);
  return PodcastRepository(db, api);
});

final subscribedPodcastsProvider = StreamProvider<List<DbPodcastSubscription>>((ref) {
  final repo = ref.watch(podcastRepositoryProvider);
  repo.checkAndNotifyNewEpisodes();
  return repo.watchSubscribedPodcasts();
});

final downloadedPodcastEpisodesProvider = StreamProvider<List<DbPodcastEpisodeData>>((ref) {
  final repo = ref.watch(podcastRepositoryProvider);
  return repo.watchDownloadedEpisodes();
});

final podcastEpisodesDbProvider = StreamProvider.family<List<DbPodcastEpisodeData>, String>((ref, feedUrl) {
  final repo = ref.watch(podcastRepositoryProvider);
  repo.getEpisodes(feedUrl);
  return repo.watchEpisodes(feedUrl);
});

final podcastEpisodeProgressDbProvider = StreamProvider.family<DbPodcastProgressData?, String>((ref, guid) {
  final repo = ref.watch(podcastRepositoryProvider);
  return repo.watchProgress(guid);
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
  const batchSize = 5;
  final entries = <MapEntry<String, List<PodcastSeries>>>[];
  for (var i = 0; i < podcastGenreNames.length; i += batchSize) {
    final batch = podcastGenreNames.skip(i).take(batchSize).toList();
    final results = await Future.wait(batch.map((g) => api.byGenre(g, limit: 15)));
    for (var j = 0; j < batch.length; j++) {
      entries.add(MapEntry(batch[j], results[j]));
    }
    if (i + batchSize < podcastGenreNames.length) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
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

final _followedCache = <String, List<PodcastSeries>>{};
final podcastFollowedDetailsProvider = FutureProvider<List<PodcastSeries>>((ref) async {
  final followed = ref.watch(podcastFollowedProvider);
  final manualUrls = ref.watch(podcastManualFeedUrlsProvider);
  if (followed.isEmpty && manualUrls.isEmpty) return [];
  final cacheKey = '${followed.hashCode}_${manualUrls.hashCode}';
  final cached = _followedCache[cacheKey];
  if (cached != null) return cached;
  final api = ref.read(podcastApiServiceProvider);
  final results = <PodcastSeries>[];
  if (followed.isNotEmpty) {
    const batchSize = 5;
    final ids = followed.toList();
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch.map((id) => api.lookupPodcast(id)));
      for (final r in batchResults) {
        if (r != null) results.add(r);
      }
      if (i + batchSize < ids.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
  if (manualUrls.isNotEmpty) {
    const batchSize = 5;
    final urls = manualUrls.toList();
    for (var i = 0; i < urls.length; i += batchSize) {
      final batch = urls.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch.map((url) => api.fetchSeriesFromFeed(url)));
      for (final r in batchResults) {
        if (r != null) results.add(r);
      }
      if (i + batchSize < urls.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
  _followedCache[cacheKey] = results;
  return results;
});

final podcastManualFeedUrlsProvider = StateNotifierProvider<PodcastManualFeedUrlsNotifier, Set<String>>((ref) {
  return PodcastManualFeedUrlsNotifier();
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

  Future<void> add(int collectionId) async {
    if (!state.contains(collectionId)) {
      state = {...state, collectionId};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('podcast_followed', jsonEncode(state.toList()));
    }
  }

  Future<void> remove(int collectionId) async {
    if (state.contains(collectionId)) {
      state = {...state}..remove(collectionId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('podcast_followed', jsonEncode(state.toList()));
    }
  }

  Future<void> toggle(int collectionId) async {
    if (state.contains(collectionId)) {
      await remove(collectionId);
    } else {
      await add(collectionId);
    }
  }

  bool isFollowed(int collectionId) => state.contains(collectionId);
}

class PodcastManualFeedUrlsNotifier extends StateNotifier<Set<String>> {
  PodcastManualFeedUrlsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('podcast_manual_feeds');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        state = list.toSet();
      } catch (_) {}
    }
  }

  Future<void> add(String url) async {
    state = {...state, url};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('podcast_manual_feeds', jsonEncode(state.toList()));
  }

  Future<void> remove(String url) async {
    state = {...state}..remove(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('podcast_manual_feeds', jsonEncode(state.toList()));
  }
}

class PodcastProgressNotifier extends StateNotifier<Map<String, int>> {
  PodcastProgressNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    const versionKey = 'podcast_progress_ver';
    if (prefs.getInt(versionKey) != 1) {
      await prefs.remove('podcast_progress');
      await prefs.setInt(versionKey, 1);
      return;
    }
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
  final String? primaryGenre;

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
    this.primaryGenre,
  });

  String get episodeKey => '${podcastTitle}_$episodeId';

  ContinueListeningData copyWith({String? podcastTitle, Duration? position, bool? isLive, DateTime? lastPlayedAt, String? primaryGenre}) =>
      ContinueListeningData(
        podcastTitle: podcastTitle ?? this.podcastTitle,
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
        primaryGenre: primaryGenre ?? this.primaryGenre,
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
    'primaryGenre': primaryGenre,
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
        primaryGenre: json['primaryGenre'] as String?,
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
    const verKey = 'podcast_last_played_ver';
    if (prefs.getInt(verKey) != 1) {
      await prefs.remove('podcast_last_played');
      await prefs.remove('podcast_progress');
      await prefs.setInt(verKey, 1);
      return;
    }
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
    final extras = mediaItem.extras!;
    final epId = extras['episodeId'] as String? ?? mediaItem.id;
    final epArtwork = (extras['episodeArtwork'] as String?)?.isNotEmpty == true
        ? extras['episodeArtwork'] as String?
        : null;
    results.add(ContinueListeningData(
      podcastTitle: extras['podcastTitle'] as String? ?? '',
      podcastArtist: extras['podcastArtist'] as String? ?? '',
      podcastArtwork: extras['podcastArtwork'] as String?,
      episodeArtwork: epArtwork,
      episodeTitle: mediaItem.title,
      episodeId: epId,
      audioUrl: mediaItem.id,
      duration: mediaItem.duration ?? Duration.zero,
      feedUrl: extras['feedUrl'] as String?,
      isLive: true,
    ));
  }

  final liveKey = isLive ? '${mediaItem.extras!['podcastTitle'] as String? ?? ''}_${mediaItem.extras!['episodeId'] as String? ?? mediaItem.id}' : null;

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

class PodcastStatsData {
  final Duration totalListeningTime;
  final int completedEpisodes;
  final int inProgressEpisodes;
  final int startedEpisodes;
  final int followedPodcasts;
  final int uniquePodcastsPlayed;
  final List<({String title, int count})> topPodcasts;
  final List<ContinueListeningData> recentActivity;
  final List<({String genre, int count})> genreBreakdown;

  PodcastStatsData({
    this.totalListeningTime = Duration.zero,
    this.completedEpisodes = 0,
    this.inProgressEpisodes = 0,
    this.startedEpisodes = 0,
    this.followedPodcasts = 0,
    this.uniquePodcastsPlayed = 0,
    this.topPodcasts = const [],
    this.recentActivity = const [],
    this.genreBreakdown = const [],
  });
}

final podcastStatsProvider = Provider<PodcastStatsData>((ref) {
  final progressMap = ref.watch(podcastProgressProvider);
  final lastPlayedMap = ref.watch(lastPlayedPodcastProvider);
  final followed = ref.watch(podcastFollowedProvider);
  final subs = ref.watch(subscribedPodcastsProvider).asData?.value ?? [];
  final subMap = {for (final s in subs) s.feedUrl: s};

  int completed = 0, inProgress = 0, started = 0;
  Duration totalTime = Duration.zero;
  final podcastCount = <String, int>{};
  final genreCount = <String, int>{};

  for (final entry in lastPlayedMap.values) {
    final posMs = progressMap[entry.episodeKey] ?? entry.position.inMilliseconds;
    final durMs = entry.duration.inMilliseconds;
    if (posMs > 0) started++;
    if (durMs > 0) {
      final fraction = posMs / durMs;
      if (fraction > 0.95) completed++;
      else if (fraction > 0.05) inProgress++;
    }
    totalTime += Duration(milliseconds: posMs);

    var title = entry.podcastTitle;
    if ((title.isEmpty || title == 'Downloaded Episode') && entry.feedUrl != null && subMap.containsKey(entry.feedUrl)) {
      title = subMap[entry.feedUrl]!.title;
    }
    if (title != 'Downloaded Episode') {
      podcastCount[title] = (podcastCount[title] ?? 0) + 1;
    }

    if (entry.primaryGenre != null) {
      genreCount[entry.primaryGenre!] = (genreCount[entry.primaryGenre!] ?? 0) + 1;
    }
  }

  final topPodcasts = podcastCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final genreSorted = genreCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final recent = lastPlayedMap.values.map((item) {
    if ((item.podcastTitle.isEmpty || item.podcastTitle == 'Downloaded Episode') && item.feedUrl != null && subMap.containsKey(item.feedUrl)) {
      return item.copyWith(podcastTitle: subMap[item.feedUrl]!.title);
    }
    return item;
  }).toList()
    ..sort((a, b) => (b.lastPlayedAt ?? DateTime(0))
        .compareTo(a.lastPlayedAt ?? DateTime(0)));

  return PodcastStatsData(
    totalListeningTime: totalTime,
    completedEpisodes: completed,
    inProgressEpisodes: inProgress,
    startedEpisodes: started,
    followedPodcasts: followed.length,
    uniquePodcastsPlayed: podcastCount.length,
    topPodcasts: topPodcasts.take(10).map((e) => (title: e.key, count: e.value)).toList(),
    recentActivity: recent.take(20).toList(),
    genreBreakdown: genreSorted.map((e) => (genre: e.key, count: e.value)).toList(),
  );
});
