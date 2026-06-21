import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import '../data/itunes_metadata_service.dart';
import 'source_picker_sheet.dart';
import 'now_playing_screen.dart';
import 'album_screen.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'package:audio_service/audio_service.dart';
import 'package:isai/main.dart';
import '../../../core/di/injection.dart';
import '../data/music_repository.dart';
import 'playlists_screen.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistName;

  const ArtistScreen({super.key, required this.artistName});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _showAllSongs = false;
  bool _showAllAlbums = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topSongsAsync = ref.watch(artistSongsProvider(widget.artistName));
    final albumsAsync = ref.watch(artistAlbumsProvider(widget.artistName));
    final artistDetailsAsync = ref.watch(artistDetailsProvider(widget.artistName));
    final url = artistDetailsAsync.asData?.value?.artistLinkUrl;
    final artistImageAsync = ref.watch(artistImageProvider(ArtistImageParams(name: widget.artistName, url: url)));
    final bioAsync = ref.watch(artistBioProvider(widget.artistName));
    final similarAsync = ref.watch(similarArtistsProvider(widget.artistName));
    final metadataAsync = ref.watch(artistMetadataProvider(widget.artistName));
    final deezerPlaylistsAsync = ref.watch(deezerArtistPlaylistsProvider(widget.artistName));
    final deezerRelatedAsync = ref.watch(deezerRelatedArtistsProvider(widget.artistName));
    final deezerTopTracksAsync = ref.watch(deezerArtistTopTracksProvider(widget.artistName));
    final deezerArtistDetailsAsync = ref.watch(deezerArtistDetailsProvider(widget.artistName));
    
    // Check if followed if we have artistId
    AsyncValue<bool> isFollowedAsync = const AsyncValue.data(false);
    final artistId = artistDetailsAsync.asData?.value?.artistId;
    if (artistId != null) {
      isFollowedAsync = ref.watch(isArtistFollowedProvider(artistId));
    }
    final isFollowed = isFollowedAsync.asData?.value ?? false;

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
            _buildSimplifiedAppBar(context, isDark),
            _buildArtistHeader(context, isDark, artistImageAsync, artistDetailsAsync, isFollowed, metadataAsync, deezerArtistDetailsAsync),
            // TODO:
            // - [ ] Improved Artist Image Fetching
            //   - [ ] Update `ItunesMetadataService` to fetch profile image from `artistViewUrl`.
            //   - [ ] Test with several artists (e.g. Frank Ocean, Michael Jackson).
            
            // Popular Songs Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popular songs${topSongsAsync.asData?.value != null ? ' (${topSongsAsync.asData!.value.length})' : ''}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,),
                    ),
                    
                  ],
                ),
              ),
            ),
            
            _buildSongsList(topSongsAsync, isDark),
            
           /* SliverToBoxAdapter(
              child: _buildDeezerTopTracksSection(deezerTopTracksAsync, isDark),
            ),*/
            
            // Albums Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Text(
                  'Top Albums${albumsAsync.asData?.value != null ? ' (${albumsAsync.asData!.value.length})' : ''}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,),
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: _buildAlbumsSection(albumsAsync, isDark),
            ),
            
            SliverToBoxAdapter(
              child: _buildDeezerPlaylistsSection(deezerPlaylistsAsync, isDark),
            ),
            
            SliverToBoxAdapter(
              child: _buildAboutSection(context, isDark, bioAsync, similarAsync, metadataAsync, deezerRelatedAsync),
            ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        'Artist',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildArtistHeader(
    BuildContext context, 
    bool isDark, 
    AsyncValue<String?> artistImageAsync, 
    AsyncValue<ItunesArtist?> artistDetailsAsync, 
    bool isFollowed, 
    AsyncValue<Map<String, dynamic>?> metadataAsync,
    AsyncValue<Map<String, dynamic>?> deezerDetailsAsync,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Circular Artist Image
          artistImageAsync.when(
            data: (url) => Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: metadataAsync.when(
                    data: (metadata) {
                      final wikidataUrl = metadata?['wikidata_image'] as String?;
                      final imageUrl = wikidataUrl ?? url;
                      return imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                              errorWidget: (context, url, error) => _defaultArtistAvatar(isDark),
                            )
                          : _defaultArtistAvatar(isDark);
                    },
                    loading: () => url != null
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                            errorWidget: (context, url, error) => _defaultArtistAvatar(isDark),
                          )
                        : _defaultArtistAvatar(isDark),
                    error: (_, __) => url != null
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                            errorWidget: (context, url, error) => _defaultArtistAvatar(isDark),
                          )
                        : _defaultArtistAvatar(isDark),
                  ),
                ),
              ),
            ),
            loading: () => Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (_, __) => Center(child: _defaultArtistAvatar(isDark)),
          ),
          const SizedBox(height: 24),
          // Artist Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.artistName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,),
            ),
          ),
          
          // Artist Genre
          artistDetailsAsync.when(
            data: (details) => details?.primaryGenreName != null
                ? Column(
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        details!.primaryGenreName!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox(height: 18),
            error: (_, __) => const SizedBox.shrink(),
          ),

          
          const SizedBox(height: 16),
          // Follow Button
          artistDetailsAsync.when(
            data: (details) => _buildFollowButton(context, isDark, details, isFollowed, artistImageAsync.asData?.value),
            loading: () => _buildFollowButton(context, isDark, null, false, null),
            error: (_, __) => _buildFollowButton(context, isDark, null, false, null),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context, bool isDark, ItunesArtist? details, bool isFollowed, String? artworkUrl) {
    return OutlinedButton(
      onPressed: details == null 
          ? null 
          : () async {
              HapticFeedback.mediumImpact();
              final repo = getIt<MusicRepository>();
              print('[ArtistScreen] Follow button clicked. Current isFollowed: $isFollowed, ArtistID: ${details.artistId}');
              if (isFollowed) {
                print('[ArtistScreen] Unfollowing artist...');
                await repo.unfollowArtist(details.artistId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unfollowed ${details.artistName}'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              } else {
                print('[ArtistScreen] Following artist...');
                await repo.followArtist(details, artworkUrl);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Followed ${details.artistName}'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              }
            },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isFollowed 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : (isDark ? Colors.white30 : Colors.black26)
        ),
        backgroundColor: isFollowed ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      ),
      child: Text(
        isFollowed ? 'FOLLOWING' : 'FOLLOW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
          color: isFollowed ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white : Colors.black),
          letterSpacing: 1.0,),
      ),
    );
  }

  Widget _defaultArtistAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
      child: Icon(
        Icons.person,
        size: 100,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }

  Widget _defaultArtistBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            AppleMusicTheme.primaryPurple.withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 120, color: Colors.white24),
      ),
    );
  }

  Widget _buildAlbumsSection(AsyncValue<List<ItunesTrack>> albumsAsync, bool isDark) {
    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No albums found.'),
          );
        }
        
        final displayAlbums = _showAllAlbums ? albums : albums.take(4).toList();
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: displayAlbums.length,
                itemBuilder: (context, index) {
                  return _ArtistAlbumCard(album: displayAlbums[index]);
                },
              ),
            ),
            if (albums.length > 4) ...[
              const SizedBox(height: 24),
              _buildSeeMoreButton(
                isDark, 
                _showAllAlbums ? 'SHOW LESS' : 'SEE MORE',
                () => setState(() => _showAllAlbums = !_showAllAlbums),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSeeMoreButton(bool isDark, String label, VoidCallback onPressed) {
    return Center(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          minimumSize: const Size(120, 40),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 0.5,),
        ),
      ),
    );
  }

  Widget _buildSongsList(AsyncValue<List<ItunesTrack>> topSongsAsync, bool isDark) {
    return topSongsAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No songs found.')),
            ),
          );
        }
        
        final displayTracks = _showAllSongs ? tracks : tracks.take(5).toList();
        
        return SliverList(
          delegate: SliverChildListDelegate([
            ...displayTracks.map((track) => _ArtistSongTile(track: track)),
            if (tracks.length > 5) ...[
              const SizedBox(height: 16),
              _buildSeeMoreButton(
                isDark, 
                _showAllSongs ? 'SHOW LESS' : 'SEE MORE',
                () => setState(() => _showAllSongs = !_showAllSongs),
              ),
            ],
          ]),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $e')),
      ),
    );
  }

  /*Widget _buildDeezerTopTracksSection(AsyncValue<List<ItunesTrack>> topTracksAsync, bool isDark) {
    return topTracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'Top Tracks from Deezer (${tracks.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,),
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16),
                    child: _ArtistSongTile(track: track),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }*/

  Widget _buildDeezerPlaylistsSection(AsyncValue<List<DeezerPlaylist>> playlistsAsync, bool isDark) {
    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'Artist Playlists (${playlists.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailsScreen(
                            deezerPlaylist: playlist,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: playlist.artworkUrl,
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,),
                          ),
                          Text(
                            '${playlist.nbTracks} tracks',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isDark, AsyncValue<String?> bioAsync, AsyncValue<List<String>> similarAsync, AsyncValue<Map<String, dynamic>?> metadataAsync, AsyncValue<List<String>> deezerRelatedAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,),
          ),
        ),
        
        metadataAsync.when(
          data: (metadata) {
            if (metadata == null) return const SizedBox.shrink();
            
            final country = metadata['country'] as String?;
            final area = metadata['area']?['name'] as String?;
            final lifeSpan = metadata['life-span'];
            final tags = (metadata['tags'] as List<dynamic>?)?.take(5).map((t) => t['name'] as String).toList();
            final type = metadata['type'] as String?;
            final gender = metadata['gender'] as String?;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (type != null) ...[
                      Text(
                        'TYPE: ${type.toUpperCase()}${gender != null ? " ($gender)" : ""}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,),
                      ),
                      const SizedBox(height: 8),
                   ],
                   if (area != null) ...[
                      Text(
                        'ORIGIN: ${area}${country != null ? " ($country)" : ""}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,),
                      ),
                      const SizedBox(height: 8),
                   ],
                   if (lifeSpan != null && lifeSpan['begin'] != null) ...[
                      Text(
                        'FORMED: ${lifeSpan['begin']}${lifeSpan['end'] != null ? " - ${lifeSpan['end']}" : ""}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,),
                      ),
                      const SizedBox(height: 8),
                   ],
                   if (tags != null && tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        children: tags.map((tag) => Text(
                          '#${tag.toUpperCase().replaceAll(" ", "")}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                   ],
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        metadataAsync.when(
          data: (metadata) {
            final wikiBio = metadata?['biography'] as String?;
            if (wikiBio != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  wikiBio.length > 800 ? '${wikiBio.substring(0, 800).trim()}...' : wikiBio,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,),
                ),
              );
            }
            
            // Fallback to Last.fm bio
            return bioAsync.when(
              data: (bio) => bio != null ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  bio,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,),
                ),
              ) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => bioAsync.when(
            data: (bio) => bio != null ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  bio,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,),
                ),
              ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          error: (_, __) => bioAsync.when(
            data: (bio) => bio != null ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  bio,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,),
                ),
              ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        similarAsync.when(
          data: (similar) {
            final Set<String> combinedSet = {...similar};
            
            metadataAsync.whenData((metadata) {
              if (metadata != null && metadata['relations'] != null) {
                final relations = metadata['relations'] as List<dynamic>;
                for (final rel in relations) {
                  if (rel['target-type'] == 'artist' && rel['artist'] != null) {
                    final relatedName = rel['artist']['name'] as String;
                    if (relatedName != widget.artistName) {
                      combinedSet.add(relatedName);
                    }
                  }
                }
              }
            });

            deezerRelatedAsync.whenData((deezerSim) {
              for (final name in deezerSim) {
                if (name != widget.artistName) {
                  combinedSet.add(name);
                }
              }
            });

            final List<String> combinedSimilar = combinedSet.toList();
            if (combinedSimilar.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                  child: Text(
                    'Similar Artists',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,),
                  ),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: combinedSimilar.length,
                    itemBuilder: (context, index) => _SimilarArtistAvatar(name: combinedSimilar[index]),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ArtistAlbumCard extends StatelessWidget {
  final ItunesTrack album;

  const _ArtistAlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => AlbumScreen(album: album)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: album.artworkUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                errorWidget: (_, __, ___) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Icon(Icons.album, color: Colors.white24, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.collectionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,),
          ),
          const SizedBox(height: 2),
          Text(
            album.releaseDate?.year.toString() ?? '',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
          ),
        ],
      ),
    );
  }
}

