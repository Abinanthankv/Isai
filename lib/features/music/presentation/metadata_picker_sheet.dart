import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/itunes_metadata_service.dart';
import '../data/music_models.dart';
import '../data/music_repository.dart';
import '../presentation/music_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'package:isai/main.dart';
import '../../../core/di/injection.dart';
import 'playlist_providers.dart';

enum MetadataProvider { iTunes, Deezer }

class MetadataPickerSheet extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final String initialQuery;
  final String? initialArtist;

  const MetadataPickerSheet({
    super.key,
    required this.file,
    required this.initialQuery,
    this.initialArtist,
  });

  @override
  ConsumerState<MetadataPickerSheet> createState() => _MetadataPickerSheetState();
}

class _MetadataPickerSheetState extends ConsumerState<MetadataPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ItunesMeta> _results = [];
  bool _isLoading = false;
  String? _error;
  MetadataProvider _selectedSource = MetadataProvider.iTunes;
  bool _showingFallback = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _performSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<ItunesMeta> results = [];
      print('[MetadataPicker] Source: $_selectedSource, Query: $query');

      if (_selectedSource == MetadataProvider.iTunes) {
        print('[MetadataPicker] Searching iTunes: $query');
        results = await getIt<ItunesMetadataService>().searchMeta(query);
      } else if (_selectedSource == MetadataProvider.Deezer) {
        print('[MetadataPicker] Searching Deezer via MusicBrainz→ISRC: $query');
        results = await _searchDeezerViaIsrc(query);
        if (results.isEmpty) {
          print('[MetadataPicker] Deezer returned 0 results, falling back to iTunes');
          final fallback = await getIt<ItunesMetadataService>().searchMeta(query);
          if (fallback.isNotEmpty) {
            results = fallback;
            _showingFallback = true;
          }
        }
      }
      print('[MetadataPicker] Found ${results.length} results');

      // 🌟 Sort matches to top automatically 🌟
      if (widget.initialArtist != null && 
          widget.initialArtist!.isNotEmpty && 
          widget.initialArtist != 'TorBox') {
        final match = widget.initialArtist!.toLowerCase();
        
        // Exact match prioritized
        results.sort((a, b) {
          final aArtist = a.artistName?.toLowerCase() ?? '';
          final bArtist = b.artistName?.toLowerCase() ?? '';
          final aMatch = aArtist.contains(match);
          final bMatch = bArtist.contains(match);
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;
          return 0;
        });
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to search metadata';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<ItunesMeta>> _searchDeezerViaIsrc(String query) async {
    try {
      final dio = Dio(BaseOptions(
        headers: {
          'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          'Accept': 'application/json',
        },
      ));

      final searchQuery = widget.initialArtist != null && widget.initialArtist!.isNotEmpty && widget.initialArtist != 'TorBox'
          ? 'recording:"$query" AND artist:"${widget.initialArtist}"'
          : 'recording:"$query"';

      final response = await dio.get(
        'https://musicbrainz.org/ws/2/recording',
        queryParameters: {
          'query': searchQuery,
          'fmt': 'json',
          'limit': 15,
        },
      );

      final recordings = (response.data is Map ? (response.data as Map)['recordings'] : null) as List<dynamic>?;
      if (recordings == null || recordings.isEmpty) return [];

      final isrcSet = <String>{};
      final trackList = <Map<String, dynamic>>[];

      for (final rec in recordings) {
        if (rec is! Map) continue;
        final isrcs = rec['isrcs'] as List<dynamic>? ?? [];
        for (final isrc in isrcs) {
          if (isrc is String && isrcSet.add(isrc)) {
            await Future.delayed(const Duration(milliseconds: 150));
            try {
              final deezerRes = await dio.get('https://api.deezer.com/track/isrc:$isrc');
              final deezerData = deezerRes.data;
              if (deezerData is Map && !deezerData.containsKey('error')) {
                trackList.add(deezerData as Map<String, dynamic>);
              }
            } catch (_) {}
          }
        }
      }

      return trackList.map(_deezerTrackToMeta).toList();
    } catch (e) {
      print('[MetadataPicker] Deezer via ISRC error: $e');
      return [];
    }
  }

  ItunesMeta _deezerTrackToMeta(Map<String, dynamic> track) {
    final album = track['album'] as Map<String, dynamic>? ?? {};
    final artist = track['artist'] as Map<String, dynamic>? ?? {};

    String? releaseDateStr;
    if (track['release_date'] is String) {
      releaseDateStr = track['release_date'] as String;
    } else if (album['release_date'] is String) {
      releaseDateStr = album['release_date'] as String;
    }
    int? releaseYear;
    if (releaseDateStr != null && releaseDateStr.length >= 4) {
      releaseYear = int.tryParse(releaseDateStr.substring(0, 4));
    }

    final duration = (track['duration'] as num?)?.toInt();
    final cover = album['cover_medium'] as String? ?? album['cover_xl'] as String?;

    final extras = <String, dynamic>{
      if (track['isrc'] != null) 'isrc': track['isrc'],
      if (album['label'] != null) 'label': album['label'],
      if (album['copyright'] != null) 'copyright': album['copyright'],
      if (track['track_position'] != null) 'trackNumber': track['track_position'],
      if (album['nb_tracks'] != null) 'totalTracks': album['nb_tracks'],
      if (track['disk_number'] != null) 'discNumber': track['disk_number'],
      if (album['nb_disk'] != null) 'totalDiscs': album['nb_disk'],
      if (album['record_type'] != null) 'albumType': album['record_type'],
      if (track['bpm'] != null) 'bpm': track['bpm'],
      if (track['gain'] != null) 'gain': track['gain'],
      if (track['explicit_lyrics'] != null) 'isExplicit': track['explicit_lyrics'],
      'provider': 'deezer',
    };

    return ItunesMeta(
      trackName: track['title'] as String?,
      artistName: artist['name'] as String?,
      artworkUrlLow: cover?.replaceAll('250x250', '600x600'),
      artworkUrlHigh: album['cover_xl'] as String? ?? cover,
      album: album['title'] as String?,
      releaseYear: releaseYear,
      trackTimeMillis: duration != null ? duration * 1000 : null,
      extras: extras,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Fix Metadata',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Source Picker Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _buildSourceTab('iTunes', MetadataProvider.iTunes),
                const SizedBox(width: 8),
                _buildSourceTab('Deezer', MetadataProvider.Deezer),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _selectedSource == MetadataProvider.iTunes ? 'Search iTunes...' : 'Search Deezer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _performSearch,
            ),
          ),

          if (_showingFallback)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    'Deezer search unavailable — showing iTunes results instead',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _error != null
                    ? Center(child: Text(_error!))
                    : _results.isEmpty
                        ? const Center(child: Text('No results found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final meta = _results[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 12,
                                  onTap: () async {
                                    final trackMeta = ItunesMeta(
                                      trackName: meta.trackName,
                                      artistName: meta.artistName,
                                      artworkUrlLow: meta.artworkUrlLow,
                                      artworkUrlHigh: meta.artworkUrlHigh,
                                      album: meta.album,
                                      genre: meta.genre,
                                      releaseYear: meta.releaseYear,
                                      trackTimeMillis: meta.trackTimeMillis,
                                      extras: meta.extras,
                                    );

                                    if (widget.file.id < 0 && widget.file.torrentId == -1) {
                                      // Playlist enrichment (virtual ID)
                                      final playlistTrackId = -widget.file.id;
                                      await ref.read(playlistProvider.notifier).enrichPlaylistTrack(playlistTrackId, trackMeta);
                                    } else {
                                      // Library enrichment
                                      await ref.read(libraryProvider.notifier).updateTrackMetadata(widget.file, trackMeta);
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Metadata updated!')),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: meta.artworkUrlLow != null
                                            ? CachedNetworkImage(
                                                imageUrl: meta.artworkUrlLow!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.white10,
                                                child: const Icon(Icons.music_note),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _unescapeHtml(meta.trackName ?? 'Unknown'),
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold,),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _unescapeHtml(meta.artistName ?? 'Unknown Artist'),
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87,),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (meta.album != null)
                                              Text(
                                                _unescapeHtml(meta.album!),
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Widget _buildSourceTab(String label, MetadataProvider source) {
    final isSelected = _selectedSource == source;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSource = source;
            _showingFallback = false;
          });
          _performSearch(_searchController.text); // Trigger refresh on switch
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),),
          ),
        ),
      ),
    );
  }
}
