import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/apple_music_theme.dart';
import 'music_providers.dart';
import 'artist_screen.dart';

class FollowedArtistsScreen extends ConsumerWidget {
  const FollowedArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedArtistsAsync = ref.watch(followedArtistsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1c1c1e), Color(0xFF000000)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFf5f5f7), Color(0xFFefeff1)],
                ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark ? const Color(0xFF1c1c1e).withOpacity(0.9) : const Color(0xFFf5f5f7).withOpacity(0.9),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Artists',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            followedArtistsAsync.when(
              data: (artists) {
                if (artists.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 80,
                            color: isDark ? Colors.white10 : Colors.black.withAlpha(26),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No followed artists yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Follow artists to see them here',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Sort alphabetically
                final sortedArtists = List.of(artists)..sort((a, b) => a.name.compareTo(b.name));

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final artist = sortedArtists[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: artist.artworkUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: artist.artworkUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                                    errorWidget: (_, __, ___) => _defaultArtistAvatar(isDark),
                                  )
                                : _defaultArtistAvatar(isDark),
                          ),
                        ),
                        title: Text(
                          artist.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,),
                        ),
                        subtitle: artist.genre != null
                            ? Text(
                                artist.genre!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                              )
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtistScreen(artistName: artist.name),
                            ),
                          );
                        },
                      );
                    },
                    childCount: sortedArtists.length,
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _defaultArtistAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
      child: Icon(
        Icons.person,
        size: 30,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }
}