class _ArtistSongTile extends ConsumerStatefulWidget {
  final ItunesTrack track;

  const _ArtistSongTile({required this.track});

  @override
  ConsumerState<_ArtistSongTile> createState() => _ArtistSongTileState();
}

class _ArtistSongTileState extends ConsumerState<_ArtistSongTile> {
  bool _isCheckingSources = false;

  void _handleTap(TorBoxFile? matchingFile) async {
    // If the file is already downloaded or in library, just play it.
    if (matchingFile != null) {
      final trackMeta = ItunesMeta(
        trackName: widget.track.trackName,
        artistName: widget.track.artistName,
        artworkUrlLow: widget.track.artworkUrl,
        artworkUrlHigh: widget.track.artworkUrl.replaceAll('600x600bb', '1000x1000bb'),
        album: widget.track.collectionName,
      );
      await ref.read(libraryProvider.notifier).updateTrackMetadata(matchingFile, trackMeta);

      if (mounted) {
      final trackUrl = matchingFile.localPath != null 
          ? Uri.file(matchingFile.localPath!).toString() 
          : 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}';

      await audioHandler.customAction('play', {
        'url': trackUrl,
        'title': widget.track.trackName,
        'artist': widget.track.artistName,
        'artworkUrl': widget.track.artworkUrl.replaceAll('600x600bb', '1000x1000bb'),
        'forceReplace': false,
        'extras': {
          'torrentId': matchingFile.torrentId,
          'fileId': matchingFile.id,
          'size': matchingFile.size,
          'localPath': matchingFile.localPath,
        },
      });

      if (mounted) {
        if (audioHandler.playbackState.value.playing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to Next in Queue'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: matchingFile,
              customQueue: [matchingFile],
            ),
          ),
        );
      }
    }
    return;
    }

    // Try finding a direct FLAC
    setState(() => _isCheckingSources = true);
    final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
      widget.track.trackName, 
      widget.track.artistName
    );
    
    // Safety check because widget lifecycle might have ended
    if (!mounted) return;
    setState(() => _isCheckingSources = false);

    if (flacResult != null) {
      // Direct stream found!
      final dummyFile = TorBoxFile(
        id: -flacResult.url.hashCode.abs(),
        torrentId: -1,
        size: flacResult.size,
        name: flacResult.title,
        localPath: null,
      );

      // Let AudioHandler know
      await audioHandler.customAction('play', {
        'url': flacResult.url,
        'title': widget.track.trackName, // Prefer iTunes metadata
        'artist': widget.track.artistName,
        'artworkUrl': widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        'forceReplace': false,
        'extras': {
          'torrentId': dummyFile.torrentId,
          'fileId': dummyFile.id,
          'size': dummyFile.size,
          'localPath': null,
          'source': flacResult.source,
        },
      });

      if (mounted) {
        if (audioHandler.playbackState.value.playing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to Next in Queue'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: dummyFile,
              customQueue: [dummyFile],
            ),
          ),
        );
      }
    } else {
      // Fallback: ask the user to pick from generic torrents / YT
      _showSourcePicker(context, widget.track);
    }
  }

  void _showSourcePicker(BuildContext context, ItunesTrack track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchingFile = ref.read(libraryProvider).findMatchingTrack(widget.track.trackName, widget.track.artistName);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: _isCheckingSources ? null : () => _handleTap(matchingFile),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.track.artworkUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isCheckingSources)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimilarArtistAvatar extends ConsumerWidget {
  final String name;
  const _SimilarArtistAvatar({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageAsync = ref.watch(artistImageProvider(ArtistImageParams(name: name)));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artistName: name)),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            imageAsync.when(
              data: (url) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                child: ClipOval(
                  child: url != null
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          errorWidget: (context, url, e) => _defaultPlaceholder(isDark),
                        )
                      : _defaultPlaceholder(isDark),
                ),
              ),
              loading: () => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => _defaultPlaceholder(isDark),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.2,),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.person,
        color: isDark ? Colors.white24 : Colors.black26,
        size: 50,
      ),
    );
  }
}
