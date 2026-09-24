import 'dart:async';
import 'package:isai/core/utils/app_haptics.dart';
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
            SliverToBoxAdapter(child: RepaintBoundary(child: const SizedBox.shrink())),
            _buildArtistHeader(context, isDark, artistImageAsync, artistDetailsAsync, isFollowed, metadataAsync, deezerArtistDetailsAsync, topSongsAsync, albumsAsync),
            // TODO:
            // - [ ] Improved Artist Image Fetching
            //   - [ ] Update `ItunesMetadataService` to fetch profile image from `artistViewUrl`.
            //   - [ ] Test with several artists (e.g. Frank Ocean, Michael Jackson).
            
            // Section divider
            SliverToBoxAdapter(child: _buildSectionDivider(context, isDark)),

            // Popular Songs Header
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                isDark: isDark,
                icon: Icons.music_note_rounded,
                title: 'Popular Songs',
                count: topSongsAsync.asData?.value?.length,
                onSeeAll: (topSongsAsync.asData?.value != null && (topSongsAsync.asData?.value?.length ?? 0) > 10)
                    ? () {
                        AppHaptics.light(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllPopularSongsScreen(
                              artistName: widget.artistName,
                              songs: topSongsAsync.asData!.value,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            _buildSongsList(topSongsAsync, isDark),

            // Section divider
            SliverToBoxAdapter(child: _buildSectionDivider(context, isDark)),

            // Albums Section Header
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                isDark: isDark,
                icon: Icons.album_rounded,
                title: 'Albums',
                count: albumsAsync.asData?.value?.length,
                onSeeAll: (albumsAsync.asData?.value != null && (albumsAsync.asData?.value?.length ?? 0) > 10)
                    ? () {
                        AppHaptics.light(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllAlbumsScreen(
                              artistName: widget.artistName,
                              albums: albumsAsync.asData!.value,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            // Albums Section
            _buildAlbumsSectionSliver(albumsAsync, isDark),

            // Section divider
            SliverToBoxAdapter(child: _buildSectionDivider(context, isDark)),

            // Artist Playlists Header
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                isDark: isDark,
                icon: Icons.queue_music_rounded,
                title: 'Artist Playlists',
                count: deezerPlaylistsAsync.asData?.value?.length,
                onSeeAll: (deezerPlaylistsAsync.asData?.value != null && (deezerPlaylistsAsync.asData?.value?.length ?? 0) > 10)
                    ? () {
                        AppHaptics.light(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllArtistPlaylistsScreen(
                              artistName: widget.artistName,
                              playlists: deezerPlaylistsAsync.asData!.value,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            SliverToBoxAdapter(
              child: RepaintBoundary(child: _buildDeezerPlaylistsSection(deezerPlaylistsAsync, isDark)),
            ),

            // Section divider
            SliverToBoxAdapter(child: _buildSectionDivider(context, isDark)),

            // About Header
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                isDark: isDark,
                icon: Icons.info_outline_rounded,
                title: 'About',
              ),
            ),

            SliverToBoxAdapter(
              child: RepaintBoundary(child: _buildAboutSection(context, isDark, bioAsync, similarAsync, metadataAsync, deezerRelatedAsync)),
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
        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        widget.artistName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, color: isDark ? Colors.white70 : Colors.black54),
          onPressed: () => _shareArtist(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _shareArtist(BuildContext context) {
    AppHaptics.light(context);
    final text = 'Check out ${widget.artistName} on Isai!';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${widget.artistName}" to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    int? count,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count != null ? '$title ($count)' : title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'SEE ALL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
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
    AsyncValue<List<ItunesTrack>> topSongsAsync,
    AsyncValue<List<ItunesTrack>> albumsAsync,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = (screenWidth * 0.4).clamp(120.0, 160.0);

    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Circular Artist Image with glow
          artistImageAsync.when(
            data: (url) => Center(
              child: Container(
                width: imageSize + 6,
                height: imageSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
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
            ),
            loading: () => Center(
              child: Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (_, __) => Center(child: _buildArtistAvatarPlaceholder(imageSize, isDark)),
          ),
          const SizedBox(height: 20),

          // Artist Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.artistName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Genre chip
          artistDetailsAsync.when(
            data: (details) => details?.primaryGenreName != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        details!.primaryGenreName!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox(height: 18),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(
                  icon: Icons.music_note_rounded,
                  label: '${topSongsAsync.asData?.value?.length ?? 0} songs',
                  isDark: isDark,
                ),
                if ((topSongsAsync.asData?.value?.length ?? 0) > 0 && (albumsAsync.asData?.value?.length ?? 0) > 0)
                  Container(width: 1, height: 16, color: isDark ? Colors.white12 : Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 12)),
                if ((albumsAsync.asData?.value?.length ?? 0) > 0)
                  _buildStatChip(
                    icon: Icons.album_rounded,
                    label: '${albumsAsync.asData?.value?.length ?? 0} albums',
                    isDark: isDark,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle button
                _buildActionButton(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  isDark: isDark,
                  onTap: () {
                    AppHaptics.light(context);
                    _playAllTopSongs(topSongsAsync.asData?.value);
                  },
                ),
                const SizedBox(width: 12),
                // Follow button
                artistDetailsAsync.when(
                  data: (details) => _buildActionButton(
                    icon: isFollowed ? Icons.check_rounded : Icons.add_rounded,
                    label: isFollowed ? 'Following' : 'Follow',
                    isDark: isDark,
                    isActive: isFollowed,
                    onTap: details == null ? null : () => _handleFollowTap(details, isFollowed, artistImageAsync.asData?.value),
                  ),
                  loading: () => _buildActionButton(icon: Icons.add_rounded, label: 'Follow', isDark: isDark, onTap: null),
                  error: (_, __) => _buildActionButton(icon: Icons.add_rounded, label: 'Follow', isDark: isDark, onTap: null),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Thin divider
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label, required bool isDark}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isActive ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white70 : Colors.black54),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playAllTopSongs(List<ItunesTrack>? tracks) {
    if (tracks == null || tracks.isEmpty) return;
    final shuffled = List<ItunesTrack>.from(tracks)..shuffle();

    final library = ref.read(libraryProvider);
    final customQueue = shuffled.map<TorBoxFile>((t) {
      final match = library.findMatchingTrack(t.trackName, t.artistName);
      if (match != null) return match;
      return TorBoxFile(
        id: -t.hashCode,
        torrentId: -1,
        name: t.trackName,
        size: 0,
        localPath: null,
      );
    }).toList();

    final firstMatch = customQueue.firstWhere(
      (f) => f.torrentId != -1,
      orElse: () => customQueue.first,
    );

    final url = firstMatch.localPath != null
        ? Uri.file(firstMatch.localPath!).toString()
        : firstMatch.torrentId != -1
            ? 'https://lazy.torbox.internal/${firstMatch.torrentId}/${firstMatch.id}'
            : 'https://lazy.flac.internal/?title=${Uri.encodeComponent(shuffled.first.trackName)}&artist=${Uri.encodeComponent(shuffled.first.artistName)}';

    audioHandler.customAction('play', {
      'url': url,
      'title': shuffled.first.trackName,
      'artist': shuffled.first.artistName,
      'artworkUrl': shuffled.first.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
      'forceReplace': true,
      'queue': List.generate(customQueue.length, (i) {
        final e = customQueue[i];
        final qTrack = shuffled[i];
        String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
        if (e.torrentId == -1) {
          fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qTrack.trackName)}&artist=${Uri.encodeComponent(qTrack.artistName)}';
        }
        return {
          'url': fUrl,
          'title': qTrack.trackName,
          'artist': qTrack.artistName,
          'artworkUrl': qTrack.artworkUrl != null
              ? qTrack.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000')
              : null,
          'extras': {
            'torrentId': e.torrentId,
            'fileId': e.id,
            'size': e.size,
            'localPath': e.localPath,
          },
        };
      }),
      'index': 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shuffling ${tracks.length} songs'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          file: firstMatch,
          customQueue: customQueue,
        ),
      ),
    );
  }

  void _handleFollowTap(ItunesArtist details, bool isFollowed, String? artworkUrl) async {
    AppHaptics.medium(context);
    final repo = getIt<MusicRepository>();
    if (isFollowed) {
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
  }

  Widget _buildArtistAvatarPlaceholder(double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: isDark ? Colors.white24 : Colors.black26,
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

  Widget _buildAlbumsSectionSliver(AsyncValue<List<ItunesTrack>> albumsAsync, bool isDark) {
    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('No albums found.'),
            ),
          );
        }
        
        final previewAlbums = albums.take(10).toList();
        final hasMore = albums.length > 10;
        
        return SliverToBoxAdapter(
          child: RepaintBoundary(
            child: SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: previewAlbums.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < previewAlbums.length) {
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 16),
                    child: _ArtistAlbumCard(
                      key: ValueKey(previewAlbums[index].trackId),
                      album: previewAlbums[index],
                    ),
                  );
                }

                // Show More Card at the end of 10 items
                return GestureDetector(
                  onTap: () {
                    AppHaptics.light(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllAlbumsScreen(
                          artistName: widget.artistName,
                          albums: albums,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Show More',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+${albums.length - 10} albums',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
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
        
        final previewTracks = tracks.take(10).toList();
        final hasMore = tracks.length > 10;
        final library = ref.read(libraryProvider);

        return SliverMainAxisGroup(
          slivers: [
            SliverFixedExtentList(
              itemExtent: 64.0,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = previewTracks[index];
                  final matchingFile = library.findMatchingTrack(track.trackName, track.artistName);
                  return _ArtistSongTile(
                    key: ValueKey(track.trackId),
                    track: track,
                    index: index,
                    matchingFile: matchingFile,
                  );
                },
                childCount: previewTracks.length,
              ),
            ),
            if (hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppHaptics.light(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllPopularSongsScreen(
                              artistName: widget.artistName,
                              songs: tracks,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                      label: Text(
                        'SHOW ALL (${tracks.length})',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                    child: _ArtistSongTile(track: track, index: index),
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
        final previewPlaylists = playlists.take(10).toList();
        final hasMore = playlists.length > 10;

        return SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: previewPlaylists.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < previewPlaylists.length) {
                final playlist = previewPlaylists[index];
                final isWide = index % 3 == 0;
                final cardWidth = isWide ? 180.0 : 150.0;
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
                    width: cardWidth,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: playlist.artworkUrl,
                              memCacheWidth: 320,
                              memCacheHeight: 320,
                              width: cardWidth,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playlist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${playlist.nbTracks} tracks',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Show More Card at the end of 10 items
              return GestureDetector(
                onTap: () {
                  AppHaptics.light(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllArtistPlaylistsScreen(
                        artistName: widget.artistName,
                        playlists: playlists,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Show More',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${playlists.length - 10} playlists',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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

        metadataAsync.when(
          data: (metadata) {
            if (metadata == null) return const SizedBox.shrink();

            final country = metadata['country'] as String?;
            final area = metadata['area']?['name'] as String?;
            final lifeSpan = metadata['life-span'];
            final tags = (metadata['tags'] as List<dynamic>?)?.take(5).map((t) => t['name'] as String).toList();
            final type = metadata['type'] as String?;
            final gender = metadata['gender'] as String?;
            final beginYear = lifeSpan?['begin'] as String?;
            final endYear = lifeSpan?['end'] as String?;

            final infoRows = <Widget>[];
            if (type != null) {
              infoRows.add(_buildInfoRow(
                context: context,
                icon: Icons.category_rounded,
                label: '${type.substring(0, 1).toUpperCase()}${type.substring(1)}${gender != null ? " · ${gender.substring(0, 1).toUpperCase()}${gender.substring(1)}" : ""}',
              ));
            }
            if (area != null) {
              infoRows.add(_buildInfoRow(
                context: context,
                icon: Icons.location_on_rounded,
                label: '$area${country != null ? " ($country)" : ""}',
              ));
            }
            if (beginYear != null) {
              final parsedYear = int.tryParse(beginYear.length >= 4 ? beginYear.substring(0, 4) : '');
              final age = parsedYear != null ? DateTime.now().year - parsedYear : null;
              infoRows.add(_buildInfoRow(
                context: context,
                icon: Icons.calendar_month_rounded,
                label: 'DOB ${beginYear}${age != null ? " · $age yrs" : ""}${endYear != null ? " - $endYear" : ""}',
              ));
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...infoRows,
                  if (tags != null && tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        _buildBioSection(context, isDark, bioAsync, metadataAsync),

        const SizedBox(height: 8),

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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Similar Artists (${combinedSimilar.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 180,
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

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(BuildContext context, bool isDark, AsyncValue<String?> bioAsync, AsyncValue<Map<String, dynamic>?> metadataAsync) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        bool bioExpanded = false;
        String? fullBio;

        return metadataAsync.when(
          data: (metadata) {
            final wikiBio = metadata?['biography'] as String?;

            if (wikiBio != null) {
              fullBio = wikiBio;
            }

            if (fullBio == null) {
              return bioAsync.when(
                data: (bio) {
                  if (bio == null) return const SizedBox.shrink();
                  fullBio = bio;
                  return _buildBioText(context, isDark, fullBio!, bioExpanded, () {
                    setInnerState(() => bioExpanded = !bioExpanded);
                  });
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            }

            return _buildBioText(context, isDark, fullBio!, bioExpanded, () {
              setInnerState(() => bioExpanded = !bioExpanded);
            });
          },
          loading: () => bioAsync.when(
            data: (bio) => bio != null ? _buildBioText(context, isDark, bio, bioExpanded, () {
              setInnerState(() => bioExpanded = !bioExpanded);
            }) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          error: (_, __) => bioAsync.when(
            data: (bio) => bio != null ? _buildBioText(context, isDark, bio, bioExpanded, () {
              setInnerState(() => bioExpanded = !bioExpanded);
            }) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildBioText(BuildContext context, bool isDark, String bio, bool expanded, VoidCallback onToggle) {
    final maxPreviewLength = 800;
    final isLong = bio.length > maxPreviewLength;
    final displayText = isLong && !expanded ? '${bio.substring(0, maxPreviewLength).trim()}...' : bio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
          if (isLong)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: onToggle,
                child: Row(
                  children: [
                    Text(
                      expanded ? 'Show less' : 'Read more',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistAlbumCard extends StatelessWidget {
  final ItunesTrack album;

  const _ArtistAlbumCard({super.key, required this.album});

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
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: album.artworkUrl,
                    memCacheWidth: 320,
                    memCacheHeight: 320,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Icon(Icons.album, color: Colors.white24, size: 48),
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ),
                  // Year badge
                  if (album.releaseDate?.year != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${album.releaseDate!.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.collectionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.collectionName.isNotEmpty ? 'Album' : '',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistSongTile extends StatefulWidget {
  final ItunesTrack track;
  final int index;
  final TorBoxFile? matchingFile;

  const _ArtistSongTile({
    super.key,
    required this.track,
    required this.index,
    required this.matchingFile,
  });

  @override
  State<_ArtistSongTile> createState() => _ArtistSongTileState();
}

class _ArtistSongTileState extends State<_ArtistSongTile> {
  bool _isCheckingSources = false;

  void _handleTap() async {
    final matchingFile = widget.matchingFile;
    // If the file is already downloaded or in library, just play it.
    if (matchingFile != null) {
      final trackMeta = ItunesMeta(
        trackName: widget.track.trackName,
        artistName: widget.track.artistName,
        artworkUrlLow: widget.track.artworkUrl,
        artworkUrlHigh: widget.track.artworkUrl.replaceAll('600x600bb', '1000x1000bb'),
        album: widget.track.collectionName,
      );
      // Fire-and-forget metadata persistence to prevent blocking instant playback start
      unawaited(ProviderScope.containerOf(context).read(libraryProvider.notifier).updateTrackMetadata(matchingFile, trackMeta));

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
    final flacResult = await ProviderScope.containerOf(context).read(flacSearchProvider.notifier).resolveDirectFlac(
      widget.track.trackName,
      widget.track.artistName,
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
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black45;
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        child: InkWell(
          onTap: _isCheckingSources ? null : _handleTap,
          borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              // Track number
              SizedBox(
                width: 28,
                child: Text(
                  '${widget.index + 1}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Artwork
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: widget.track.artworkUrl,
                      memCacheWidth: 150,
                      memCacheHeight: 150,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isCheckingSources)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            imageAsync.when(
              data: (url) => Container(
                width: 120,
                height: 120,
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
                width: 120,
                height: 120,
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

enum AlbumSortOrder { newest, oldest, name }

class AllAlbumsScreen extends StatefulWidget {
  final String artistName;
  final List<ItunesTrack> albums;

  const AllAlbumsScreen({
    super.key,
    required this.artistName,
    required this.albums,
  });

  @override
  State<AllAlbumsScreen> createState() => _AllAlbumsScreenState();
}

class _AllAlbumsScreenState extends State<AllAlbumsScreen> {
  AlbumSortOrder _sortOrder = AlbumSortOrder.newest;
  final ScrollController _scrollController = ScrollController();

  List<ItunesTrack> get _sortedAlbums {
    final list = List<ItunesTrack>.from(widget.albums);
    switch (_sortOrder) {
      case AlbumSortOrder.newest:
        list.sort((a, b) {
          final yearA = a.releaseDate?.year ?? 0;
          final yearB = b.releaseDate?.year ?? 0;
          return yearB.compareTo(yearA);
        });
        break;
      case AlbumSortOrder.oldest:
        list.sort((a, b) {
          final yearA = a.releaseDate?.year ?? 9999;
          final yearB = b.releaseDate?.year ?? 9999;
          return yearA.compareTo(yearB);
        });
        break;
      case AlbumSortOrder.name:
        list.sort((a, b) => a.collectionName.toLowerCase().compareTo(b.collectionName.toLowerCase()));
        break;
    }
    return list;
  }

  List<int> get _availableYears {
    final years = widget.albums
        .map((a) => a.releaseDate?.year)
        .whereType<int>()
        .toSet()
        .toList();
    years.sort((a, b) => _sortOrder == AlbumSortOrder.oldest ? a.compareTo(b) : b.compareTo(a));
    return years;
  }

  void _scrollToYear(int year, List<ItunesTrack> sortedList) {
    final index = sortedList.indexWhere((a) => a.releaseDate?.year == year);
    if (index != -1 && _scrollController.hasClients) {
      final crossAxisCount = (MediaQuery.of(context).size.width / 180.0).floor().clamp(2, 6);
      final rowIndex = index ~/ crossAxisCount;
      final offset = rowIndex * 220.0;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sortedAlbums;
    final years = _availableYears;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Discography',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${widget.albums.length} Albums • ${widget.artistName}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<AlbumSortOrder>(
            icon: Icon(Icons.sort_rounded, color: isDark ? Colors.white : Colors.black),
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AlbumSortOrder.newest,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 18,
                      color: _sortOrder == AlbumSortOrder.newest ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Newest First', style: TextStyle(fontWeight: _sortOrder == AlbumSortOrder.newest ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AlbumSortOrder.oldest,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: _sortOrder == AlbumSortOrder.oldest ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Oldest First', style: TextStyle(fontWeight: _sortOrder == AlbumSortOrder.oldest ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AlbumSortOrder.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha_rounded,
                      size: 18,
                      color: _sortOrder == AlbumSortOrder.name ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Alphabetical (A-Z)', style: TextStyle(fontWeight: _sortOrder == AlbumSortOrder.name ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Horizontal Year Selector Quick Bar
              if (years.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: years.length,
                    itemBuilder: (context, idx) {
                      final yr = years[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            '$yr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                          side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          onPressed: () => _scrollToYear(yr, sorted),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final maxCardWidth = 180.0;
                    final crossAxisCount = (maxWidth / (maxCardWidth + 16)).floor().clamp(2, 6);
                    final cardWidth = (maxWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
                    final aspectRatio = cardWidth / (cardWidth + 58.0);

                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _ArtistAlbumCard(
                          key: ValueKey(sorted[index].trackId),
                          album: sorted[index],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AllPopularSongsScreen extends StatelessWidget {
  final String artistName;
  final List<ItunesTrack> songs;

  const AllPopularSongsScreen({
    super.key,
    required this.artistName,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final library = ProviderScope.containerOf(context).read(libraryProvider);
    final matchCache = <int, TorBoxFile?>{
      for (final song in songs)
        song.trackId: library.findMatchingTrack(song.trackName, song.artistName),
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Popular Songs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${songs.length} Tracks • $artistName',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemExtent: 72.0,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _ArtistSongTile(
            key: ValueKey(song.trackId),
            track: song,
            index: index,
            matchingFile: matchCache[song.trackId],
          );
        },
      ),
    );
  }
}

class AllArtistPlaylistsScreen extends StatelessWidget {
  final String artistName;
  final List<DeezerPlaylist> playlists;

  const AllArtistPlaylistsScreen({
    super.key,
    required this.artistName,
    required this.playlists,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Artist Playlists',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${playlists.length} Playlists • $artistName',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxCardWidth = 180.0;
          final crossAxisCount = (maxWidth / (maxCardWidth + 16)).floor().clamp(2, 6);
          final cardWidth = (maxWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
          final aspectRatio = cardWidth / (cardWidth + 58.0);

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: aspectRatio,
            ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: playlist.artworkUrl,
                          memCacheWidth: 320,
                          memCacheHeight: 320,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${playlist.nbTracks} tracks',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
