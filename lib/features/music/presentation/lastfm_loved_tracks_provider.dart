import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../data/lastfm_service.dart';
import '../data/itunes_metadata_service.dart';
import '../../settings/data/lastfm_repository.dart';

class LovedTracksState {
  final List<Map<String, dynamic>> tracks;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  LovedTracksState({
    this.tracks = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  LovedTracksState copyWith({
    List<Map<String, dynamic>>? tracks,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return LovedTracksState(
      tracks: tracks ?? this.tracks,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

final lastfmLovedTracksProvider = NotifierProvider<LastfmLovedTracksNotifier, LovedTracksState>(() {
  return LastfmLovedTracksNotifier();
});

class LastfmLovedTracksNotifier extends Notifier<LovedTracksState> {
  late final LastFmService _service;
  late final ItunesMetadataService _itunes;
  late final LastfmRepository _repo;

  @override
  LovedTracksState build() {
    _service = getIt<LastFmService>();
    _itunes = getIt<ItunesMetadataService>();
    _repo = getIt<LastfmRepository>();
    return LovedTracksState();
  }

  Future<void> fetchFirstPage() async {
    final username = _repo.username;
    if (username == null) return;

    state = state.copyWith(isLoading: true, error: null, tracks: []);
    
    try {
      final result = await _service.getLovedTracks(username, page: 1, limit: 50);
      final tracks = result['tracks'] as List<Map<String, dynamic>>;
      
      // Perform initial enrichment in background
      _enrichBatch(tracks);

      state = state.copyWith(
        isLoading: false,
        tracks: tracks,
        currentPage: 1,
        totalPages: result['totalPages'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || state.currentPage >= state.totalPages) return;
    
    final username = _repo.username;
    if (username == null) return;

    state = state.copyWith(isLoadingMore: true);
    
    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.getLovedTracks(username, page: nextPage, limit: 50);
      final newTracks = result['tracks'] as List<Map<String, dynamic>>;
      
      _enrichBatch(newTracks);

      state = state.copyWith(
        isLoadingMore: false,
        tracks: [...state.tracks, ...newTracks],
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> _enrichBatch(List<Map<String, dynamic>> items) async {
    // Enrich 5 at a time for performance
    for (int i = 0; i < items.length; i += 5) {
      final chunk = items.skip(i).take(5);
      await Future.wait(chunk.map((item) async {
        final name = item['name'] as String;
        final artist = item['artist'] as String;
        final currentImg = item['image_url'] as String? ?? '';
        
        if (LastFmService.isPlaceholderImage(currentImg)) {
          final meta = await _itunes.fetchMeta(name, artist);
          if (meta?.artworkUrlHigh != null) {
            item['image_url'] = meta!.artworkUrlHigh;
          }
        }
      }));
      // Update state to reflect enriched images
      // In Notifier, we don't have 'mounted', we just update state if we are still active
      state = state.copyWith(tracks: List.from(state.tracks));
    }
  }
}
