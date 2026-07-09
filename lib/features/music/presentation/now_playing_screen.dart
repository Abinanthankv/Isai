import 'dart:ui';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isai/main.dart';
import 'music_providers.dart';
import 'player_visuals.dart';
import 'share_card_widget.dart';
import '../../music/data/music_models.dart';
import '../../music/data/music_repository.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/di/injection.dart';
import 'package:isai/core/database/database.dart';
import '../data/lastfm_service.dart';
import '../data/deezer_service.dart';
import 'artist_screen.dart';
import 'album_screen.dart';
import 'torrent_picker_sheet.dart';
import 'package:isai/core/theme/apple_music_components.dart';
import '../data/itunes_metadata_service.dart';
import 'package:isai/features/player/presentation/player_providers.dart';
import 'package:isai/features/settings/presentation/settings_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'lyrics_provider.dart';
import '../data/lyrics_models.dart';
import 'metadata_picker_sheet.dart';
import 'playlist_picker_sheet.dart';
import 'playlist_providers.dart';
import '../../player/data/audio_handler.dart';
import 'visualizer_layer.dart';
import 'visualizer_settings_sheet.dart';
import 'package:isai/core/theme/material3_theme.dart';
import 'package:isai/core/theme/dynamic_color_provider.dart';
import 'spotify_canvas_provider.dart';
import 'interactive_controls.dart';


class NowPlayingScreen extends ConsumerWidget {
  final TorBoxFile file;
  final List<TorBoxFile>? customQueue;
  final String? initialArtwork;

  const NowPlayingScreen({
    super.key,
    required this.file,
    this.customQueue,
    this.initialArtwork,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isM3 = settings.appThemeStyle == 'material3';

    ThemeData themeData;
    if (isM3) {
      final dynamicColors = ref.watch(dynamicColorProvider);
      themeData = Material3Theme.darkThemeFromScheme(dynamicColors.darkScheme);
    } else {
      themeData = AppleMusicTheme.darkTheme();
    }

    return Theme(
      data: themeData,
      child: NowPlayingContent(
        file: file,
        customQueue: customQueue,
        initialArtwork: initialArtwork,
      ),
    );
  }
}

class NowPlayingContent extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final List<TorBoxFile>? customQueue;
  final String? initialArtwork;

  const NowPlayingContent({
    super.key,
    required this.file,
    this.customQueue,
    this.initialArtwork,
  });

  @override
  ConsumerState<NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends ConsumerState<NowPlayingContent>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  // late AnimationController _vinylController; // Removed: art is now static
  double _volume = 1.0;
  ProviderSubscription? _metadataSubscription;
  bool _showLyrics = false;
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricIndex = -1;
  StreamSubscription<MediaItem?>? _mediaSubscription;
  String? _currentTrackKey;

