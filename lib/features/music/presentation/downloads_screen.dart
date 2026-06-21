import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'music_providers.dart';
import '../data/itunes_metadata_service.dart';
import '../data/music_models.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import 'now_playing_screen.dart';
import 'track_action_sheet.dart';
import 'music_search_screen.dart'; // for parsing

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final downloadedFiles = library.allAudioFiles.where((f) {
      return ref.read(libraryProvider.notifier).isDownloaded(f);
    }).toList();

    int totalMillis = 0;
    for (final file in downloadedFiles) {
      final meta = library.metadata['${file.torrentId}-${file.id}'];
      if (meta?.trackTimeMillis != null) {
        totalMillis = totalMillis + meta!.trackTimeMillis!.toInt();
      }
    }

    final totalDuration = Duration(milliseconds: totalMillis);
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final durationString = hours > 0 
        ? '${hours}h ${minutes}m' 
        : '${minutes}m';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Offline Songs',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
              ),
            ),
            if (downloadedFiles.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.library_music_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${downloadedFiles.length} Songs',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,),
                            ),
                            Text(
                              'Total runtime: $durationString',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white60 : Colors.black54,),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (downloadedFiles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No offline songs found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final file = downloadedFiles[index];
                    final meta = library.metadata['${file.torrentId}-${file.id}'];
                    
                    return _DownloadTrackTile(
                      file: file, 
                      queue: downloadedFiles,
                      meta: meta,
                    );
                  },
                  childCount: downloadedFiles.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _DownloadTrackTile extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final List<TorBoxFile> queue;
  final ItunesMeta? meta;

  const _DownloadTrackTile({
    required this.file,
    required this.queue,
    this.meta,
  });

  @override
  ConsumerState<_DownloadTrackTile> createState() => _DownloadTrackTileState();
}

class _DownloadTrackTileState extends ConsumerState<_DownloadTrackTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).enrichTrack(widget.file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = widget.meta;
    final parsed = _parseFilename(widget.file.displayName);
    
    return AppleMusicListTile(
      title: meta?.trackName ?? parsed.title,
      subtitle: meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox'),
      imageUrl: meta?.artworkUrlLow,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (meta?.trackTimeMillis != null)
            Text(
              ItunesTrack.formatDuration(meta!.trackTimeMillis),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white30 : Colors.black26,),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white30 : Colors.black26,
            size: 20,
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: widget.file,
              customQueue: widget.queue,
            ),
          ),
        );
      },
      onLongPress: () {
        final parsed = _parseFilename(widget.file.displayName);
        final itunesTrack = ItunesTrack(
          trackId: widget.file.id,
          trackName: widget.meta?.trackName ?? parsed.title,
          artistName: widget.meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox'),
          collectionName: widget.meta?.album ?? 'TorBox',
          artworkUrl: widget.meta?.artworkUrlHigh ?? widget.meta?.artworkUrlLow ?? '',
        );

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TrackActionSheet(
            track: itunesTrack,
            libraryFile: widget.file,
          ),
        );
      },
    );
  }
}

// Reuse from library_screen.dart (should be moved to utils)
({String title, String artist}) _parseFilename(String displayName) {
  var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
  name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');
  final match = RegExp(r' [-–] ').firstMatch(name);
  if (match != null) {
    return (
      artist: name.substring(0, match.start).trim(),
      title: name.substring(match.end).trim(),
    );
  }
  return (title: name.trim(), artist: '');
}
