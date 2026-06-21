import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../player/presentation/player_providers.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import '../data/itunes_metadata_service.dart';
import 'metadata_picker_sheet.dart';
import 'package:isai/main.dart'; // for navigatorKey
import 'artist_screen.dart';
import 'package:flutter/services.dart';

enum SongListMode { all, recent }

class SongsScreen extends ConsumerStatefulWidget {
  final SongListMode mode;
  const SongsScreen({super.key, required this.mode});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

enum SongSortOption { alphabetic, artist, recentlyAdded }

class _SongsScreenState extends ConsumerState<SongsScreen> {
  String _searchQuery = '';
  SongSortOption _sortBy = SongSortOption.recentlyAdded;

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final title = widget.mode == SongListMode.all ? 'All Music' : 'Recently Added';
    
    var songs = List<TorBoxFile>.from(libraryState.allAudioFiles);
    
    // Apply sorting
    if (widget.mode == SongListMode.all) {
      if (_sortBy == SongSortOption.alphabetic) {
        songs.sort((a, b) {
          final metaA = libraryState.metadata['${a.torrentId}-${a.id}'];
          final metaB = libraryState.metadata['${b.torrentId}-${b.id}'];
          final titleA = (metaA?.trackName ?? a.name).toLowerCase();
          final titleB = (metaB?.trackName ?? b.name).toLowerCase();
          return titleA.compareTo(titleB);
        });
      } else if (_sortBy == SongSortOption.artist) {
        songs.sort((a, b) {
          final metaA = libraryState.metadata['${a.torrentId}-${a.id}'];
          final metaB = libraryState.metadata['${b.torrentId}-${b.id}'];
          final artistA = (metaA?.artistName ?? 'TorBox').toLowerCase();
          final artistB = (metaB?.artistName ?? 'TorBox').toLowerCase();
          return artistA.compareTo(artistB);
        });
      } else if (_sortBy == SongSortOption.recentlyAdded) {
        songs.sort((a, b) => b.id.compareTo(a.id));
      }
    } else {
      // For Recently Added mode, always sort by id descending
      songs.sort((a, b) => b.id.compareTo(a.id));
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      songs = songs.where((f) {
        final meta = libraryState.metadata['${f.torrentId}-${f.id}'];
        final fileName = f.name.toLowerCase();
        final trackName = meta?.trackName?.toLowerCase() ?? '';
        final artistName = meta?.artistName?.toLowerCase() ?? '';
        return fileName.contains(query) || trackName.contains(query) || artistName.contains(query);
      }).toList();
    }

    if (widget.mode == SongListMode.recent && _searchQuery.isEmpty) {
      songs = songs.take(50).toList();
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0a0a0a), Color(0xFF000000)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFf5f5f7), Color(0xFFefeff1)],
                ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
              actions: widget.mode == SongListMode.all 
                  ? [
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        ),
                        child: PopupMenuButton<SongSortOption>(
                          icon: Icon(Icons.sort_rounded, color: Theme.of(context).colorScheme.primary),
                          onSelected: (option) {
                            setState(() {
                              _sortBy = option;
                            });
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: SongSortOption.recentlyAdded,
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 18, color: _sortBy == SongSortOption.recentlyAdded ? Theme.of(context).colorScheme.primary : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Recently Added', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: _sortBy == SongSortOption.recentlyAdded ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: SongSortOption.alphabetic,
                              child: Row(
                                children: [
                                  Icon(Icons.sort_by_alpha_rounded, size: 18, color: _sortBy == SongSortOption.alphabetic ? Theme.of(context).colorScheme.primary : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Alphabetical (A-Z)', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: _sortBy == SongSortOption.alphabetic ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: SongSortOption.artist,
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 18, color: _sortBy == SongSortOption.artist ? Theme.of(context).colorScheme.primary : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Artist Name', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: _sortBy == SongSortOption.artist ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 48, bottom: 16),
              ),
            ),
            
            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: GlassContainer(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search in library...',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ),

            if (songs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note_rounded, size: 64, color: subTextColor),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No songs found' : 'No matches for "$_searchQuery"',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final file = songs[index];
                    final meta = libraryState.metadata['${file.torrentId}-${file.id}'];
                    
                    return _SongTile(file: file, meta: meta, queue: songs);
                  },
                  childCount: songs.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for mini player
          ],
        ),
      ),
    );
  }
}

class _SongTile extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final ItunesMeta? meta;
  final List<TorBoxFile> queue;

  const _SongTile({required this.file, this.meta, required this.queue});

  @override
  ConsumerState<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<_SongTile> {
  @override
  void initState() {
    super.initState();
    // Pre-enrich if metadata is missing
    if (widget.meta == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(libraryProvider.notifier).enrichTrack(widget.file);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = '${widget.file.torrentId}-${widget.file.id}';
    final meta = libraryState.metadata[key] ?? widget.meta;
    final isEnriching = libraryState.enrichingKeys.contains(key);
    
    // Fallback parsing if no metadata
    var title = widget.file.name;
    var artist = 'TorBox';
    
    if (meta != null) {
      title = meta.trackName ?? widget.file.name;
      artist = meta.artistName ?? 'TorBox';
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MetadataPickerSheet(
            file: widget.file,
            initialQuery: title,
            initialArtist: artist != 'TorBox' ? artist : null,
          ),
        );
      },
      child: AppleMusicListTile(
        title: title,
        subtitle: isEnriching ? 'Fetching metadata...' : artist,
        imageUrl: meta?.artworkUrlLow,
        onSubtitleTap: (isEnriching || artist == 'TorBox')
            ? null
            : () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistScreen(artistName: artist),
                  ),
                );
              },
        trailing: isEnriching 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary)),
            )
          : Icon(
              Icons.play_arrow_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 26,
            ),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NowPlayingScreen(
                file: widget.file,
                customQueue: widget.queue,
                initialArtwork: meta?.artworkUrlHigh ?? meta?.artworkUrlLow,
              ),
            ),
          );
        },
      ),
    );
  }
}
