import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:isai/main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import 'playlist_providers.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import '../../../core/database/database.dart';
import 'metadata_picker_sheet.dart';
import 'track_action_sheet.dart';
import 'music_providers.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    ref.listen(settingsProvider, (prev, next) {
      if (next.eclipseIsValid && (prev == null || !prev.eclipseIsValid)) {
        ref.read(playlistProvider.notifier).importEclipsePlaylists();
      }
    });
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
        child: RefreshIndicator(
          onRefresh: () => ref.read(playlistProvider.notifier).refresh(),
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
              actions: [
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _showImportOptions(context, ref),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Playlists',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 48, bottom: 16),
              ),
            ),
            playlistsAsync.when(
              data: (allPlaylists) {
                final playlists = allPlaylists.where((p) => p.playlist.sourceUrl == null || !p.playlist.sourceUrl!.contains('album_')).toList();
                final isEmpty = playlists.isEmpty;
                
                return isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.playlist_add_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                              const SizedBox(height: 16),
                              Text(
                                'No playlists yet',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  AppleMusicChip(
                                    label: 'YouTube',
                                    onTap: () => _showImportDialog(context, ref),
                                  ),
                                  AppleMusicChip(
                                    label: 'Spotify',
                                    onTap: () => _showImportDialog(context, ref, isSpotify: true),
                                  ),
                                  AppleMusicChip(
                                    label: 'JSON File',
                                    onTap: () => _importPlaylistFromFile(context, ref),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridCrossAxisCount(context),
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = playlists[index];
                              return _PlaylistCard(item: item);
                            },
                            childCount: playlists.length,
                          ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref, {bool isSpotify = false}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(isSpotify ? 'Import Spotify Playlist' : 'Import YouTube Playlist', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: isSpotify ? 'Paste Spotify playlist link...' : 'Paste YouTube/Music link...',
            hintStyle: const TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(dialogContext);
                try {
                  if (isSpotify) {
                    await ref.read(playlistProvider.notifier).importSpotifyPlaylist(url);
                  } else {
                    await ref.read(playlistProvider.notifier).importYoutubePlaylist(url);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully imported ${isSpotify ? 'Spotify' : 'YouTube'} playlist!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (errorDialogContext) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text('Import Failed', style: TextStyle(color: Colors.white)),
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(errorDialogContext),
                            child: Text('OK', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          ),
                        ],
                      ),
                    );
                  }
                }
              }
            },
            child: Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.link_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text('Import from YouTube Link'),
              onTap: () {
                Navigator.pop(context);
                _showImportDialog(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.music_note_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text('Import from Spotify Link'),
              onTap: () {
                Navigator.pop(context);
                _showImportDialog(context, ref, isSpotify: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.file_open_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text('Import Playlists (JSON / Backup)'),
              onTap: () {
                Navigator.pop(context);
                _importPlaylistFromFile(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.backup_table_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text('Export All Playlists (Backup)'),
              onTap: () {
                Navigator.pop(context);
                _exportAllPlaylists(context, ref);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _importPlaylistFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final content = await file.readAsString();

        final count = await ref.read(playlistProvider.notifier).importAllPlaylistsFromJson(content);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported $count playlist${count > 1 ? 's' : ''}!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import backup: $e')),
        );
      }
    }
  }

  Future<void> _exportAllPlaylists(BuildContext context, WidgetRef ref) async {
    try {
      final jsonStr = await ref.read(playlistProvider.notifier).exportAllPlaylistsToJson();
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${tempDir.path}/isai_playlists_backup_$dateStr.json');
      await file.writeAsString(jsonStr);
      
      await Share.shareXFiles([XFile(file.path)], text: 'My Isai Playlists Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting playlists: $e')),
        );
      }
    }
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

Future<void> _sharePlaylistHelper(BuildContext context, WidgetRef ref, int playlistId, String playlistName) async {
  try {
    final jsonStr = await ref.read(playlistProvider.notifier).exportPlaylistToJson(playlistId);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$playlistName.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles([XFile(file.path)], text: 'Check out my playlist: $playlistName!');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing playlist: $e')),
      );
    }
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistWithCount item;

  const _PlaylistCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailsScreen(
              localPlaylist: item.playlist,
            ),
          ),
        );
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Consumer(
            builder: (context, ref, _) => Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('Share Playlist', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    onTap: () {
                      Navigator.pop(context);
                      _sharePlaylistHelper(context, ref, item.playlist.id, item.playlist.name);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final tracksAsync = ref.watch(playlistTracksProvider(item.playlist.id));
                          return tracksAsync.when(
                            data: (tracks) {
                              // Prioritize the first track with artwork over the playlist's own artwork
                              final imageUrl = tracks.where((t) => t.artworkUrl != null && t.artworkUrl!.isNotEmpty).firstOrNull?.artworkUrl 
                                  ?? item.playlist.artworkUrl;

                              return imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.grey[800]),
                                      errorWidget: (context, url, error) => _IconPlaceholder(),
                                    )
                                  : _IconPlaceholder();
                            },
                            loading: () => Container(color: Colors.grey[800]),
                            error: (_, __) => _IconPlaceholder(),
                          );
                        },
                      ),
                      if (item.playlist.eclipseId != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_outlined, size: 10, color: Colors.white70),
                                SizedBox(width: 3),
                                Text('Eclipse', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.playlist.name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${item.count} songs',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Delete Playlist?', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to delete "${item.playlist.name}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(playlistProvider.notifier).deletePlaylist(item.playlist.id);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}


class _IconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 48, color: Colors.white24),
      ),
    );
  }
}

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final DbPlaylist? localPlaylist;
  final AppleMusicPlaylist? appleMusicPlaylist;
  final DeezerPlaylist? deezerPlaylist;
  final List<ItunesTrack>? customTracks;
  final String? customTitle;
  final String? customArtwork;

  const PlaylistDetailsScreen({
    super.key,
    this.localPlaylist,
    this.appleMusicPlaylist,
    this.deezerPlaylist,
    this.customTracks,
    this.customTitle,
    this.customArtwork,
  });

  @override
  ConsumerState<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> {
  late ScrollController _scrollController;
  String? _lastExtractedKey;
  Color? _dominantColor;
  Color? _vibrantColor;
  Color? _mutedColor;

  void _extractColors(String artworkUrl, bool isDark) async {
    final key = '${artworkUrl}_$isDark';
    if (_lastExtractedKey == key) return;
    _lastExtractedKey = key;
    
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(artworkUrl),
        maximumColorCount: 20,
      );
      
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color;
          _vibrantColor = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color;
          _mutedColor = palette.mutedColor?.color ?? palette.darkMutedColor?.color;
        });
      }
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  /// Build a dark, atmospheric gradient inspired by Apple Music.
  /// Uses HSL manipulation to desaturate and darken the cover art color,
  /// creating a moody backdrop that isn't flat or overly saturated.
  List<Color> _buildGradientColors(bool isDark) {
    final base = _dominantColor ?? _vibrantColor ?? _mutedColor ?? Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(base);

    if (isDark) {
      return [
        hsl.withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
            .withLightness(0.30).toColor(),
        hsl.withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
            .withLightness(0.25).toColor(),
        hsl.withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
            .withLightness(0.22).toColor(),
        hsl.withSaturation((hsl.saturation * 0.50).clamp(0.0, 1.0))
            .withLightness(0.19).toColor(),
        hsl.withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
            .withLightness(0.16).toColor(),
      ];
    } else {
      return [
        hsl.withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
            .withLightness(0.30).toColor(),
        hsl.withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
            .withLightness(0.25).toColor(),
        hsl.withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
            .withLightness(0.22).toColor(),
        hsl.withSaturation((hsl.saturation * 0.50).clamp(0.0, 1.0))
            .withLightness(0.19).toColor(),
        hsl.withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
            .withLightness(0.16).toColor(),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (widget.deezerPlaylist != null) {
        ref.read(deezerPlaylistTracksProvider(widget.deezerPlaylist!.id).notifier).fetchNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localPlaylist = widget.localPlaylist;
    final appleMusicPlaylist = widget.appleMusicPlaylist;
    final deezerPlaylist = widget.deezerPlaylist;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth * 0.55).clamp(160.0, 300.0);
    
    final title = localPlaylist?.name ?? appleMusicPlaylist?.name ?? deezerPlaylist?.title ?? widget.customTitle ?? 'Unknown Playlist';
    final artworkUrl = localPlaylist?.artworkUrl ?? appleMusicPlaylist?.artworkUrl ?? deezerPlaylist?.artworkUrl ?? widget.customArtwork;

    AsyncValue<List<dynamic>> tracksAsync;
    if (localPlaylist != null) {
      tracksAsync = ref.watch(playlistTracksProvider(localPlaylist.id));
    } else if (appleMusicPlaylist != null) {
      if (appleMusicPlaylist.url.contains('jiosaavn.com')) {
        tracksAsync = ref.watch(jiosaavnPlaylistTracksProvider(appleMusicPlaylist.url));
      } else {
        tracksAsync = ref.watch(appleMusicPlaylistNotifierProvider(appleMusicPlaylist.url));
      }
    } else if (deezerPlaylist != null) {
      tracksAsync = ref.watch(deezerPlaylistTracksProvider(deezerPlaylist.id));
    } else if (widget.customTracks != null) {
      tracksAsync = AsyncValue.data(widget.customTracks!);
    } else {
      tracksAsync = const AsyncValue.data([]);
    }

    // Resolve display artwork
    String? displayArtwork = artworkUrl;
    final tracksValue = tracksAsync.value;
    if (tracksValue != null && tracksValue.isNotEmpty) {
      if (tracksValue.first is DbPlaylistTrack) {
        displayArtwork = (tracksValue as List<DbPlaylistTrack>).where((t) => t.artworkUrl != null && t.artworkUrl!.isNotEmpty).firstOrNull?.artworkUrl ?? artworkUrl;
      } else if (tracksValue.first is ItunesTrack) {
        displayArtwork = artworkUrl;
      }
    }

    if (displayArtwork != null && displayArtwork.isNotEmpty) {
      _extractColors(displayArtwork, isDark);
    }

    final gradientColors = _buildGradientColors(isDark);


    // Source name for display
    final sourceName = localPlaylist != null 
        ? 'Local Playlist' 
        : deezerPlaylist != null 
            ? 'Deezer' 
            : widget.customTracks != null
                ? 'Curated'
                : (appleMusicPlaylist != null && appleMusicPlaylist.url.contains('jiosaavn.com'))
                    ? 'JioSaavn'
                    : 'Apple Music';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
            stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // --- Transparent App Bar ---
            SliverAppBar(
              floating: false,
              pinned: true,
              expandedHeight: 0,
              toolbarHeight: 56,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (localPlaylist != null) ...[
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white70),
                    onPressed: () => _sharePlaylistHelper(context, ref, localPlaylist.id, localPlaylist.name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _showDeleteConfirmation(context),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                    onPressed: () {},
                  ),
              ],
            ),

            // --- Hero Header: Cover Art + Metadata + Buttons ---
            SliverToBoxAdapter(
              child: tracksAsync.when(
                data: (tracks) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      
                      // Cover Art Card with shadow
                      Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (displayArtwork != null && displayArtwork.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: displayArtwork,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: isDark ? Colors.grey[900] : Colors.grey[300],
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? Colors.grey[900] : Colors.grey[300],
                                    child: const Icon(Icons.music_note_rounded, size: 64, color: Colors.white24),
                                  ),
                                )
                              : Container(
                                  color: isDark ? Colors.grey[900] : Colors.grey[300],
                                  child: const Icon(Icons.music_note_rounded, size: 64, color: Colors.white24),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Playlist Title (centered)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          height: 1.2,),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Source label
                      Text(
                        sourceName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w500,),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      
                      // Track count & metadata
                      Text(
                        '${tracks.length} tracks',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w400,),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // --- Buttons Row: Shuffle | Play | Add ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           // Shuffle button (circle)
                          _buildCircleButton(
                            icon: Icons.shuffle_rounded,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (tracks.isNotEmpty) {
                                if (localPlaylist != null) {
                                  final shuffled = List<DbPlaylistTrack>.from(tracks)..shuffle();
                                  _playLocalTracks(ref, context, shuffled, startIndex: 0, forceFullQueue: true);
                                } else {
                                  final shuffled = List<ItunesTrack>.from(tracks)..shuffle();
                                  _playAppleMusicTracks(ref, context, shuffled, artworkUrl, startIndex: 0, forceFullQueue: true);
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 20),
                          
                          // Play button (large pill)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (tracks.isNotEmpty) {
                                if (localPlaylist != null) {
                                  _playLocalTracks(ref, context, tracks as List<DbPlaylistTrack>, forceFullQueue: true);
                                } else {
                                  _playAppleMusicTracks(ref, context, tracks as List<ItunesTrack>, artworkUrl, forceFullQueue: true);
                                }
                              }
                            },
                            child: Container(
                              height: 48,
                              width: 140,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Play',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white,
                                      fontWeight: FontWeight.w600,),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          
                          // Add/Save button (circle)
                           _buildCircleButton(
                            icon: localPlaylist != null ? Icons.check_rounded : Icons.add_rounded,
                            isDark: isDark,
                            iconColor: localPlaylist != null ? Colors.green : null,
                            onTap: localPlaylist != null
                                ? () { HapticFeedback.lightImpact(); } // Already saved
                                : () async {
                                    HapticFeedback.lightImpact();
                                    if (tracks.isNotEmpty) {
                                      try {
                                        final itunesTracks = tracks as List<ItunesTrack>;
                                        await ref.read(playlistProvider.notifier).importItunesTracksPlaylist(
                                          title,
                                          artworkUrl,
                                          itunesTracks,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Successfully saved "$title" to Library!'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to save playlist: $e'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Thin divider
                      Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                ),
                loading: () => SizedBox(
                  height: artSize + 160,
                  child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                ),
                error: (e, _) => SizedBox(
                  height: 200,
                  child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
                ),
              ),
            ),

            // --- Track List ---
            tracksAsync.when(
              data: (tracks) {
                final hasMoreDeezer = deezerPlaylist != null && 
                    ref.watch(deezerPlaylistTracksProvider(deezerPlaylist.id).notifier).hasMore;

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == tracks.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      }

                      final track = tracks[index];
                      if (track is DbPlaylistTrack) {
                        return _buildTrackTile(
                          index: index + 1,
                          title: track.title,
                          subtitle: track.artist,
                          imageUrl: track.artworkUrl,
                          isDark: isDark,
                          onTap: () => _playLocalTracks(ref, context, tracks as List<DbPlaylistTrack>, startIndex: index),
                          onLongPress: () => _showTrackOptions(context, ref, track),
                        );
                      } else if (track is ItunesTrack) {
                        if (appleMusicPlaylist != null && !appleMusicPlaylist.url.contains('jiosaavn.com')) {
                          ref.read(appleMusicPlaylistNotifierProvider(appleMusicPlaylist.url).notifier).enrichTrackAtIndex(index);
                        }
                        return _buildTrackTile(
                          index: index + 1,
                          title: track.trackName,
                          subtitle: track.artistName,
                          imageUrl: track.artworkUrl.isNotEmpty ? track.artworkUrl : artworkUrl,
                          isDark: isDark,
                          onTap: () => _playAppleMusicTracks(ref, context, tracks as List<ItunesTrack>, artworkUrl, startIndex: index),
                          onLongPress: () => _showTrackOptionsForItunesTrack(context, ref, track),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: tracks.length + (hasMoreDeezer ? 1 : 0),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  /// Builds a translucent circular icon button (Shuffle / Add)
  Widget _buildCircleButton({
    required IconData icon,
    required bool isDark,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// Builds an individual track tile matching the reference style
  Widget _buildTrackTile({
    required int index,
    required String title,
    required String subtitle,
    String? imageUrl,
    required bool isDark,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress != null ? () {
        HapticFeedback.mediumImpact();
        onLongPress();
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Track artwork (small rounded square)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[300]),
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          child: const Icon(Icons.music_note, size: 20, color: Colors.white38),
                        ),
                      )
                    : Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: const Icon(Icons.music_note, size: 20, color: Colors.white38),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white,
                      fontWeight: FontWeight.w500,),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.55),),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // More options
            Icon(
              Icons.more_horiz_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _playLocalTracks(WidgetRef ref, BuildContext context, List<DbPlaylistTrack> tracks, {int startIndex = 0, bool forceFullQueue = false}) async {
    final library = ref.read(libraryProvider);
    final customQueue = tracks.map((t) {
      final matched = library.findMatchingTrack(t.title, t.artist);
      return matched ?? TorBoxFile(
        id: -t.id,
        name: '${t.artist} - ${t.title}',
        size: 0,
        torrentId: -1,
      );
    }).toList().cast<TorBoxFile>();

    final file = customQueue[startIndex];
    final track = tracks[startIndex];
    
    final url = file.localPath != null 
        ? Uri.file(file.localPath!).toString() 
        : 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';
      
    await audioHandler.customAction('play', {
      'url': url,
      'title': track.title,
      'artist': track.artist,
      'artworkUrl': track.artworkUrl ?? '',
      'forceReplace': true,
      'queue': List.generate(customQueue.length, (i) {
        final e = customQueue[i];
        final tMatch = tracks[i];
        String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
        if (e.torrentId == -1) {
          fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(tMatch.title)}&artist=${Uri.encodeComponent(tMatch.artist)}';
        }
        return {
          'url': fUrl,
          'title': tMatch.title,
          'artist': tMatch.artist,
          'artworkUrl': tMatch.artworkUrl ?? '',
          'extras': {
            'torrentId': e.torrentId,
            'fileId': e.id,
            'size': e.size,
            'localPath': e.localPath,
          }
        };
      }),
      'index': startIndex,
    });

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NowPlayingScreen(
            file: file,
            customQueue: customQueue,
            initialArtwork: track.artworkUrl,
          ),
        ),
      );
    }
  }

  void _playAppleMusicTracks(WidgetRef ref, BuildContext context, List<ItunesTrack> tracks, String? playlistArtwork, {int startIndex = 0, bool forceFullQueue = false}) async {
    final library = ref.read(libraryProvider);
    // Map ItunesTrack to TorBoxFile dummy for NowPlayingScreen
    final customQueue = tracks.map((t) {
      final matched = library.findMatchingTrack(t.trackName, t.artistName);
      return matched ?? TorBoxFile(
        id: -t.trackId,
        name: '${t.artistName} - ${t.trackName}',
        size: 0,
        torrentId: -1,
      );
    }).toList().cast<TorBoxFile>();

    final file = customQueue[startIndex];
    final track = tracks[startIndex];
    final artwork = track.artworkUrl.isNotEmpty ? track.artworkUrl : playlistArtwork;

    final url = file.localPath != null 
        ? Uri.file(file.localPath!).toString() 
        : 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';
      
    await audioHandler.customAction('play', {
      'url': url,
      'title': track.trackName,
      'artist': track.artistName,
      'artworkUrl': artwork ?? '',
      'forceReplace': true,
      'queue': List.generate(customQueue.length, (i) {
        final e = customQueue[i];
        final tMatch = tracks[i];
        String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
        if (e.torrentId == -1) {
          fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(tMatch.trackName)}&artist=${Uri.encodeComponent(tMatch.artistName)}';
        }
        return {
          'url': fUrl,
          'title': tMatch.trackName,
          'artist': tMatch.artistName,
          'artworkUrl': tMatch.artworkUrl.isNotEmpty ? tMatch.artworkUrl : playlistArtwork ?? '',
          'extras': {
            'torrentId': e.torrentId,
            'fileId': e.id,
            'size': e.size,
            'localPath': e.localPath,
          }
        };
      }),
      'index': startIndex,
    });

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NowPlayingScreen(
            file: file,
            customQueue: customQueue,
            initialArtwork: artwork,
          ),
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    if (widget.localPlaylist == null) return;
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Delete Playlist?', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to delete "${widget.localPlaylist!.name}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(playlistProvider.notifier).deletePlaylist(widget.localPlaylist!.id);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to playlists screen
              },
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, WidgetRef ref, DbPlaylistTrack track) {
    final library = ref.read(libraryProvider);
    final matchingFile = library.findMatchingTrack(track.title, track.artist);
    
    // Convert DbPlaylistTrack to ItunesTrack for the unified sheet
    final itunesTrack = ItunesTrack(
      trackId: track.id,
      trackName: track.title,
      artistName: track.artist,
      collectionName: track.album ?? '',
      artworkUrl: track.artworkUrl ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrackActionSheet(
        track: itunesTrack,
        libraryFile: matchingFile,
        playlistTrackId: track.id,
      ),
    );
  }

  void _showTrackOptionsForItunesTrack(BuildContext context, WidgetRef ref, ItunesTrack track) {
    final library = ref.read(libraryProvider);
    final matchingFile = library.findMatchingTrack(track.trackName, track.artistName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrackActionSheet(
        track: track,
        libraryFile: matchingFile,
      ),
    );
  }
}
