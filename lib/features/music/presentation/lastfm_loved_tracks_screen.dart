import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import 'lastfm_loved_tracks_provider.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import 'package:isai/main.dart';

class LastfmLovedTracksScreen extends ConsumerStatefulWidget {
  const LastfmLovedTracksScreen({super.key});

  @override
  ConsumerState<LastfmLovedTracksScreen> createState() => _LastfmLovedTracksScreenState();
}

class _LastfmLovedTracksScreenState extends ConsumerState<LastfmLovedTracksScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(lastfmLovedTracksProvider.notifier).fetchFirstPage());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(lastfmLovedTracksProvider.notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lastfmLovedTracksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          controller: _scrollController,
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
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Loved on Last.fm',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 48, bottom: 16),
              ),
            ),
            if (state.isLoading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              )
            else if (state.error != null)
              SliverFillRemaining(
                child: Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.white))),
              )
            else if (state.tracks.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No loved tracks found.', style: TextStyle(color: Colors.white54))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= state.tracks.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                      );
                    }

                    final item = state.tracks[index];
                    final title = item['name'] as String;
                    final artist = item['artist'] as String;
                    final imageUrl = item['image_url'] as String?;

                    return AppleMusicListTile(
                      title: title,
                      subtitle: artist,
                      imageUrl: imageUrl,
                      onTap: () => _playVirtualTrack(item, state.tracks, index),
                      trailing: Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), size: 20),
                    );
                  },
                  childCount: state.tracks.length + (state.currentPage < state.totalPages ? 1 : 0),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Future<void> _playVirtualTrack(Map<String, dynamic> track, List<Map<String, dynamic>> allTracks, int index) async {
    final title = track['name'] as String;
    final artist = track['artist'] as String;
    final artwork = track['image_url'] as String? ?? '';

    // Create a virtual TorBoxFile (id derived from content hash)
    final virtualFile = TorBoxFile(
      id: (title + artist).hashCode,
      torrentId: -1,
      name: '$artist - $title',
      size: 0,
    );

    // Build the queue for standard playback logic
    final queue = allTracks.map((t) {
      final qTitle = t['name'] as String;
      final qArtist = t['artist'] as String;
      final qArtwork = t['image_url'] as String? ?? '';
      
      final url = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qTitle)}&artist=${Uri.encodeComponent(qArtist)}';
      
      return {
        'url': url,
        'title': qTitle,
        'artist': qArtist,
        'artworkUrl': qArtwork,
        'extras': {
          'torrentId': -1,
          'fileId': (qTitle + qArtist).hashCode,
          'size': 0,
        }
      };
    }).toList();

    await audioHandler.customAction('play', {
      'url': 'https://lazy.flac.internal/?title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist)}',
      'title': title,
      'artist': artist,
      'artworkUrl': artwork,
      'forceReplace': true,
      'index': index,
      'queue': queue,
    });

    if (mounted) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => NowPlayingScreen(
            file: virtualFile,
            initialArtwork: artwork,
          ),
        ),
      );
    }
  }
}
