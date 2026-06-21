import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:isai/core/utils/string_utils.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../data/music_models.dart';
import '../data/itunes_metadata_service.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';
import 'torrent_picker_sheet.dart';
import 'package:isai/main.dart';

/// A bottom sheet that shows all available playback sources for a given iTunes track:
///  - Library matches (already in TorBox)
///  - External streaming sources (scraped FLAC / Tidal results)
///  - Option to add via Apibay torrent search
class SourcePickerSheet extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final ItunesTrack? albumContext;
  final List<TorBoxFile>? albumQueue;
  final bool forceReplace;

  const SourcePickerSheet({
    super.key,
    required this.track,
    this.albumContext,
    this.albumQueue,
    this.forceReplace = false,
  });

  @override
  ConsumerState<SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends ConsumerState<SourcePickerSheet> {
  List<TorBoxFile> _libraryMatches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    // 1. Find library matches
    final libraryResults = ref.read(libraryProvider.notifier)
        .findMatches(widget.track.trackName, widget.track.artistName);

    // 2. Start scraper search
    final cleanT = StringUtils.unescapeHtml(widget.track.trackName);
    final cleanA = StringUtils.unescapeHtml(widget.track.artistName);
    final query = '$cleanA $cleanT'.trim();
    ref.read(flacSearchProvider.notifier).search(query, force: force);

    if (mounted) {
      setState(() {
        _libraryMatches = libraryResults;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flacState = ref.watch(flacSearchProvider);
    final isSearching = flacState.isLoading;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E), // Always dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Source',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white,
                          fontWeight: FontWeight.bold,),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${StringUtils.unescapeHtml(widget.track.trackName)} · ${StringUtils.unescapeHtml(widget.track.artistName)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54,),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSearching)
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white54,
                        size: 20),
                    onPressed: () => _fetchSources(force: true),
                  ),
              ],
            ),
          ),
          // Source filter chips
          if (flacState.results.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  AppleMusicChip(
                    label: 'All',
                    isSelected: flacState.selectedSource == 'All' ||
                        flacState.selectedSource == null,
                    isDarkOverride: true,
                    onTap: () =>
                        ref.read(flacSearchProvider.notifier).setSource('All'),
                  ),
                  ...flacState.availableSources.map((source) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: AppleMusicChip(
                          label: source,
                          isSelected: flacState.selectedSource == source,
                          isDarkOverride: true,
                          onTap: () => ref
                              .read(flacSearchProvider.notifier)
                              .setSource(source),
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Content list
          Expanded(
            child: ListView(
              children: [
                // Library section
                if (_libraryMatches.isNotEmpty) ...[
                  _sectionHeader('YOUR LIBRARY'),
                  ..._libraryMatches.map(_buildLibraryTile),
                ],
                // Streaming section
                if (flacState.filteredResults.isNotEmpty) ...[
                  _sectionHeader('STREAMING'),
                  ...flacState.filteredResults.map(_buildStreamTile),
                ],
                // Empty streaming state
                if (!isSearching &&
                    _libraryMatches.isEmpty &&
                    flacState.filteredResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No direct streams found',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                // Torrent option
                _buildTorrentOption(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,),
      ),
    );
  }

  Widget _buildLibraryTile(TorBoxFile file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta =
        ref.read(libraryProvider).metadata['${file.torrentId}-${file.id}'];
    final parsed = _parseFilename(file.displayName);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white12
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.library_music,
            color: Theme.of(context).colorScheme.primary, size: 22),
      ),
      title: Text(
        StringUtils.unescapeHtml(meta?.trackName ?? parsed.title),
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_limitArtists(meta?.artistName ?? parsed.artist)} · Library · ${file.formattedSize}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,),
      ),
      trailing: Icon(Icons.play_circle_filled_rounded,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 28),
      onTap: () => _playLibraryTrack(file, meta),
    );
  }

  Widget _buildStreamTile(ScraperResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      isThreeLine: true,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: result.thumbnail != null
            ? CachedNetworkImage(
                imageUrl: result.thumbnail!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _streamPlaceholder(isDark),
              )
            : _streamPlaceholder(isDark),
      ),
      title: Text(
        StringUtils.unescapeHtml(result.title),
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.artist.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              StringUtils.unescapeHtml(_limitArtists(result.artist)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _SourceBadge(source: result.source),
              const SizedBox(width: 6),
              Text(
                result.format,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.play_circle_filled_rounded,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 28),
      onTap: () => _playStream(result),
    );
  }

  Widget _buildTorrentOption(bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TorrentPickerSheet(track: widget.track),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_download_outlined,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add via Torrent (Apibay)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white,
                      fontWeight: FontWeight.w500,),
                  ),
                  Text(
                    'Search and download to your TorBox library',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _streamPlaceholder(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
      child: Icon(Icons.music_note,
          color: isDark ? Colors.white38 : Colors.black38, size: 20),
    );
  }

  Future<void> _playLibraryTrack(TorBoxFile file, ItunesMeta? meta) async {
    Navigator.pop(context);
    if (meta != null) {
      await ref.read(libraryProvider.notifier).updateTrackMetadata(file, meta);
    }
    
    final trackUrl = file.localPath != null 
        ? Uri.file(file.localPath!).toString() 
        : 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';

    final highResArtwork = widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000');
    final initialArtwork = meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? highResArtwork;
    
    await audioHandler.customAction('play', {
      'url': trackUrl,
      'title': widget.track.trackName,
      'artist': widget.track.artistName,
      'artworkUrl': initialArtwork,
      'forceReplace': widget.forceReplace,
      'queue': (widget.albumQueue != null && widget.forceReplace) ? widget.albumQueue!.map((e) {
          final isLibrary = file.torrentId != -1;
          String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
          if (e.torrentId == -1) {
            fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(e.name)}&artist=${Uri.encodeComponent(widget.track.artistName)}';
          }
          return {
            'url': fUrl,
            'title': e.name,
            'artist': widget.track.artistName,
            'artworkUrl': widget.track.artworkUrl,
            'extras': {
              'torrentId': e.torrentId,
              'fileId': e.id,
              'size': e.size,
            }
          };
      }).toList() : null,
      'index': widget.albumQueue?.indexOf(file) ?? 0,
      'extras': {
        'torrentId': file.torrentId,
        'fileId': file.id,
        'size': file.size,
        'localPath': file.localPath,
      },
    });

    if (!mounted) return;

    final playbackState = audioHandler.playbackState.value;
    if (playbackState.playing && !widget.forceReplace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to Next in Queue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          file: file,
          customQueue: widget.albumQueue ?? [file],
          initialArtwork: initialArtwork,
        ),
      ),
    );
  }

  Future<void> _playStream(ScraperResult result) async {
    Navigator.pop(context);
    final dummyFile = TorBoxFile(
      id: -result.url.hashCode.abs(),
      torrentId: -1,
      size: result.size,
      name: result.title,
      localPath: null,
    );

    await audioHandler.customAction('play', {
      'url': result.url,
      'title': widget.track.trackName,
      'artist': widget.track.artistName,
      'artworkUrl': widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
      'forceReplace': widget.forceReplace,
      'extras': {
        'torrentId': dummyFile.torrentId,
        'fileId': dummyFile.id,
        'size': result.size,
        'localPath': null,
        'source': result.source,
        'linkType': result.linkType,
        'format': result.format,
      },
    });

    if (!mounted) return;

    final playbackState = audioHandler.playbackState.value;
    if (playbackState.playing && !widget.forceReplace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to Next in Queue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          file: dummyFile,
          customQueue: widget.albumQueue ?? [dummyFile],
          initialArtwork: widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        ),
      ),
    );
  }

  ({String title, String artist}) _parseFilename(String displayName) {
    var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
    name = name.replaceAll(RegExp(r'^\d+\s*[-.]?\s*'), '');
    final match = RegExp(r' [-–] ').firstMatch(name);
    if (match != null) {
      return (
        artist: name.substring(0, match.start).trim(),
        title: name.substring(match.end).trim(),
      );
    }
    return (artist: 'Unknown', title: name);
  }

  String _limitArtists(String artist) {
    if (artist.isEmpty) return artist;
    final parts = artist.split(RegExp(r'\s*(?:,|\s+&\s+|\s+and\s+)\s*'));
    if (parts.length > 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return artist;
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (source.toLowerCase()) {
      case 'tidal':
        color = Colors.tealAccent;
        break;
      case 'qobuz':
        color = Colors.blueAccent;
        break;
      case 'youtube':
      case 'yt':
        color = Colors.redAccent;
        break;
      case 'jiosaavn':
        color = Colors.lightGreenAccent;
        break;
      default:
        color = Theme.of(context).colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        source.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,),
      ),
    );
  }
}
