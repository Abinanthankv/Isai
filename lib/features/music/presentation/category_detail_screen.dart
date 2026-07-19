import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import 'playlists_screen.dart';
import 'package:isai/main.dart';
import 'package:audio_service/audio_service.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final DeezerGenre genre;

  const CategoryDetailScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(genrePlaylistsProvider(GenrePlaylistsParams(id: genre.id, name: genre.name)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                genre.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: genre.picture,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          playlistsAsync.when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No playlists found for this category',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCrossAxisCount(context),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlist = playlists[index];
                      return AppleMusicCard(
                        title: playlist.title,
                        subtitle: '${playlist.nbTracks} tracks',
                        imageUrl: playlist.artworkUrl,
                        onTap: () {
                          debugPrint('[CategoryDetailScreen] Tapped playlist: ${playlist.title} (ID: ${playlist.id})');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailsScreen(
                                deezerPlaylist: playlist,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: playlists.length,
                  ),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
          // Add extra padding at bottom for player
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  int _gridCrossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 1200) return 6;
    if (w > 900) return 5;
    if (w > 700) return 4;
    if (w > 500) return 3;
    return 2;
  }
}