  // Sleep timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  bool _sleepAtEndOfTrack = false;
  String? _sleepTimerTrackId;
  Duration _lyricsOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    /* _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    ); */
    _loadAndPlay();
    // Only enrich library tracks (torrentId != -1) — virtual/scraper tracks already have
    // correct title/artist/artwork from the play action and don't need iTunes enrichment.
    if (widget.file.torrentId != -1) {
      final existingMeta = ref.read(libraryProvider).metadata['${widget.file.torrentId}-${widget.file.id}'];
      final hasArtwork = existingMeta?.artworkUrlHigh != null && existingMeta!.artworkUrlHigh!.isNotEmpty;
      if (existingMeta == null || !hasArtwork || (existingMeta.genre == null && existingMeta.album == null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(libraryProvider.notifier).enrichTrack(widget.file);
          }
        });
      }
    }
    
    // Listen for metadata changes to update audio handler if needed
    _metadataSubscription = ref.listenManual(libraryProvider.select((s) => s.metadata), (prev, next) async {
      if (!mounted) return;
      final currentMedia = audioHandler.mediaItem.value;
      if (currentMedia == null) return;
      final fileId = (currentMedia.extras?['fileId'] as num?)?.toInt();
      final torrentId = (currentMedia.extras?['torrentId'] as num?)?.toInt();
      if (fileId == null || torrentId == null) return;
      
      final updatedMeta = next['$torrentId-$fileId'];
      if (updatedMeta != null) {
        // Metadata for the current track was updated (e.g., Fix Metadata was used)
        // Broadcast the full update to audioHandler so artwork + genre are live
        final artwork = (updatedMeta.artworkUrlHigh?.isNotEmpty == true) 
            ? Uri.parse(updatedMeta.artworkUrlHigh!)
            : (updatedMeta.artworkUrlLow?.isNotEmpty == true)
                ? Uri.parse(updatedMeta.artworkUrlLow!)
                : currentMedia.artUri;
        final updated = currentMedia.copyWith(
          title: updatedMeta.trackName ?? currentMedia.title,
          artist: updatedMeta.artistName ?? currentMedia.artist,
          album: updatedMeta.album ?? currentMedia.album,
          artUri: artwork,
          extras: {
            ...currentMedia.extras ?? {},
            if (updatedMeta.genre != null) 'genre': updatedMeta.genre,
          },
        );
        if (audioHandler is MyAudioHandler) {
          await (audioHandler as MyAudioHandler).broadcastMetadata(updated);
        }
      }
    });
    
    // Listen for track changes to: (a) fetch lyrics, (b) enrich library metadata for new track
    _mediaSubscription = audioHandler.mediaItem.listen((item) {
      if (item != null && mounted) {
        final title = item.title;
        final artist = item.artist ?? '';
        final trackKey = '${title}_$artist';
        
        if (trackKey == _currentTrackKey) {
          return;
        }
        _currentTrackKey = trackKey;

        if (_sleepAtEndOfTrack && _sleepTimerTrackId != null && item.id != _sleepTimerTrackId) {
          _sleepAtEndOfTrack = false;
          _sleepTimerTrackId = null;
          audioHandler.pause();
          setState(() {});
          return;
        }
        Future.microtask(() {
          if (!mounted) return;
          // Fetch lyrics for the new track
          ref.read(lyricsProvider.notifier).fetchLyrics(
            title, 
            artist, 
            durationMs: item.duration?.inMilliseconds,
          );

          // Fetch Canvas for the new track
          ref.read(spotifyCanvasProvider.notifier).fetchCanvas(title, artist);

          // Proactively enrich library metadata for this track if not already loaded
          final fileId = (item.extras?['fileId'] as num?)?.toInt();
          final torrentId = (item.extras?['torrentId'] as num?)?.toInt();
          if (fileId != null && torrentId != null && torrentId > 0) {
            final key = '$torrentId-$fileId';
            final alreadyLoaded = ref.read(libraryProvider).metadata.containsKey(key);
            if (!alreadyLoaded) {
              // Find the TorBoxFile and enrich it
              final library = ref.read(libraryProvider);
              final file = library.allAudioFiles.where((f) => f.id == fileId && f.torrentId == torrentId).firstOrNull;
              if (file != null) {
                ref.read(libraryProvider.notifier).enrichTrack(file);
              }
            }
          }
        });
      }
    });

    // Track that player is open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('[NowPlayingScreen] initState: setting isPlayerOpen=true');
        ref.read(isPlayerOpenProvider.notifier).setOpen(true);
      }
    });
  }

  // Removed deactivate() to prevent "Looking up a deactivated widget's ancestor is unsafe" crash.
  // The state (lyrics/canvas) should persist anyway so we don't have to re-fetch if the user re-opens the screen for the same track.
  @override
  void dispose() {
    print('[NowPlayingScreen] dispose started');
    // _vinylController.dispose();
    _lyricsScrollController.dispose();
    _mediaSubscription?.cancel();
    _sleepTimer?.cancel();
    _metadataSubscription?.close();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    final library = ref.read(libraryProvider);
    final currentMedia = audioHandler.mediaItem.value;
    
    // If this track is already active in the player, return early.
    if (currentMedia != null && (
        currentMedia.extras?['fileId'] == widget.file.id && 
        currentMedia.extras?['torrentId'] == widget.file.torrentId
    )) {
      print('[NowPlayingScreen] Already active, returning early.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Priority 1: Check if song exists in library (only if not already playing)
    TorBoxFile activeFile = widget.file;
    if (activeFile.torrentId == -1) {
      final parsed = parseFilename(activeFile.displayName);
      final matched = library.findMatchingTrack(parsed.title, parsed.artist);
      if (matched != null) {
        // Re-check with matched file
        if (currentMedia != null &&
            currentMedia.extras?['fileId'] == matched.id &&
            currentMedia.extras?['torrentId'] == matched.torrentId) {
          print('[NowPlayingScreen] Already active (matched library track), returning early.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        print('[NowPlayingScreen] Virtual track matched with library: ${matched.displayName}');
        activeFile = matched;
      }
    }

    // Check again with the (possibly matched) activeFile
    final isAlreadyActive = currentMedia != null && (
        currentMedia.extras?['fileId'] == activeFile.id && 
        currentMedia.extras?['torrentId'] == activeFile.torrentId
    );

    if (!mounted) return;
    setState(() {
      _isLoading = !isAlreadyActive; 
      _error = null;
    });

    if (isAlreadyActive) {
       print('[NowPlayingScreen] Already active, returning early.');
       return;
    }

    String? url;
    String? resolvedFormat;
    Map<String, dynamic>? extraMetadata;

    try {
      // Use custom queue if provided, otherwise fall back to library
      final allFiles = widget.customQueue ?? library.allAudioFiles;
      int currentIndex = -1;

    // Moved logic above for isAlreadyActive check

        // 1. Check for local persistent download first
        final isDownloaded = ref.read(libraryProvider.notifier).isDownloaded(activeFile);
        String? url;
        String? localPath;
        
        if (isDownloaded) {
          final torrent = library.torrents.where((t) => t.id == activeFile.torrentId).firstOrNull;
          final file = torrent?.files.where((f) => f.id == activeFile.id).firstOrNull;
          localPath = file?.localPath ?? activeFile.localPath;
          if (localPath != null) {
            url = Uri.file(localPath).toString();
          }
        }
  
        // 2. Fetch stream URL ONLY if not downloaded
        if (url == null) {
          final connectivity = await ref.read(connectivityProvider.future);
          if (!mounted) return;
          final isOffline = connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty;
          
          if (isOffline) {
            setState(() {
              _isLoading = false;
              _error = 'Network unavailable. This track is not downloaded.';
            });
            return;
          }
  
          // If we are here, we are online and the track is not downloaded.
          // We need to get a stream URL.
          final meta = library.metadata['${activeFile.torrentId}-${activeFile.id}'];
          if (activeFile.torrentId == -1) {
            // Trigger background fetch for sources
            final parsed = parseFilename(activeFile.displayName);
            final query = meta != null 
                ? '${meta.artistName} ${meta.trackName}'.trim()
                : '${parsed.artist} ${parsed.title}'.trim();
                
            final repo = getIt<MusicRepository>();
            final trackTitle = meta?.trackName ?? parsed.title;
            final trackArtist = meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'Unknown Artist');

            print('[NowPlayingScreen] Starting concurrent FLAC + YouTube + SoundCloud resolution for $query');
            
            // Start FLAC, SoundCloud, and YouTube searches concurrently
            final flacFuture = ref.read(flacSearchProvider.notifier).resolveDirectFlac(trackTitle, trackArtist);
            
            final enableYT = ref.read(settingsProvider).enableYouTubeScraper;
            final ytFuture = enableYT 
                ? repo.searchYouTube(query).then((results) {
                    if (results.isNotEmpty) {
                      final yt = results.first;
                      return ScraperResult(
                        title: yt.title,
                        artist: yt.author,
                        url: 'https://www.youtube.com/watch?v=${yt.id}',
                        size: 0,
                        format: 'YouTube',
                        source: 'YouTube',
                        linkType: 'youtube',
                      );
                    }
                    return null;
                  }).catchError((e) {
                    print('[NowPlayingScreen] YouTube search failed: $e');
                    return null;
                  })
                : Future<ScraperResult?>.value(null);

            // Wait for all, prefer FLAC then YouTube
            final results = await Future.wait([flacFuture, ytFuture]);
            final flacResult = results[0];
            final ytResult = results[1];
            
            ScraperResult? finalResult = flacResult ?? ytResult;
            if (flacResult != null) {
              print('[NowPlayingScreen] Using FLAC source: ${flacResult.title}');
            } else if (ytResult != null) {
              print('[NowPlayingScreen] Using YouTube fallback: ${ytResult.title}');
            }

            if (finalResult != null) {
               url = finalResult.url;
               resolvedFormat = finalResult.format;
               extraMetadata = {
                 if (finalResult.linkType != null) 'linkType': finalResult.linkType,
                 ...?finalResult.extras,
               };
            }


          } else {
            try {
              url = await getIt<MusicRepository>().getStreamUrl(
                activeFile.torrentId,
                activeFile.id,
              );
            if (!mounted) return;
          } catch (e) {
            // Handle error if stream URL cannot be fetched
            print('Error fetching stream URL: $e');
            // If we have a queue, try to skip this one and move to next
            if (widget.customQueue != null || library.allAudioFiles.isNotEmpty) {
              _skipToNextInQueue(activeFile);
              return;
            }
            
            setState(() {
              _isLoading = false;
              _error = 'Could not get stream URL: ${e.toString()}';
            });
            return;
          }
        }
      }

      if (url == null) {
        // If we have a queue, try to skip this one and move to next
        if (widget.customQueue != null || library.allAudioFiles.isNotEmpty) {
          _skipToNextInQueue(activeFile);
          return;
        }

        setState(() {
          _isLoading = false;
          _error = 'Could not get stream URL';
        });
        return;
      }

      // Build the queue data for customAction
      final queueItems = <Map<String, dynamic>>[];
      
      currentIndex = allFiles.indexWhere((f) => f.id == activeFile.id && f.torrentId == activeFile.torrentId);
      
      // If the file isn't in the list (shouldn't happen with customQueue), 
      // just start at 0 and use the current files
      final filesToQueue = currentIndex != -1 ? allFiles : [activeFile];
      if (currentIndex == -1) currentIndex = 0;

      for (int i = 0; i < filesToQueue.length; i++) {
        final file = filesToQueue[i];
        
        final meta = library.metadata['${file.torrentId}-${file.id}'];
        final parsed = parseFilename(file.displayName);
        
        // Note: We don't have all stream URLs yet, but we'll fetch them on-demand in the handler
        // OR we can pass a special 'lazy' URL. 
        // For now, if it's the current file, use the URL we just fetched.
        String fileUrl = url!;
        if (file.id != activeFile.id || file.torrentId != activeFile.torrentId) {
          if (file.torrentId == -1) {
            final trackTitle = meta?.trackName ?? parsed.title;
            final artistName = meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox');
            fileUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(trackTitle)}&artist=${Uri.encodeComponent(artistName)}';
          } else {
            fileUrl = 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';
          }
        }

        final artwork = (meta?.artworkUrlHigh != null && meta!.artworkUrlHigh!.isNotEmpty) 
            ? meta.artworkUrlHigh 
            : (meta?.artworkUrlLow != null && meta!.artworkUrlLow!.isNotEmpty) 
                ? meta.artworkUrlLow 
                : (file.id == widget.file.id ? widget.initialArtwork : null) ?? '';

        queueItems.add({
          'url': fileUrl,
          'title': meta?.trackName ?? parsed.title,
          'artist': meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox'),
          'artworkUrl': artwork,
          'duration': meta?.trackTimeMillis?.toString(),
          'extras': {
            'torrentId': file.torrentId,
            'fileId': file.id,
            'size': file.size,
            'localPath': file.localPath,
          },
        });
      }

      final currentMeta = library.metadata['${activeFile.torrentId}-${activeFile.id}'];
      final currentParsed = parseFilename(activeFile.displayName);

      final currentQueue = audioHandler.queue.value;
      bool inQueue = currentQueue.any((item) => 
        item.extras?['fileId'] == activeFile.id && 
        item.extras?['torrentId'] == activeFile.torrentId
      );

      final playArgs = <String, dynamic>{
        'url': url,
        'title': currentMeta?.trackName ?? currentParsed.title,
        'artist': currentMeta?.artistName ?? (currentParsed.artist.isNotEmpty ? currentParsed.artist : 'TorBox'),
        'artworkUrl': currentMeta?.artworkUrlHigh ?? currentMeta?.artworkUrlLow ?? widget.initialArtwork ?? '',
        'duration': currentMeta?.trackTimeMillis?.toString(),
        'index': currentIndex >= 0 ? currentIndex : 0,
        'extras': {
          'torrentId': activeFile.torrentId,
          'fileId': activeFile.id,
          'size': activeFile.size,
          'localPath': localPath,
          if (resolvedFormat != null) 'format': resolvedFormat,
          if (extraMetadata != null) ...extraMetadata,
        },
      };

      // Only provide the queue if it's explicitly non-trivial (like an album) 
      // OR if we don't have a queue yet.
      // This prevents wiping a rich queue when just playing a single song.
      if (!inQueue || (widget.customQueue != null && widget.customQueue!.length > 1)) {
        playArgs['queue'] = queueItems;
      } else {
        print('[NowPlayingScreen] Track already in queue, avoiding queue reset');
      }

      await audioHandler.customAction('play', playArgs);
      if (!mounted) return;

      setState(() => _isLoading = false);
    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = msg.contains('not ready') || msg.contains('download')
            ? '⏳ File not ready yet on TorBox.\nPlease wait and try again.'
            : msg;
      });
    }
  }

  void _skipToNextInQueue(TorBoxFile failedFile) {
    if (!mounted) return;
    
    final library = ref.read(libraryProvider);
    final allFiles = widget.customQueue ?? library.allAudioFiles;
    
    final currentIndex = allFiles.indexWhere((f) => 
      f.id == failedFile.id && f.torrentId == failedFile.torrentId
    );
    
    if (currentIndex != -1 && currentIndex < allFiles.length - 1) {
      final nextFile = allFiles[currentIndex + 1];
      print('[NowPlayingScreen] Skipping failed track, moving to next: ${nextFile.displayName}');
      
      // We can't easily "replace" the widget.file, but we can restart _loadAndPlay with a different "activeFile" logic
      // However, it's better to just navigate to a NEW NowPlayingScreen or update state.
      // For now, let's just trigger another _loadAndPlay after updating a local "currentFile" if we had one.
      // But Since NowPlayingScreen depends on widget.file, it's tricky.
      
      // Best approach: If we are already in the player, just use audioHandler.skipToNext().
      // If we are just starting, we can try to play the next one.
      
      final currentMedia = audioHandler.mediaItem.value;
      if (currentMedia != null) {
        audioHandler.skipToNext();
        setState(() => _isLoading = false);
      } else {
        // If nothing is playing yet, we need to initialize with the next one
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NowPlayingScreen(
              file: nextFile,
              customQueue: widget.customQueue,
              initialArtwork: widget.initialArtwork,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Could not get stream URL and no more tracks in queue.';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    ref.listen(libraryProvider.select((s) => s.downloadError), (previous, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ),
        );
      }
    });

    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    
    // Priority Match check for build method as well
    TorBoxFile activeFile = widget.file;
    if (activeFile.torrentId == -1) {
      final parsed = parseFilename(activeFile.displayName);
      final matched = library.findMatchingTrack(parsed.title, parsed.artist);
      if (matched != null) activeFile = matched;
    }

    final meta = library.metadata['${activeFile.torrentId}-${activeFile.id}'];
    final parsed = parseFilename(activeFile.displayName);
    final isM3 = settings.appThemeStyle == 'material3';

    final widgetTree = Scaffold(
        backgroundColor: Colors.black,
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        initialData: audioHandler.mediaItem.value,
        builder: (context, snapshot) {
          final currentMediaItem = snapshot.data;
          final settings = ref.watch(settingsProvider);
          final canvasState = ref.watch(spotifyCanvasProvider);
          final showCanvas = settings.playerSpotifyCanvasEnabled && canvasState.canvasUrl != null;

          // 1. Identify the active file (either from the stream or the widget if starting)
          // Use safe num -> int conversion to avoid issues with double/int JSON serialization
          final activeFileId = ((currentMediaItem?.extras?['fileId'] as num?)?.toInt()) ?? widget.file.id;
          final activeTorrentId = ((currentMediaItem?.extras?['torrentId'] as num?)?.toInt()) ?? widget.file.torrentId;
          
          // 2. Look up centralized metadata for the active track
          final activeMeta = library.metadata['$activeTorrentId-$activeFileId'];
          
          // 3. Prepare display data with high priority for LibraryNotifier metadata
          // (Since it might have been manually injected from Search or enriched)
          final displayTitle = activeMeta?.trackName 
              ?? currentMediaItem?.title 
              ?? (activeFileId == widget.file.id ? parsed.title : 'Loading...');
              
          final displayArtist = activeMeta?.artistName 
              ?? currentMediaItem?.artist 
              ?? (activeFileId == widget.file.id ? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox') : '');
              
          final displayArtwork = ((activeMeta?.artworkUrlHigh != null && activeMeta!.artworkUrlHigh!.isNotEmpty) 
              ? activeMeta!.artworkUrlHigh 
              : (activeMeta?.artworkUrlLow != null && activeMeta!.artworkUrlLow!.isNotEmpty) 
                  ? activeMeta!.artworkUrlLow 
                  : (currentMediaItem?.artUri?.toString() != null && currentMediaItem!.artUri!.toString().isNotEmpty) 
                      ? currentMediaItem!.artUri!.toString() 
                      : '')!;
              
          final hasArtwork = displayArtwork.isNotEmpty;

          return Stack(
            children: [
              // ── Background ─────────────────────────────────────────────
              if (settings.playerBackgroundType == 'amoled')
                Positioned.fill(child: Container(color: Colors.black))
              else if (settings.playerBackgroundType == 'gradient')
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          isM3 ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15) : AppleMusicTheme.primaryPurple.withValues(alpha: 0.15),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Default: Blurred background
                if (hasArtwork)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: displayArtwork!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) {
                         print('[NowPlayingScreen] Error loading blurred background image: $error, url: $url');
                         return Container(color: const Color(0xFF1A1A2E));
                       },
                    ),
                  ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(color: Colors.black.withValues(alpha: 0.55)),
                  ),
                ),
              ],

              if (showCanvas) ...[
                SpotifyCanvasBackground(videoUrl: canvasState.canvasUrl!),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],

              // ── Visualizer Overlay ───────────────────────────────────────
              VisualizerOverlay(
                albumArtColor: hasArtwork ? Theme.of(context).colorScheme.primary : null,
              ),

              // ── Main content ────────────────────────────────────────────
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 720;
                    if (isWideScreen) {
                      return Row(
                        children: [
                          // Left side: Album Art
                          Expanded(
                            flex: 5,
                            child: showCanvas 
                                ? const SizedBox() 
                                : _buildAlbumArt(hasArtwork, displayArtwork),
                          ),
                          // Right side: Header, Lyrics / Controls
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildHeader(context),
                                if (_showLyrics) ...[
                                  Expanded(
                                    child: _buildLyricsContent(),
                                  ),
                                  StreamBuilder<PlaybackState>(
                                    stream: audioHandler.playbackState,
                                    builder: (context, snapshot) {
                                      final playing = snapshot.data?.playing ?? false;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    displayTitle,
                                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white,
                                                      fontWeight: FontWeight.bold,),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    displayArtist,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70,),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                                              iconSize: 28,
                                              onPressed: () {
                                                HapticFeedback.mediumImpact();
                                                audioHandler.skipToPrevious();
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                                              iconSize: 32,
                                              onPressed: () {
                                                HapticFeedback.mediumImpact();
                                                if (playing) {
                                                  audioHandler.pause();
                                                } else {
                                                  audioHandler.play();
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                                              iconSize: 28,
                                              onPressed: () {
                                                HapticFeedback.mediumImpact();
                                                audioHandler.skipToNext();
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ] else ...[
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 28),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildTrackInfo(displayTitle, displayArtist),
                                                const SizedBox(height: 16),
                                                StreamBuilder<PlaybackState>(
                                                  stream: audioHandler.playbackState,
                                                  builder: (context, stateSnap) {
                                                    if (_error != null) {
                                                      return _buildError();
                                                    }
                                                    return Column(
                                                      children: [
                                                        _buildSeekBar(),
                                                        const SizedBox(height: 12),
                                                        _buildTransportControls(),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (settings.playerControlLayout != 'minimalist') ...[
                                            const SizedBox(height: 16),
                                            _buildBottomBar(),
                                          ] else ...[
                                            _buildBottomBar(),
                                            const SizedBox(height: 16),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    
                    // Portrait Mobile Layout (original)
                    if (_showLyrics) {
                      return _buildLyricsToggledLayout(
                        hasArtwork,
                        displayArtwork,
                        displayTitle,
                        displayArtist,
                        settings,
                        isM3,
                      );
                    }

                    return Column(
                      children: [
                        // Drag handle + header
                        _buildHeader(context),

                        const SizedBox(height: 12),

                        // Album art (vinyl-style spinning)
                        Expanded(
                          child: showCanvas ? const SizedBox() : _buildAlbumArt(hasArtwork, displayArtwork),
                        ),

                        const SizedBox(height: 32),

                        // Track info + controls
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               _buildTrackInfo(displayTitle, displayArtist),
                               const SizedBox(height: 20),
                               StreamBuilder<PlaybackState>(
                                 stream: audioHandler.playbackState,
                                 builder: (context, stateSnap) {
                                   if (_error != null) {
                                     return _buildError();
                                   }

                                   return Column(
                                     children: [
                                       _buildSeekBar(),
                                       const SizedBox(height: 16),
                                       _buildTransportControls(),
                                     ],
                                   );
                                 },
                               ),
                             ],
                           ),
                         ),

                         if (settings.playerControlLayout != 'minimalist') ...[
                           const SizedBox(height: 24),
                           // Bottom icons
                           _buildBottomBar(),
                         ] else ...[
                           _buildBottomBar(),
                           const SizedBox(height: 24),
                         ],
                       ],
                     );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );

    return widgetTree;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text('NOW PLAYING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54, letterSpacing: 1.5)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
    );
  }



  Future<void> _shareNowPlaying() async {
    final currentMedia = audioHandler.mediaItem.value;
    if (currentMedia == null) return;

    final library = ref.read(libraryProvider);
    final fileId = (currentMedia.extras?['fileId'] as num?)?.toInt();
    final torrentId = (currentMedia.extras?['torrentId'] as num?)?.toInt();
    final meta = (fileId != null && torrentId != null) ? library.metadata['$torrentId-$fileId'] : null;

    final title = meta?.trackName ?? currentMedia.title;
    final artist = meta?.artistName ?? currentMedia.artist ?? 'Unknown Artist';
    final artworkUrl = meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? currentMedia.artUri?.toString();
    final album = meta?.album ?? currentMedia.album;

    // Create a GlobalKey for the RepaintBoundary
    final boundaryKey = GlobalKey();

    // Show a brief loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating share card...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 180,
      ),
    );

    // Build and render the card off-screen
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -500, top: -1000, // Off-screen
        child: RepaintBoundary(
          key: boundaryKey,
          child: NowPlayingShareCard(
            title: title,
            artist: artist,
            artworkUrl: artworkUrl,
            album: album,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);

    // Wait for images to load + render
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        overlay.remove();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      overlay.remove();

      if (byteData == null || !mounted) return;

      final tempDir = await getTemporaryDirectory();
      final file = io.File('${tempDir.path}/isai_now_playing.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎵 $title — $artist',
      );
    } catch (e) {
      overlay.remove();
      print('[Share] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }



  Widget _buildThreeColumnActions(
    BuildContext context,
    WidgetRef ref,
    bool isLiked,
    int actualTorrentId,
    int actualFileId,
    String displayTitle,
    String displayArtist,
    MediaItem? currentItem,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 1. Liked Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                ref.read(likedSongsProvider.notifier).toggleLike(
                  actualTorrentId,
                  actualFileId,
                  isLiked,
                  title: displayTitle,
                  artist: displayArtist,
                );
                
                if (!isLiked && currentItem != null) {
                   final db = getIt<AppDatabase>();
                   db.into(db.files).insertOnConflictUpdate(FilesCompanion.insert(
                     id: actualFileId,
                     torrentId: actualTorrentId,
                     name: currentItem.title,
                     size: 0,
                     isAudio: true,
                   ));
                   db.saveTrackMetadata(TrackMetadataCompanion.insert(
                     fileId: actualFileId,
                     torrentId: actualTorrentId,
                     trackTitle: drift.Value(currentItem.title),
                     artist: drift.Value(currentItem.artist),
                     artworkUrlLow: drift.Value(currentItem.artUri?.toString() ?? widget.initialArtwork),
                     artworkUrlHigh: drift.Value(currentItem.artUri?.toString() ?? widget.initialArtwork),
                     trackTimeMillis: drift.Value(currentItem.duration?.inMilliseconds),
                     isLiked: const drift.Value(true)
                   ));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Theme.of(context).colorScheme.primary : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLiked ? 'Liked' : 'Like',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white,
                        fontWeight: FontWeight.w600,),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 2. Playlist Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => PlaylistPickerSheet(
                    track: ItunesTrack(
                      trackId: actualFileId,
                      trackName: displayTitle,
                      artistName: displayArtist,
                      artworkUrl: currentItem?.artUri?.toString() ?? widget.initialArtwork ?? '',
                      collectionName: currentItem?.album ?? '',
                      artistViewUrl: '',
                    ),
                    libraryFile: TorBoxFile(
                      id: actualFileId,
                      torrentId: actualTorrentId,
                      name: displayTitle,
                      size: 0,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Playlist',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white,
                        fontWeight: FontWeight.w600,),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 3. Download Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _handleDownload();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Download',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white,
                        fontWeight: FontWeight.w600,),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final liveItem = audioHandler.mediaItem.value;
    final parsedFromLive = liveItem != null ? parseFilename(liveItem.title) : parseFilename(widget.file.displayName);
    final displayTitle = parsedFromLive.title.isNotEmpty ? parsedFromLive.title : (liveItem?.title ?? widget.file.name);
    final displayArtist = parsedFromLive.artist.isNotEmpty ? parsedFromLive.artist : (liveItem?.artist ?? 'Unknown Artist');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final currentItem = audioHandler.mediaItem.value;
          final dynamicTorrentId = (currentItem?.extras?['torrentId'] as num?)?.toInt();
          final dynamicFileId = (currentItem?.extras?['fileId'] as num?)?.toInt();
          final actualTorrentId = dynamicTorrentId ?? widget.file.torrentId;
          final actualFileId = dynamicFileId ?? widget.file.id;

          final isLiked = ref.watch(isTrackLikedProvider((torrentId: actualTorrentId, fileId: actualFileId)));

          return DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.25,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 8),
                        // Header with Artwork, Title, Artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: currentItem?.artUri?.toString() ?? widget.initialArtwork ?? '',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.white10),
                              errorWidget: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white,
                                    fontWeight: FontWeight.bold,),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  displayArtist,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60,),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // 3-Column Action Buttons
                    _buildThreeColumnActions(
                      context,
                      ref,
                      isLiked,
                      actualTorrentId,
                      actualFileId,
                      displayTitle,
                      displayArtist,
                      currentItem,
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    
                    // Repeat Mode Toggle
                    StreamBuilder<PlaybackState>(
                      stream: audioHandler.playbackState,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.none;

                        IconData icon;
                        Color iconColor;
                        String modeName;

                        switch (repeatMode) {
                          case AudioServiceRepeatMode.one:
                            icon = Icons.repeat_one;
                            iconColor = Theme.of(context).colorScheme.primary;
                            modeName = 'Repeat 1 time';
                            break;
                          case AudioServiceRepeatMode.all:
                            icon = Icons.repeat;
                            iconColor = Theme.of(context).colorScheme.primary;
                            modeName = 'Repeat infinite';
                            break;
                          case AudioServiceRepeatMode.none:
                          default:
                            icon = Icons.repeat;
                            iconColor = Colors.white54;
                            modeName = 'Normal queue';
                            break;
                        }

                        return ListTile(
                          leading: Icon(icon, color: iconColor),
                          title: Text('Repeat Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: Text(modeName, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,)),
                          onTap: () {
                            AudioServiceRepeatMode nextMode;
                            if (repeatMode == AudioServiceRepeatMode.none) {
                              nextMode = AudioServiceRepeatMode.one;
                            } else if (repeatMode == AudioServiceRepeatMode.one) {
                              nextMode = AudioServiceRepeatMode.all;
                            } else {
                              nextMode = AudioServiceRepeatMode.none;
                            }
                            audioHandler.setRepeatMode(nextMode);
                          },
                        );
                      }
                    ),



                    // 6. Go to Album
                    ListTile(
                      leading: const Icon(Icons.album, color: Colors.white),
                      title: Text('Go to Album', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => AlbumScreen(
                              album: ItunesTrack(
                                trackId: actualFileId,
                                trackName: displayTitle,
                                artistName: displayArtist,
                                artworkUrl: currentItem?.artUri?.toString() ?? widget.initialArtwork ?? '',
                                collectionName: currentItem?.album ?? '',
                                artistViewUrl: '',
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // 7. View Artist
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.white),
                      title: Text('View $displayArtist', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => ArtistScreen(artistName: displayArtist),
                          ),
                        );
                      },
                    ),

                    // 8. Share
                    ListTile(
                      leading: const Icon(Icons.share, color: Colors.white),
                      title: Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareNowPlaying();
                      },
                    ),
                    
                    const Divider(color: Colors.white12, height: 1),

                    // 9. Sleep Timer
                    ListTile(
                      leading: Icon(
                        _sleepTimer != null || _sleepAtEndOfTrack ? Icons.bedtime : Icons.bedtime_outlined,
                        color: _sleepTimer != null || _sleepAtEndOfTrack ? Theme.of(context).colorScheme.primary : Colors.white,
                      ),
                      title: Text(
                        _sleepTimer != null || _sleepAtEndOfTrack ? 'Sleep Timer (active)' : 'Sleep Timer',
                        style: TextStyle(
                          color: _sleepTimer != null || _sleepAtEndOfTrack ? Theme.of(context).colorScheme.primary : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: _sleepAtEndOfTrack 
                          ? Text('Stops at end of track', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,))
                          : (_sleepTimerEnd != null
                              ? StreamBuilder<DateTime>(
                                  stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                                  builder: (_, __) {
                                    final remaining = _sleepTimerEnd!.difference(DateTime.now());
                                    if (remaining.isNegative) return Text('Stopping...', style: TextStyle(color: Colors.white54));
                                    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
                                    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
                                    return Text('Stops in ${remaining.inHours > 0 ? "${remaining.inHours}h " : ""}$m:$s', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,));
                                  },
                                )
                              : null),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSleepTimerSheet();
                      },
                    ),

                    // 10. Song Info
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: Text('Song Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _SongInfoSheet(
                            file: widget.file,
                            onCloseLyrics: () {
                              if (_showLyrics) setState(() => _showLyrics = false);
                            },
                          ),
                        );
                      },
                    ),

                    // 11. Visualizer
                    ListTile(
                      leading: const Icon(Icons.equalizer_rounded, color: Colors.white),
                      title: Text('Visualizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VisualizerSettingsSheet(),
                          ),
                        );
                      },
                    ),

                    // 12. Fix Metadata
                    ListTile(
                      leading: const Icon(Icons.edit_note_rounded, color: Colors.white),
                      title: Text('Fix Metadata', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MetadataPickerSheet(
                            file: widget.file,
                            initialQuery: displayTitle,
                            initialArtist: displayArtist,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            }
          );
        }
      ),
    );
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SleepTimerSheet(
        isActive: _sleepTimer != null,
        isEndOfTrackActive: _sleepAtEndOfTrack,
        remainingEnd: _sleepTimerEnd,
        onSet: (Duration duration) {
          Navigator.pop(ctx);
          _sleepTimer?.cancel();
          if (duration == Duration.zero) {
            setState(() {
              _sleepAtEndOfTrack = true;
              _sleepTimerTrackId = audioHandler.mediaItem.value?.id;
              _sleepTimerEnd = null;
              _sleepTimer = null;
            });
            print('[SleepTimer] Set to sleep at end of track: $_sleepTimerTrackId');
          } else {
            setState(() {
              _sleepAtEndOfTrack = false;
              _sleepTimerTrackId = null;
              _sleepTimerEnd = DateTime.now().add(duration);
              _sleepTimer = Timer(duration, () async {
                await audioHandler.stop();
                if (mounted) setState(() { _sleepTimer = null; _sleepTimerEnd = null; });
              });
            });
          }
        },
        onCancel: () {
          Navigator.pop(ctx);
          _sleepTimer?.cancel();
          setState(() { 
            _sleepTimer = null; 
            _sleepTimerEnd = null; 
            _sleepAtEndOfTrack = false;
            _sleepTimerTrackId = null;
          });
        },
      ),
    );
  }

  Widget _buildAlbumArt(bool hasArtwork, String? artworkUrl) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final pState = snapshot.data?.processingState;
        final playing = snapshot.data?.playing ?? false;
        final isBuffering = pState == AudioProcessingState.buffering || 
                           pState == AudioProcessingState.loading;
        
        final settings = ref.watch(settingsProvider);
        final showLoading = (_isLoading || isBuffering) && !playing;
        
        final artworkSize = settings.playerArtworkSize;
        final shape = settings.playerArtworkShape;
        final showGlow = settings.playerShowGlow;

        final displaySize = artworkSize * 1.15;

        final isWideScreen = MediaQuery.of(context).size.width > 720;
        return Align(
          alignment: isWideScreen ? Alignment.center : const Alignment(0, -0.3),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: displaySize,
              maxHeight: displaySize,
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                key: ValueKey('art_${artworkUrl ?? 'no_art'}'),
                alignment: Alignment.center,
                children: [
                  // Glow effect (behind everything, only for album art)
                  if (showGlow && hasArtwork)
                    Positioned.fill(
                      child: Transform.scale(
                        scale: 1.15,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                          child: Opacity(
                            opacity: 0.7,
                            child: CachedNetworkImage(
                              imageUrl: artworkUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Album art image
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: shape == 'circle' ? null : BorderRadius.circular(shape == 'rounded' ? 24 : 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'artwork_hero',
                        child: ClipRRect(
                          borderRadius: shape == 'circle' 
                              ? BorderRadius.circular(displaySize / 2) 
                              : BorderRadius.circular(shape == 'rounded' ? 24 : 4),
                          child: hasArtwork
                              ? CachedNetworkImage(
                                  imageUrl: artworkUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => _artworkPlaceholder(size: displaySize, iconSize: displaySize * 0.4),
                                )
                              : _artworkPlaceholder(size: displaySize, iconSize: displaySize * 0.4),
                        ),
                      ),
                    ),
                  ),

                  // Loading indicator
                  if (showLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: shape == 'circle' ? null : BorderRadius.circular(shape == 'rounded' ? 24 : 4),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _artworkPlaceholder({double size = 48, double iconSize = 24}) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF2D2D3F),
      child: Center(
        child: Icon(Icons.music_note, size: iconSize, color: Colors.white24),
      ),
    );
  }

  Widget _buildTrackInfo(String title, String artist) {
    final artists = ItunesTrack.splitArtists(artist);
    final isM3 = ref.watch(settingsProvider).appThemeStyle == 'material3';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: isM3 
                    ? Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white,
                        fontWeight: FontWeight.bold,),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...artists.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final name = entry.value;
                    final isLast = idx == artists.length - 1;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistScreen(artistName: name),
                          ),
                        );
                      },
                      child: Text(
                        name + (isLast ? "" : " & "),
                        style: isM3
                            ? Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.primary,),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
        StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final currentItem = snapshot.data;
            final dynamicTorrentId = (currentItem?.extras?['torrentId'] as num?)?.toInt();
            final dynamicFileId = (currentItem?.extras?['fileId'] as num?)?.toInt();

            final actualTorrentId = dynamicTorrentId ?? widget.file.torrentId;
            final actualFileId = dynamicFileId ?? widget.file.id;
            return Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(settingsProvider);
                final isLiked = ref.watch(isTrackLikedProvider((torrentId: actualTorrentId, fileId: actualFileId)));
                
                IconData likeIcon;
                switch (settings.playerLikeIcon) {
                  case 'thumb':
                    likeIcon = isLiked ? Icons.thumb_up : Icons.thumb_up_outlined;
                    break;
                  case 'gift':
                    likeIcon = isLiked ? Icons.card_giftcard : Icons.card_giftcard;
                    break;
                  default:
                    likeIcon = isLiked ? Icons.favorite : Icons.favorite_border;
                }
                
                return IconButton(
                  icon: Icon(
                    likeIcon,
                    color: isLiked ? Theme.of(context).colorScheme.primary : Colors.white54,
                  ),
                  onPressed: () {
                    // Update the Database & Last.fm
                    ref.read(likedSongsProvider.notifier).toggleLike(
                      actualTorrentId, 
                      actualFileId, 
                      isLiked,
                      title: currentItem?.title ?? widget.file.displayName,
                      artist: currentItem?.artist ?? '',
                    );
                    
                    // If we just liked a song that isn't already in the "Files" DB (like a direct stream), 
                    // we need to make sure basic metadata is stored so it shows up beautifully in the Liked Songs screen!
                    if (!isLiked && currentItem != null) {
                       final db = getIt<AppDatabase>();
                       db.into(db.files).insertOnConflictUpdate(FilesCompanion.insert(
                         id: actualFileId,
                         torrentId: actualTorrentId,
                         name: currentItem.title,
                         size: 0,
                         isAudio: true,
                       ));
                       db.saveTrackMetadata(TrackMetadataCompanion.insert(
                         fileId: actualFileId,
                         torrentId: actualTorrentId,
                         trackTitle: drift.Value(currentItem.title),
                         artist: drift.Value(currentItem.artist),
                         artworkUrlLow: drift.Value(currentItem.artUri?.toString()),
                         artworkUrlHigh: drift.Value(currentItem.artUri?.toString()),
                         trackTimeMillis: drift.Value(currentItem.duration?.inMilliseconds),
                         isLiked: const drift.Value(true)
                       ));
                    }
                  },
                );
              },
            );
          }
        ),
      ],
    );
  }

  String _getTrackFormat(MediaItem item) {
    String? format = item.extras?['format'] as String?;
    if (format == null || format.isEmpty) {
      final localPath = item.extras?['localPath'] as String?;
      final url = item.id;
      final pathToCheck = localPath ?? url;
      final originalId = item.extras?['originalId'] as String?;
      final linkType = item.extras?['linkType'] as String?;
      
      if (pathToCheck.toLowerCase().endsWith('.flac') || 
          pathToCheck.contains('lazy.flac.internal') ||
          (originalId != null && originalId.contains('lazy.flac.internal')) ||
          linkType == 'flac') {
        format = 'FLAC';
      } else if (pathToCheck.toLowerCase().endsWith('.mp3')) {
        format = 'MP3';
      } else if (pathToCheck.toLowerCase().endsWith('.m4a') || pathToCheck.toLowerCase().endsWith('.aac') || pathToCheck.contains('youtube') || pathToCheck.contains('googlevideo')) {
        format = 'AAC';
      } else if (pathToCheck.toLowerCase().endsWith('.wav')) {
        format = 'WAV';
      } else if (pathToCheck.toLowerCase().contains('soundcloud')) {
        format = 'MP3';
      } else {
        format = 'AAC'; // default/fallback
      }
    }
    
    final bitrate = item.extras?['bitrate'] as int?;
    if (bitrate != null && bitrate > 0) {
      final kbps = (bitrate >= 8000 && bitrate <= 48000)
          ? (bitrate / 100).round()
          : (bitrate / 1000).round();
      if (!format.toLowerCase().contains('kbps')) {
        format = '$format ($kbps kbps)';
      }
    }
    
    return format;
  }

  String _getTrackSource(MediaItem item) {
    String? source = item.extras?['source'] as String?;
    if (source == null || source.isEmpty) {
      final url = item.id;
      final localPath = item.extras?['localPath'] as String?;
      final isLocal = localPath != null && localPath.isNotEmpty;
      final linkType = item.extras?['linkType'] as String?;
      
      if (isLocal) {
        source = 'Local Storage';
      } else if (linkType == 'youtube' || url.contains('youtube') || url.contains('googlevideo')) {
        source = 'YouTube';
      } else if (url.contains('lazy.flac.internal') || linkType == 'flac') {
        source = 'FLAC Scraper';
      } else if (item.extras?['torrentId'] != null && (item.extras?['torrentId'] as num) > 0) {
        source = 'TorBox Torrent';
      } else {
        source = 'Streaming Server';
      }
    }
    return source;
  }

  Widget _buildQualityBadge(MediaItem? item) {
    if (item == null) return const SizedBox.shrink();
    final format = _getTrackFormat(item);
    final lowerFormat = format.toLowerCase();
    final IconData icon;
    final List<Color> gradientColors;
    final Color textColor;
    
    if (lowerFormat.contains('hi-res') || lowerFormat.contains('hires') || lowerFormat.contains('24bit') || lowerFormat.contains('192khz')) {
      icon = Icons.star_rounded;
      gradientColors = [const Color(0xFFFF2D55), const Color(0xFFFF9500)];
      textColor = Colors.white;
    } else if (lowerFormat.contains('flac') || lowerFormat.contains('lossless') || lowerFormat.contains('alac') || lowerFormat.contains('wav')) {
      icon = Icons.music_note_rounded;
      gradientColors = [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)];
      textColor = Colors.white70;
    } else {
      icon = Icons.high_quality_rounded;
      gradientColors = [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)];
      textColor = Colors.white60;
    }
    
    String? codec = item.extras?['format'] as String?;
    if (codec == null || codec.isEmpty) {
      final localPath = item.extras?['localPath'] as String?;
      final url = item.id;
      final pathToCheck = localPath ?? url;
      final originalId = item.extras?['originalId'] as String?;
      final linkType = item.extras?['linkType'] as String?;
      
      if (pathToCheck.toLowerCase().endsWith('.flac') || 
          pathToCheck.contains('lazy.flac.internal') ||
          (originalId != null && originalId.contains('lazy.flac.internal')) ||
          linkType == 'flac') {
        codec = 'FLAC';
      } else if (pathToCheck.toLowerCase().endsWith('.mp3')) {
        codec = 'MP3';
      } else if (pathToCheck.toLowerCase().endsWith('.m4a') || pathToCheck.toLowerCase().endsWith('.aac') || pathToCheck.contains('youtube') || pathToCheck.contains('googlevideo')) {
        codec = 'AAC';
      } else if (pathToCheck.toLowerCase().endsWith('.wav')) {
        codec = 'WAV';
      } else if (pathToCheck.toLowerCase().contains('soundcloud')) {
        codec = 'MP3';
      } else {
        codec = 'AAC'; // default/fallback
      }
    }

    final bitrate = item.extras?['bitrate'] as int?;
    String bitrateStr = '';
    if (bitrate != null && bitrate > 0) {
      final kbps = (bitrate >= 8000 && bitrate <= 48000)
          ? (bitrate / 100).round()
          : (bitrate / 1000).round();
      bitrateStr = '$kbps kbps';
    }

    final sampleRate = item.extras?['sampleRate'] as int?;
    String sampleRateStr = '';
    if (sampleRate != null && sampleRate > 0) {
      sampleRateStr = '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
    }

    String finalLabel = codec.toUpperCase();
    if (bitrateStr.isNotEmpty) {
      finalLabel = '$finalLabel:$bitrateStr';
    }
    if (sampleRateStr.isNotEmpty) {
      finalLabel = '$finalLabel/$sampleRateStr';
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _showQualityInfoSheet(context, item),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: textColor),
              const SizedBox(width: 4),
              Text(finalLabel.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualityInfoSheet(BuildContext context, MediaItem? item) {
    if (item == null) return;
    final format = _getTrackFormat(item);
    final source = _getTrackSource(item);
    final size = item.extras?['size'] as num? ?? 0;
    
    final lowerFormat = format.toLowerCase();
    final isLossless = lowerFormat.contains('flac') || lowerFormat.contains('lossless') || lowerFormat.contains('wav');
    final isHiRes = lowerFormat.contains('hi-res') || lowerFormat.contains('hires') || lowerFormat.contains('24bit') || lowerFormat.contains('192khz');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1C24).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(children: [
              Icon(isHiRes ? Icons.star_rounded : (isLossless ? Icons.music_note_rounded : Icons.high_quality_rounded), color: isHiRes ? const Color(0xFFFF2D55) : Colors.white70, size: 28),
              const SizedBox(width: 12),
              Text(isHiRes ? 'Hi-Res Lossless Audio' : (isLossless ? 'Lossless Audio' : 'High Quality Audio'), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            Text(isHiRes 
              ? 'Studio quality recording format (up to 24-bit/192 kHz) preserving every detail of the performance.' 
              : (isLossless ? 'Lossless compression preserves all of the original data in the audio file for CD-quality playback.' : 'High Quality compression formats (AAC/MP3) provide excellent acoustic reproduction with efficient network usage.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.7), height: 1.4)),
            const Divider(color: Colors.white10, height: 32),
            _buildInfoRow('Codec/Format', format.toUpperCase()),
            if (item.extras?['sampleRate'] != null) _buildInfoRow('Sample Rate', '${item.extras!['sampleRate']} Hz'),
            _buildInfoRow('Source Provider', source),
            if (size > 0) _buildInfoRow('File Size', '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'),
            const SizedBox(height: 24),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.08), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.4),)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSeekBar({bool isLyricsMode = false}) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnap) {
        final totalDuration = mediaSnap.data?.duration ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: AudioService.position,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final settings = ref.watch(settingsProvider);
            final isM3 = settings.appThemeStyle == 'material3';
            final colorScheme = Theme.of(context).colorScheme;
            
            double value = 0;
            if (totalDuration.inMilliseconds > 0) {
              value = (position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
            }

            SliderThemeData sliderThemeData = SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: isM3 ? colorScheme.primary : Colors.white,
              inactiveTrackColor: isM3 ? colorScheme.secondaryContainer : Colors.white24,
              thumbColor: isM3 ? colorScheme.primary : Colors.white,
              overlayColor: isM3 ? colorScheme.primary.withOpacity(0.12) : Colors.white24,
            );

            if (settings.playerSeekBarStyle == 'rainbow') {
              sliderThemeData = sliderThemeData.copyWith(
                trackShape: RainbowSliderTrackShape(),
              );
            } else if (settings.playerSeekBarStyle == 'wavy') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: WavySliderTrackShape(),
              );
            } else if (settings.playerSeekBarStyle == 'gradient') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: GradientSliderTrackShape(),
              );
            } else if (settings.playerSeekBarStyle == 'capsule') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: CapsuleSliderTrackShape(),
                thumbShape: SliderComponentShape.noThumb,
              );
            } else if (settings.playerSeekBarStyle == 'neon') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: NeonSliderTrackShape(),
              );
            } else if (settings.playerSeekBarStyle == 'dashed') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: DashedSliderTrackShape(),
              );
            } else if (settings.playerSeekBarStyle == 'dotted') {
               sliderThemeData = sliderThemeData.copyWith(
                trackShape: DottedSliderTrackShape(),
              );
            }

            final timeColor = isM3 ? colorScheme.onSurfaceVariant : Colors.white54;

            return Column(
              children: [
                SliderTheme(
                  data: sliderThemeData,
                  child: Slider(
                    value: value,
                    onChanged: (v) {
                      if (totalDuration.inMilliseconds > 0) {
                        final target = Duration(
                          milliseconds: (v * totalDuration.inMilliseconds).toInt(),
                        );
                        audioHandler.seek(target);
                      }
                    },
                    onChangeEnd: (v) {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: timeColor,)),
                      Text(
                        totalDuration == Duration.zero
                            ? '--:--'
                            : (isLyricsMode
                                ? '-${_formatDuration(totalDuration - position)}'
                                : _formatDuration(totalDuration)),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: timeColor,),
                      ),
                    ],
                  ),
                ),
                if (!isLyricsMode) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: _buildQualityBadge(mediaSnap.data),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLyricsToggledLayout(
    bool hasArtwork,
    String displayArtwork,
    String displayTitle,
    String displayArtist,
    dynamic settings,
    bool isM3,
  ) {
    return Column(
      children: [
        // Custom Header for Lyrics Mode
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: displayArtwork,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayArtist,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _showLyrics = false),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showOptionsMenu(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),

        // Lyrics Scrollable Content
        Expanded(
          child: _buildLyricsContent(),
        ),

        const SizedBox(height: 16),

        // Seek Bar & Transport Controls (no volume bar or bottom bar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              _buildSeekBar(isLyricsMode: true),
              const SizedBox(height: 16),
              _buildTransportControls(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls() {
    final settings = ref.watch(settingsProvider);
    final isM3 = settings.playerButtonStyle == 'theme' 
        ? settings.appThemeStyle == 'material3' 
        : settings.playerButtonStyle == 'm3';

    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final colorScheme = Theme.of(context).colorScheme;

        return InteractiveControls(
          isM3: isM3,
          playing: playing,
          colorScheme: colorScheme,
          onPrevious: () {
            HapticFeedback.mediumImpact();
            audioHandler.skipToPrevious();
          },
          onNext: () {
            HapticFeedback.mediumImpact();
            audioHandler.skipToNext();
          },
          onPlayPause: () {
            HapticFeedback.mediumImpact();
            if (playing) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          },
        );
      },
    );
  }

  Widget _buildVolumeBar() {
    final settings = ref.watch(settingsProvider);
    final isM3 = settings.appThemeStyle == 'material3';
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = isM3 ? colorScheme.onSurfaceVariant : Colors.white54;
    final activeColor = isM3 ? colorScheme.primary : Colors.white70;
    final inactiveColor = isM3 ? colorScheme.secondaryContainer : Colors.white24;
    final thumbColor = isM3 ? colorScheme.primary : Colors.white;

    return Row(
      children: [
        Icon(Icons.volume_mute_rounded, color: iconColor, size: 20),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              thumbColor: thumbColor,
            ),
            child: Slider(
              value: _volume,
              onChanged: (val) {
                setState(() => _volume = val);
                audioHandler.customAction('setVolume', {'volume': val});
              },
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded, color: iconColor, size: 20),
      ],
    );
  }

  Widget _buildBottomBar() {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isMinimalist = settings.playerControlLayout == 'minimalist';

    final showSource = !isMinimalist || settings.playerMinimalistShowSource;
    final showLyrics = !isMinimalist || settings.playerMinimalistShowLyrics;
    final showSleep = !isMinimalist || settings.playerMinimalistShowSleep;
    final showQueue = !isMinimalist || settings.playerMinimalistShowQueue;

    // If minimalist and all are disabled, return empty
    if (isMinimalist && !showSource && !showLyrics && !showSleep && !showQueue) {
      return const SizedBox();
    }

    final leftButtons = [
      if (showSource)
        GestureDetector(
          onTap: _showSourceSelection,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
            child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 22),
          ),
        ),
      if (showLyrics)
        GestureDetector(
          onTap: () => setState(() => _showLyrics = !_showLyrics),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _showLyrics ? colorScheme.primary.withOpacity(0.2) : Colors.white.withOpacity(0.08),
            ),
            child: Icon(
              _showLyrics ? CupertinoIcons.quote_bubble_fill : CupertinoIcons.quote_bubble,
              color: _showLyrics ? Colors.pink : Colors.white,
              size: 24,
            ),
          ),
        ),
      if (showSleep)
        GestureDetector(
          onTap: _showSleepTimerSheet,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_sleepTimer != null || _sleepAtEndOfTrack)
                  ? colorScheme.primary.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
            ),
            child: Icon(
              (_sleepTimer != null || _sleepAtEndOfTrack) ? Icons.bedtime : Icons.bedtime_outlined,
              color: (_sleepTimer != null || _sleepAtEndOfTrack) ? colorScheme.primary : Colors.white,
              size: 22,
            ),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Left Group (Source, Lyrics, Sleep Timer)
          for (int i = 0; i < leftButtons.length; i++) ...[
            leftButtons[i],
            if (i < leftButtons.length - 1) const SizedBox(width: 12),
          ],
          const Spacer(),
          // Up Next on the right
          if (showQueue)
            GestureDetector(
              onTap: _showQueue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.08),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Up Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleDownload() async {
    final currentMedia = audioHandler.mediaItem.value;
    if (currentMedia == null) return;
    
    final torrentId = (currentMedia.extras?['torrentId'] as num?)?.toInt();
    final fileId = (currentMedia.extras?['fileId'] as num?)?.toInt();

    if (torrentId == null || fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot download this track')),
      );
      return;
    }

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();

    final notifier = ref.read(libraryProvider.notifier);
    notifier.clearDownloadError();

    // --- CASE 1: Virtual Tracks (SoundCloud, YouTube, FLAC Search) ---
    if (torrentId == -1) {
      String? url = currentMedia.id;
      String extension = '.flac'; // Default
      final linkType = currentMedia.extras?['linkType'] as String?;

      // Handle SoundCloud resolution if needed
      // Handle lazy internal links
      if (url.contains('.internal')) {
        // Here we could resolve TorBox lazy links if needed, 
        // but typically users download from the library for those.
        // For now, let's just alert the user if we can't resolve.
      }

      if (url == null || !url.startsWith('http')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source URL not available for download')),
        );
        return;
      }

      await notifier.downloadTrackFromUri(
        url: url,
        title: currentMedia.title,
        artist: currentMedia.artist ?? 'Unknown',
        artworkUrl: currentMedia.artUri?.toString(),
        durationMs: currentMedia.duration?.inMilliseconds,
        fileId: fileId,
        extension: extension,
      );
      if (!mounted) return;
      return;
    }

    // --- CASE 2: Track IS in TorBox library ---
    final library = ref.read(libraryProvider);
    final torrent = library.torrents.where((t) => t.id == torrentId).firstOrNull;
    final file = torrent?.files.where((f) => f.id == fileId).firstOrNull;

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found in library')),
      );
      return;
    }

    final isDownloaded = notifier.isDownloaded(file);
    if (isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already downloaded')),
      );
      return;
    }

    await notifier.downloadTrack(file);
    if (!mounted) return;
  }

  void _showSourceSelection() {
    final mediaItem = audioHandler.mediaItem.value;
    final extras = mediaItem?.extras ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SourceSheet(
        title: mediaItem?.title ?? '',
        artist: mediaItem?.artist ?? '',
        activeFileId: (extras['fileId'] as num?)?.toInt() ?? 0,
        activeTorrentId: (extras['torrentId'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  void _showQueue() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _QueueBottomSheet(),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Text(_error!, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red,)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadAndPlay,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          child: Text('Retry'),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  Widget _buildLyricsProviderSelector() {
    final lyricsState = ref.watch(lyricsProvider);
    final currentItem = audioHandler.mediaItem.value;
    final trackName = currentItem?.title ?? '';
    final artistName = currentItem?.artist ?? '';
    final durationMs = currentItem?.duration?.inMilliseconds;
    final albumName = currentItem?.album;

    String providerLabel;
    switch (lyricsState.selectedProvider) {
      case LyricsProviderType.auto:
        providerLabel = 'Auto';
        break;
      case LyricsProviderType.lyricsOvh:
        providerLabel = 'Lyrics.ovh';
        break;
      case LyricsProviderType.lrclib:
        providerLabel = 'LRCLIB';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (lyricsState.lyrics?.source != null) ...[
            Text(
              lyricsState.lyrics!.source!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38, fontWeight: FontWeight.w400),
            ),
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          InkWell(
            onTap: () => _showLyricsProviderSelectorMenu(context, lyricsState.selectedProvider, trackName, artistName, album: albumName, durationMs: durationMs),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lyrics_outlined, color: Colors.white70, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Provider: $providerLabel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLyricsProviderSelectorMenu(
    BuildContext context,
    LyricsProviderType currentProvider,
    String track,
    String artist, {
    String? album,
    int? durationMs,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 8, left: 20),
                  child: Text(
                    'Select Lyrics Provider',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: Icon(
                    Icons.auto_awesome,
                    color: currentProvider == LyricsProviderType.auto ? Theme.of(context).colorScheme.primary : Colors.white54,
                  ),
                  title: Text('Auto (Priority Mirror Search)', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Searches lyrics.ovh first, falls back to LRCLIB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,)),
                  trailing: currentProvider == LyricsProviderType.auto ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(lyricsProvider.notifier).setProvider(LyricsProviderType.auto, track, artist, album: album, durationMs: durationMs);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.music_note,
                    color: currentProvider == LyricsProviderType.lyricsOvh ? Theme.of(context).colorScheme.primary : Colors.white54,
                  ),
                  title: Text('Lyrics.ovh (Plain Text)', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Fetches from api.lyrics.ovh free API', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,)),
                  trailing: currentProvider == LyricsProviderType.lyricsOvh ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(lyricsProvider.notifier).setProvider(LyricsProviderType.lyricsOvh, track, artist, album: album, durationMs: durationMs);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.cloud_queue,
                    color: currentProvider == LyricsProviderType.lrclib ? Theme.of(context).colorScheme.primary : Colors.white54,
                  ),
                  title: Text('LRCLIB (Crowdsourced)', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Fetches from lrclib.net open database', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,)),
                  trailing: currentProvider == LyricsProviderType.lrclib ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(lyricsProvider.notifier).setProvider(LyricsProviderType.lrclib, track, artist, album: album, durationMs: durationMs);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricsContent() {
    final lyricsState = ref.watch(lyricsProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lyricsWidget = () {
      if (lyricsState.isLoading) {
        return Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        );
      }

      if (lyricsState.error != null || lyricsState.lyrics == null) {
        return Center(
          child: Text(
            lyricsState.error ?? 'No lyrics found',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
          ),
        );
      }

      final lyrics = lyricsState.lyrics!;
      
      if (lyrics.hasSynced) {
        return _buildSyncedLyrics(lyrics);
      }

      final currentMedia = audioHandler.mediaItem.value;
      final meta = currentMedia?.extras?['meta'] as ItunesMeta?;

      return Column(
        children: [
          Text(
            meta?.trackName ?? currentMedia?.title ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white,
              fontWeight: FontWeight.bold,),
          ),
          const SizedBox(height: 4),
          Text(
            meta?.artistName ?? (currentMedia?.artist?.isNotEmpty == true ? currentMedia!.artist! : 'TorBox'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70,
              fontWeight: FontWeight.w500,),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              controller: _lyricsScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text(
                lyrics.plainLyrics ?? '',
                textAlign: settings.playerLyricsAlignment == 'left' 
                    ? TextAlign.left 
                    : (settings.playerLyricsAlignment == 'right' ? TextAlign.right : TextAlign.center),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: settings.playerLyricsFontSize,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
    }();

    return Column(
      children: [
        _buildLyricsProviderSelector(),
        const SizedBox(height: 8),
        Expanded(child: lyricsWidget),
      ],
    );
  }


  Widget _buildSyncedLyrics(LyricsData lyrics) {
    final settings = ref.watch(settingsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        const itemHeight = 60.0; 
        final focusPoint = viewportHeight * 0.3; // Raise focus even higher (30% from top)

        return StreamBuilder<Duration>(
          stream: AudioService.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final adjustedPosition = position + _lyricsOffset;
            
            // Find current line
            int currentLineIndex = -1;
            for (int i = 0; i < lyrics.syncedLines.length; i++) {
              if (lyrics.syncedLines[i].timestamp <= adjustedPosition) {
                currentLineIndex = i;
              } else {
                break;
              }
            }

            // Auto-scroll logic with centering
            if (currentLineIndex != _lastLyricIndex && currentLineIndex != -1) {
              _lastLyricIndex = currentLineIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                
                if (_lyricsScrollController.hasClients) {
                  try {
                    // Check if we can safely cast the position
                    final position = _lyricsScrollController.position;
                    
                    // Center the active line at focusPoint
                    final targetOffset = (currentLineIndex * itemHeight) - focusPoint + (itemHeight / 2);
                    
                    // Do not clamp to maxScrollExtent. During keyboard presentation,
                    // the view resizes and maxScrollExtent becomes violently unstable or even negative,
                    // causing asserts in ScrollPosition. Allow the ListView physics to clamp it naturally.
                    final offset = targetOffset < 0 ? 0.0 : targetOffset;
                    
                    _lyricsScrollController.animateTo(
                      offset,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                    );
                  } on StateError {
                    // This catches the exact "Cannot get renderObject" exception
                    // which is thrown as a StateError by Flutter when the tree is detached.
                    debugPrint('Skipped lyrics scroll: widget tree detached (likely keyboard opening)');
                  } catch (e) {
                    debugPrint('Ignored expected scroll error: $e');
                  }
                }
              });
            }

            return Stack(
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.1, 0.7, 1.0], // Fade out earlier at the bottom
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _lyricsScrollController,
                    padding: EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: focusPoint - (itemHeight / 2),
                      bottom: viewportHeight - focusPoint - (itemHeight / 2),
                    ),
                    itemCount: lyrics.syncedLines.length,
                    itemBuilder: (context, index) {
                      final line = lyrics.syncedLines[index];
                      final isActive = index == currentLineIndex;
                      final baseStyle = TextStyle(
                        fontSize: isActive ? settings.playerLyricsFontSize + 4 : settings.playerLyricsFontSize,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        height: 1.2,
                      );

                      Widget textWidget;
                      if (line.words.isNotEmpty) {
                        final spans = <TextSpan>[];
                        for (int i = 0; i < line.words.length; i++) {
                          final word = line.words[i];
                          Color wordColor;
                          
                          if (adjustedPosition >= word.end) {
                            wordColor = isActive ? Colors.white : Colors.white.withOpacity(0.2);
                          } else if (adjustedPosition >= word.start && adjustedPosition < word.end) {
                            wordColor = isActive ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.2);
                          } else {
                            wordColor = isActive ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1);
                          }
                          
                          spans.add(TextSpan(
                            text: word.text + (i < line.words.length - 1 ? ' ' : ''),
                            style: baseStyle.copyWith(color: wordColor),
                          ));
                        }
                        textWidget = RichText(
                          text: TextSpan(children: spans),
                          textAlign: settings.playerLyricsAlignment == 'left' 
                              ? TextAlign.left 
                              : (settings.playerLyricsAlignment == 'right' ? TextAlign.right : TextAlign.center),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      } else {
                        textWidget = AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          style: baseStyle.copyWith(
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                          ),
                          child: Text(
                            line.text,
                            textAlign: settings.playerLyricsAlignment == 'left' 
                                ? TextAlign.left 
                                : (settings.playerLyricsAlignment == 'right' ? TextAlign.right : TextAlign.center),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }

                      return Container(
                        height: itemHeight,
                        alignment: settings.playerLyricsAlignment == 'left' 
                            ? Alignment.centerLeft 
                            : (settings.playerLyricsAlignment == 'right' ? Alignment.centerRight : Alignment.center),
                        child: textWidget,
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _lyricsOffset -= const Duration(milliseconds: 500);
                            });
                          },
                          child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_lyricsOffset.inMilliseconds >= 0 ? '+' : ''}${(_lyricsOffset.inMilliseconds / 1000).toStringAsFixed(1)}s',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _lyricsOffset += const Duration(milliseconds: 500);
                            });
                          },
                          child: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 22),
                        ),
                        if (_lyricsOffset != Duration.zero) ...[
                          const SizedBox(width: 10),
                          Container(width: 1, height: 16, color: Colors.white10),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _lyricsOffset = Duration.zero;
                              });
                            },
                            child: Icon(Icons.restore_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SongInfoSheet extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final String? initialArtwork;
  final VoidCallback? onCloseLyrics;

  const _SongInfoSheet({
    required this.file,
    this.initialArtwork,
    this.onCloseLyrics,
  });

  @override
  ConsumerState<_SongInfoSheet> createState() => _SongInfoSheetState();
}

class _SongInfoSheetState extends ConsumerState<_SongInfoSheet> {
  ItunesMeta? _enrichedMeta;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _checkAndEnrichMetadata();
  }

  Future<void> _checkAndEnrichMetadata() async {
    final library = ref.read(libraryProvider);
    final existingMeta = library.metadata['${widget.file.torrentId}-${widget.file.id}'];
    
    // If we have genre or album, we consider it "enriched enough"
    if (existingMeta?.genre != null || existingMeta?.album != null) {
      return;
    }

    final parsed = parseFilename(widget.file.displayName);
    if (parsed.title.isEmpty) return;

    setState(() => _isFetching = true);
    
    try {
      final itunes = getIt<ItunesMetadataService>();
      final result = await itunes.fetchMeta(parsed.title, parsed.artist);
      if (!mounted) return;
      
      if (result != null && mounted) {
        final enriched = ItunesMeta(
          trackName: result.trackName,
          artistName: result.artistName,
          artworkUrlLow: result.artworkUrlLow,
          artworkUrlHigh: result.artworkUrlHigh,
          album: result.album,
          genre: result.genre,
          releaseYear: result.releaseYear,
          trackTimeMillis: result.trackTimeMillis,
        );
        
        setState(() => _enrichedMeta = enriched);
        
        // Persist to library
        await ref.read(libraryProvider.notifier).updateTrackMetadata(widget.file, enriched);
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      print('[SongInfoSheet] Enrichment error: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  String _detectedFormat() {
    final name = widget.file.name.toLowerCase();
    
    // Check extension first
    if (name.endsWith('.flac')) return 'FLAC';
    if (name.endsWith('.mp3')) return 'MP3';
    if (name.endsWith('.m4a') || name.endsWith('.aac')) return 'AAC/M4A';
    if (name.endsWith('.wav')) return 'WAV';
    if (name.endsWith('.ogg')) return 'OGG';

    // If no extension, or potentially a generic pirate bay name, 
    // check the stream source which is more reliable for our "Lazy" streams.
    final currentMedia = audioHandler.mediaItem.value;
    
    // Check for "FLAC" in the filename anywhere as a fallback
    if (name.contains('flac')) return 'FLAC';

    if (currentMedia != null) {
      final id = currentMedia.id.toLowerCase();
      if (id.contains('flac') || id.contains('tidal')) return 'FLAC';
      if (id.contains('torbox')) return 'MP3/FLAC';
    }

    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      initialData: audioHandler.mediaItem.value,
      builder: (context, snapshot) {
        final liveItem = snapshot.data;
        final activeParsed = parseFilename(widget.file.displayName);

        // liveItem is the primary source of truth — always use it if available
        // widget.file is only a fallback when no track is playing
        final liveFileId = (liveItem?.extras?['fileId'] as num?)?.toInt();
        final liveTorrentId = (liveItem?.extras?['torrentId'] as num?)?.toInt();

        // Try to resolve enriched metadata for the LIVE track
        ItunesMeta? activeMeta;
        if (liveFileId != null && liveTorrentId != null && liveTorrentId != -1) {
          activeMeta = library.metadata['$liveTorrentId-$liveFileId'];
        }
        if (activeMeta == null && widget.file.torrentId != -1) {
          activeMeta = library.metadata['${widget.file.torrentId}-${widget.file.id}'];
        }
        activeMeta ??= _enrichedMeta;

        // Prefer liveItem data, fall back to widget.file as last resort
        final displayTitle = activeMeta?.trackName
            ?? liveItem?.title
            ?? (activeParsed.title.isNotEmpty ? activeParsed.title : widget.file.name);
        final displayArtist = activeMeta?.artistName
            ?? (liveItem?.artist?.isNotEmpty == true ? liveItem!.artist! : null)
            ?? (activeParsed.artist.isNotEmpty ? activeParsed.artist : 'Unknown');
        final artists = ItunesTrack.splitArtists(displayArtist);

        final displayArtwork = (activeMeta?.artworkUrlHigh?.isNotEmpty == true)
            ? activeMeta!.artworkUrlHigh!
            : (activeMeta?.artworkUrlLow?.isNotEmpty == true)
                ? activeMeta!.artworkUrlLow!
                : (liveItem?.artUri != null)
                    ? liveItem!.artUri.toString()
                    : (widget.initialArtwork?.isNotEmpty == true)
                        ? widget.initialArtwork!
                        : '';

        // Genre from metadata or live player extras
        final displayGenre = activeMeta?.genre
            ?? (liveItem?.extras?['genre'] as String?);

        // Filename / size: prefer live extras, fall back to widget.file
        final displayFilename = liveItem?.title ?? widget.file.name;
        final displaySize = widget.file.formattedSize;

        final format = _detectedFormat();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Song Info',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white,
                          fontWeight: FontWeight.bold,),
                      ),
                      if (_isFetching)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text('Fix Metadata'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close the sheet
                      widget.onCloseLyrics?.call(); // Close lyrics if open
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => MetadataPickerSheet(
                          file: widget.file,
                          initialQuery: displayTitle,
                          initialArtist: displayArtist,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Title', displayTitle),
                ...artists.asMap().entries.map((entry) => _buildInfoRow(
                  entry.key == 0 ? 'Artist' : '', 
                  entry.value,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArtistScreen(artistName: entry.value)),
                    );
                  },
                )),
                if (activeMeta?.album != null) _buildInfoRow('Album', _cleanAlbumName(activeMeta!.album!)),
                if (displayGenre != null) _buildInfoRow('Genre', displayGenre),
                _buildInfoRow('Format', format),
                _buildInfoRow('Filename', displayFilename),
                _buildInfoRow('Size', displaySize),
                const SizedBox(height: 12),
                if (displayArtwork.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: displayArtwork,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54,),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onTap != null ? Theme.of(context).colorScheme.primary : Colors.white,
                  fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal,),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes > 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }
}

class _SourceSheet extends ConsumerStatefulWidget {
  final String title;
  final String artist;
  final int activeFileId;
  final int activeTorrentId;

  const _SourceSheet({
    required this.title,
    required this.artist,
    required this.activeFileId,
    required this.activeTorrentId,
  });

  @override
  ConsumerState<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends ConsumerState<_SourceSheet> {
  List<TorBoxFile> _libraryMatches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    // 1. Check Library
    final libraryResults = ref.read(libraryProvider.notifier).findMatches(widget.title, widget.artist);
    
    // 2. Trigger FLAC search
    final query = '${widget.artist} ${widget.title}'.trim();
    ref.read(flacSearchProvider.notifier).search(query, force: force);

    if (mounted) {
      setState(() {
        _libraryMatches = libraryResults;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(libraryProvider.select((s) => s.downloadError), (previous, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ),
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flacState = ref.watch(flacSearchProvider);
    final isSearching = flacState.isLoading;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Always dark
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Source',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (isSearching)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                        onPressed: () => _fetchSources(force: true),
                      ),
                  ],
                ),
                if (flacState.results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        AppleMusicChip(
                          label: 'All',
                          isSelected: flacState.selectedSource == 'All' || flacState.selectedSource == null,
                          isDarkOverride: true,
                          onTap: () {
                            ref.read(flacSearchProvider.notifier).setSource('All');
                          },
                        ),
                        ...flacState.availableSources.map((source) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: AppleMusicChip(
                            label: source,
                            isSelected: flacState.selectedSource == source,
                            isDarkOverride: true,
                            onTap: () {
                              ref.read(flacSearchProvider.notifier).setSource(source);
                            },
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (_libraryMatches.isNotEmpty) ...[
                  _buildSectionHeader('YOUR LIBRARY'),
                  ..._libraryMatches.map(_buildLibraryTile),
                ],
                if (flacState.filteredResults.isNotEmpty) ...[
                  _buildSectionHeader('EXTERNAL SOURCES'),
                  ...flacState.filteredResults.map(_buildTidalTile),
                ],
                if (!isSearching && _libraryMatches.isEmpty && flacState.filteredResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('No other sources found', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildLibraryTile(TorBoxFile file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = file.id == widget.activeFileId && file.torrentId == widget.activeTorrentId;
    final meta = ref.read(libraryProvider).metadata['${file.torrentId}-${file.id}'];
    final parsed = parseFilename(file.displayName);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.library_music, color: isDark ? Colors.white54 : Colors.black45, size: 20),
      ),
      title: Text(
        meta?.trackName ?? parsed.title,
        style: TextStyle(color: isActive ? Theme.of(context).colorScheme.primary : Colors.white, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(
        '${_limitArtists(meta?.artistName ?? parsed.artist)} • Library • ${file.formattedSize}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,),
      ),
      trailing: isActive ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20) : null,
      onTap: isActive ? null : () => _switchSource(
        url: 'https://lazy.torbox.internal/${file.torrentId}/${file.id}',
        torrentId: file.torrentId,
        fileId: file.id,
        source: 'Library',
        duration: meta?.trackTimeMillis?.toString(),
      ),
    );
  }

  Widget _buildTidalTile(ScraperResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // For Tidal we don't have a stable ID easily without comparing URLs
    final currentUrl = audioHandler.mediaItem.value?.id;
    final isActive = currentUrl == result.url;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: result.thumbnail != null
            ? CachedNetworkImage(
                imageUrl: result.thumbnail!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        _unescapeHtml(result.title),
        style: TextStyle(color: isActive ? Theme.of(context).colorScheme.primary : Colors.white, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(
        '${result.artist.isNotEmpty ? "${_unescapeHtml(_limitArtists(result.artist))} • " : ""}${result.source} • ${result.format}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,),
      ),
      trailing: isActive ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20) : null,
      onTap: isActive ? null : () => _switchSource(
        url: result.url,
        torrentId: -1,
        fileId: result.url.hashCode,
        source: result.source,
        artworkUrl: result.thumbnail,
        linkType: result.linkType,
        duration: result.duration,
        extras: result.extras,
      ),
    );
  }

  Widget _placeholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
      child: Icon(Icons.music_note, color: isDark ? Colors.white54 : Colors.black45, size: 20),
    );
  }

  String _limitArtists(String artist) {
    if (artist.isEmpty) return artist;
    final parts = artist.split(RegExp(r'\s*(?:,|\s+&\s+|\s+and\s+)\s*'));
    if (parts.length > 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return artist;
  }

  Future<void> _switchSource({
    required String url,
    required int torrentId,
    required int fileId,
    required String source,
    String? artworkUrl,
    String? linkType,
    String? duration,
    Map<String, dynamic>? extras,
  }) async {
    String finalUrl = url;

    // URL will be resolved internally by AudioHandler
    if (linkType == 'youtube') {
       finalUrl = url;
    }

    Navigator.pop(context);
    
    final currentMedia = audioHandler.mediaItem.value;
    if (currentMedia == null) return;

    await audioHandler.customAction('play', {
      'url': finalUrl,
      'title': currentMedia.title,
      'artist': currentMedia.artist,
      'artworkUrl': artworkUrl ?? currentMedia.artUri?.toString() ?? '',
      'duration': duration,
      'replaceCurrent': true,
      'extras': {
        'torrentId': torrentId,
        'fileId': fileId,
        'source': source,
        'linkType': linkType,
        ...?extras,
      },
    });

    // Persistent update for playlist tracks
    final activeFileId = (currentMedia.extras?['fileId'] as num?)?.toInt();
    final activeTorrentId = (currentMedia.extras?['torrentId'] as num?)?.toInt();
    
    // In Isai, playlist tracks often use negative IDs to distinguish from library files
    if (activeTorrentId == -1 && activeFileId != null && activeFileId < 0) {
      final playlistTrackId = activeFileId.abs();
      if (linkType == 'youtube' || linkType == 'soundcloud') {
        final ytId = (extras?['youtubeId'] as String?) ?? (extras?['track_id'] as String?) ?? url;
        try {
          print('[NowPlayingScreen] _switchSource: Updating database for playlist track $playlistTrackId with new source $ytId');
          await ref.read(playlistProvider.notifier).updatePlaylistTrackSource(playlistTrackId, ytId);
        } catch (e) {
          print('[NowPlayingScreen] _switchSource: Failed to update DB: $e');
        }
      }
    }

    if (!mounted) return;
  }
}

String _unescapeHtml(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}



// ─── Helpers ─────────────────────────────────────────────────────────────────

// ({String title, String artist}) _parseFilename(String displayName) {
//   var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
//   name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');
//   final match = RegExp(r' [-–] ').firstMatch(name);
//   if (match != null) {
//     return (
//       artist: name.substring(0, match.start).trim(),
//       title: name.substring(match.end).trim(),
//     );
//   }
//   return (title: name.trim(), artist: '');
// }

String _cleanAlbumName(String album) {
  return album
    .replaceAll(RegExp(r'\[.*?\]'), '')
    .replaceAll(RegExp(r'\(.*?\)'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
}

class _QueueBottomSheet extends ConsumerStatefulWidget {
  const _QueueBottomSheet();
  @override
  ConsumerState<_QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends ConsumerState<_QueueBottomSheet> {
  String _selectedChip = 'All';
  bool _isLoading = false;
  final List<String> _chips = ['All', 'Familiar', 'Discover', 'Popular', 'Deep cuts'];

  Future<void> _onChipSelected(String chip) async {
    if (_selectedChip == chip) return;
    setState(() {
      _selectedChip = chip;
      _isLoading = true;
    });

    try {
      final currentItem = audioHandler.mediaItem.value;
      if (currentItem != null && chip != 'All') {
        if (chip == 'Discover') {
          // Use last 5 played songs + current song to build better seeds
          final db = getIt<AppDatabase>();
          final recentHistory = await db.getRecentPlaybackUnique(limit: 5);
          
          // Collect unique artists from recent history (split multi-artist)
          final Set<String> seedArtists = {};
          for (final h in recentHistory) {
            if (h.artist.isNotEmpty) {
              final parts = h.artist.split(RegExp(r'\s*(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false))
                  .expand((p) => p.split(RegExp(r'\s*[,&]\s*')))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty && s.length > 1);
              seedArtists.addAll(parts);
            }
          }
          // Also add current artist
          if (currentItem.artist != null && currentItem.artist!.isNotEmpty) {
            final parts = currentItem.artist!.split(RegExp(r'\s*(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false))
                .expand((p) => p.split(RegExp(r'\s*[,&]\s*')))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty && s.length > 1);
            seedArtists.addAll(parts);
          }

          final List<ItunesTrack> allRecommendations = [];
          final Set<String> seen = {};

          // 1. Try Last.fm similar tracks for the most recent songs
          final lastfm = getIt<LastFmService>();
          for (final h in recentHistory.take(2)) {
            try {
              final similar = await lastfm.getSimilarTracks(h.trackTitle, h.artist, limit: 8);
              for (final t in similar) {
                final key = '${t['name']}|${t['artist']}'.toLowerCase();
                if (!seen.contains(key)) {
                  seen.add(key);
                  allRecommendations.add(ItunesTrack(
                    trackId: key.hashCode,
                    trackName: t['name'] as String,
                    artistName: t['artist'] as String,
                    collectionName: '',
                    artworkUrl: '',
                  ));
                }
              }
            } catch (_) {}
          }

          // 2. Get Deezer radio for seed artists
          final deezer = getIt<DeezerService>();
          for (final artist in seedArtists.take(3)) {
            try {
              final deezerArtist = await deezer.searchArtist(artist);
              if (deezerArtist != null) {
                final radio = await deezer.getArtistRadio(deezerArtist['id'].toString());
                for (final t in radio.take(5)) {
                  final a = t['artist'] as Map<String, dynamic>? ?? {};
                  final album = t['album'] as Map<String, dynamic>? ?? {};
                  final name = t['title'] as String? ?? '';
                  final artistName = a['name'] as String? ?? '';
                  final key = '$name|$artistName'.toLowerCase();
                  if (!seen.contains(key) && name.isNotEmpty) {
                    seen.add(key);
                    allRecommendations.add(ItunesTrack(
                      trackId: (t['id'] as num?)?.toInt() ?? key.hashCode,
                      trackName: name,
                      artistName: artistName,
                      collectionName: album['title'] as String? ?? '',
                      artworkUrl: album['cover_big'] as String? ?? album['cover_medium'] as String? ?? '',
                    ));
                  }
                }
              }
            } catch (_) {}
          }

          // 3. Fallback to ReccoBeats if we don't have enough
          if (allRecommendations.length < 10) {
            try {
              final repo = getIt<MusicRepository>();
              final fallback = await repo.getRecommendedTracks(
                currentItem.title,
                currentItem.artist ?? '',
                'Discover',
              );
              for (final t in fallback) {
                final key = '${t.trackName}|${t.artistName}'.toLowerCase();
                if (!seen.contains(key)) {
                  seen.add(key);
                  allRecommendations.add(t);
                }
              }
            } catch (_) {}
          }

          allRecommendations.shuffle();
          final recommendations = allRecommendations.take(20).toList();

          if (recommendations.isNotEmpty) {
            final library = ref.read(libraryProvider);
            final items = recommendations.map((t) {
              final match = library.findMatchingTrack(t.trackName, t.artistName);
              final url = match != null 
                  ? 'https://lazy.torbox.internal/${match.torrentId}/${match.id}'
                  : 'https://lazy.flac.internal/?title=${Uri.encodeComponent(t.trackName)}&artist=${Uri.encodeComponent(t.artistName)}';
                   
              return {
                'url': url,
                'title': t.trackName,
                'artist': t.artistName,
                'artworkUrl': t.artworkUrl,
                'duration': t.trackTimeMillis != null ? Duration(milliseconds: t.trackTimeMillis!).toString() : null,
                'extras': match != null ? <String, dynamic>{
                   'torrentId': match.torrentId,
                   'fileId': match.id,
                   'size': match.size,
                   'localPath': match.localPath,
                } : <String, dynamic>{
                   'torrentId': -1,
                   'fileId': -(t.trackId != 0 ? t.trackId : ('${t.trackName}|${t.artistName}'.hashCode)).abs(),
                },
              };
            }).toList();
            await audioHandler.customAction('updateUpNext', {'items': items});
          }
        } else {
          // Other chips: Familiar, Popular, Deep cuts — use existing logic
          final repo = getIt<MusicRepository>();
          final recommendations = await repo.getRecommendedTracks(
            currentItem.title,
            currentItem.artist ?? '',
            chip,
          );
          
          if (recommendations.isNotEmpty) {
             final library = ref.read(libraryProvider);
             final items = recommendations.map((t) {
               final match = library.findMatchingTrack(t.trackName, t.artistName);
               final url = match != null 
                   ? 'https://lazy.torbox.internal/${match.torrentId}/${match.id}'
                   : 'https://lazy.flac.internal/?title=${Uri.encodeComponent(t.trackName)}&artist=${Uri.encodeComponent(t.artistName)}';
                    
               return {
                 'url': url,
                 'title': t.trackName,
                 'artist': t.artistName,
                 'artworkUrl': t.artworkUrl,
                 'duration': t.trackTimeMillis != null ? Duration(milliseconds: t.trackTimeMillis!).toString() : null,
                 'extras': match != null ? <String, dynamic>{
                    'torrentId': match.torrentId,
                    'fileId': match.id,
                    'size': match.size,
                    'localPath': match.localPath,
                } : <String, dynamic>{
                    'torrentId': -1,
                    'fileId': -(t.trackId != 0 ? t.trackId : ('${t.trackName}|${t.artistName}'.hashCode)).abs(),
                },
               };
             }).toList();
             await audioHandler.customAction('updateUpNext', {'items': items});
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppleMusicTheme.darkSurface, 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 24, right: 24),
            child: Row(
              children: [
                 Text('Up Next', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(width: 8),
                 StreamBuilder<PlaybackState>(
                   stream: audioHandler.playbackState,
                   builder: (context, snapshot) {
                     final isShuffled = snapshot.data?.shuffleMode != AudioServiceShuffleMode.none;
                     return IconButton(
                       icon: Icon(
                         Icons.shuffle_rounded,
                         color: isShuffled ? Theme.of(context).colorScheme.primary : Colors.white54,
                         size: 20,
                       ),
                       constraints: const BoxConstraints(),
                       padding: const EdgeInsets.all(4),
                       onPressed: () {
                         audioHandler.customAction('shuffle');
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text(isShuffled ? 'Shuffle Disabled' : 'Queue Shuffled'),
                             duration: const Duration(seconds: 1),
                             behavior: SnackBarBehavior.floating,
                             width: 150,
                           ),
                         );
                       },
                     );
                   },
                 ),
                 const Spacer(),
                 StreamBuilder<MediaItem?>(
                   stream: audioHandler.mediaItem,
                   builder: (context, snap) {
                     final track = snap.data;
                     if (track == null) return const SizedBox();
                     return Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Text('Playing from', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54,)),
                           Text(
                             track.artist ?? 'Library', 
                             maxLines: 1, 
                             overflow: TextOverflow.ellipsis, 
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)
                           ),
                         ]
                       )
                     );
                   }
                 )
              ]
            )
          ),
          // Chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _chips.length,
              itemBuilder: (context, i) {
                final chip = _chips[i];
                final isSelected = _selectedChip == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(chip),
                    selected: isSelected,
                    onSelected: (_) => _onChipSelected(chip),
                    backgroundColor: AppleMusicTheme.darkCard,
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,),
                    side: BorderSide(
                      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
              : StreamBuilder<List<MediaItem>>(
                  stream: audioHandler.queue,
                  builder: (context, snapshot) {
                    final queue = snapshot.data ?? [];
                    return StreamBuilder<MediaItem?>(
                      stream: audioHandler.mediaItem,
                      builder: (context, mediaSnap) {
                        final currentId = mediaSnap.data?.id;
                        return ReorderableListView.builder(
                          itemCount: queue.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            if (audioHandler is MyAudioHandler) {
                              (audioHandler as MyAudioHandler).moveQueueItem(oldIndex, newIndex);
                            }
                          },
                          itemBuilder: (context, i) {
                            final item = queue[i];
                            final isCurrent = currentId == item.id;
                            
                            // Visual divider between current track and upcoming
                            final isNext = !isCurrent && i > 0 && queue[i-1].id == currentId;
                            
                            return Column(
                              key: ValueKey('queue-item-${item.id}-$i'),
                              children: [
                                if (isNext)
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('UPCOMING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                                    )
                                  ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: item.artUri != null
                                        ? CachedNetworkImage(
                                            imageUrl: item.artUri!.toString(),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 100,
                                            errorWidget: (_, __, ___) => _artworkPlaceholder(size: 48, iconSize: 24),
                                          )
                                        : _artworkPlaceholder(size: 48, iconSize: 24),
                                  ),
                                  title: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.artist ?? 'Unknown Artist', 
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54,)
                                  ),
                                  trailing: isCurrent 
                                    ? Icon(Icons.equalizer, color: Theme.of(context).colorScheme.primary) 
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              (audioHandler as MyAudioHandler).removeQueueItemAt(i);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Icon(Icons.close, size: 16, color: Colors.white54),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.drag_handle, color: Colors.white24),
                                        ],
                                      ),
                                  onTap: () {
                                    audioHandler.skipToQueueItem(i);
                                    Navigator.pop(context);
                                  },
                                ),
                              ]
                            );
                          },
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _artworkPlaceholder({required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      color: Colors.white10,
      child: Icon(Icons.music_note, color: Colors.white54, size: iconSize),
    );
  }
}

class _SleepTimerSheet extends StatefulWidget {
  final bool isActive;
  final bool isEndOfTrackActive;
  final DateTime? remainingEnd;
  final void Function(Duration) onSet;
  final VoidCallback onCancel;

  const _SleepTimerSheet({
    required this.isActive,
    required this.isEndOfTrackActive,
    required this.remainingEnd,
    required this.onSet,
    required this.onCancel,
  });

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  static const _presetDurations = [
    (label: '15 minutes', duration: Duration(minutes: 15)),
    (label: '30 minutes', duration: Duration(minutes: 30)),
    (label: '45 minutes', duration: Duration(minutes: 45)),
    (label: '1 hour', duration: Duration(hours: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151419),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header: Circular icon + text (SLEEP TIMER / Pick a duration)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2C221E),
                    ),
                    child: const Center(
                      child: Icon(Icons.bedtime, color: Color(0xFFE58043), size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SLEEP TIMER',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
                            color: Colors.orange[300],
                            letterSpacing: 1.2,),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a duration',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
                            color: Colors.white,),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            // Active remaining time display if a timed sleep timer is running
            if (widget.isActive && widget.remainingEnd != null) ...[
              StreamBuilder<DateTime>(
                stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                builder: (_, __) {
                  final remaining = widget.remainingEnd!.difference(DateTime.now());
                  if (remaining.isNegative) return const SizedBox.shrink();
                  final h = remaining.inHours;
                  final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
                  final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Remaining time: ${h > 0 ? "${h}h " : ""}$m:$s',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ] else if (widget.isEndOfTrackActive) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Active: Stops at end of current track',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],

            // Presets
            ..._presetDurations.map((preset) => ListTile(
              leading: const Icon(Icons.access_time_rounded, color: Colors.white54),
              title: Text(
                preset.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w400),
              ),
              onTap: () => widget.onSet(preset.duration),
            )),

            // End of current track
            ListTile(
              leading: const Icon(Icons.music_note_rounded, color: Colors.white54),
              title: Text(
                'End of current track',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w400),
              ),
              subtitle: Text(
                'Pauses the moment this song finishes',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38,),
              ),
              onTap: () => widget.onSet(Duration.zero),
            ),

            // Turn off timer button if any timer is active
            if (widget.isActive || widget.isEndOfTrackActive) ...[
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: Text(
                  'Turn off timer',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w500),
                ),
                onTap: widget.onCancel,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BounceButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class SpotifyCanvasBackground extends StatefulWidget {
  final String videoUrl;

  const SpotifyCanvasBackground({
    super.key,
    required this.videoUrl,
  });

  @override
  State<SpotifyCanvasBackground> createState() => _SpotifyCanvasBackgroundState();
}

class _SpotifyCanvasBackgroundState extends State<SpotifyCanvasBackground> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  StreamSubscription<PlaybackState>? _playbackSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    _playbackSubscription = audioHandler.playbackState.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        player.play();
      } else {
        player.pause();
      }
    });
  }

  @override
  void didUpdateWidget(SpotifyCanvasBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      player.open(Media(widget.videoUrl), play: audioHandler.playbackState.value.playing);
    }
  }

  void _initializePlayer() {
    player.setPlaylistMode(PlaylistMode.single);
    player.setVolume(0.0);
    player.open(Media(widget.videoUrl), play: true);
    
    // Double check state alignment
    if (!audioHandler.playbackState.value.playing) {
       player.pause();
    }
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Video(
        controller: controller,
        fit: BoxFit.cover,
        controls: NoVideoControls,
      ),
    );
  }
}
