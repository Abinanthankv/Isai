import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/plugins/plugin_manager.dart';
import '../../music/data/plugins/js_plugin.dart';
import '../../music/data/plugins/eclipse_addon.dart';
import '../../../core/di/injection.dart';
import '../../../core/database/database.dart';
import '../../music/data/music_models.dart';
import '../../music/data/itunes_metadata_service.dart';
import '../../youtube/data/youtube_video_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:drift/drift.dart';
import '../../music/data/lastfm_service.dart';
import '../../settings/data/lastfm_repository.dart';
import 'audio_metadata_service.dart';
import '../../audiobooks/data/audiobook_repository.dart';
import '../../audiobooks/data/audiobook_models.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  
  /// Expose the Android audio session ID for the native Visualizer API.
  /// Returns null on non-Android platforms.
  int? get androidAudioSessionIdSync => _player.androidAudioSessionId;
  double get volume => _player.volume;
  Stream<double> get volumeStream => _player.volumeStream;
  final _playlist = ConcatenatingAudioSource(children: []);
  final Set<int> _resolvingIndices = {}; // resolution lock
  final Map<String, MediaItem> _enrichedItems = {}; // cache to persist metadata across sequence updates
  late final String _cachePath;
  final _yt = YoutubeExplode();
  final _ytClients = [YoutubeApiClient.androidVr, YoutubeApiClient.android, YoutubeApiClient.ios];
  // Session-level URL cache: videoId → {url, expiry, contentLength, userAgent}
  final Map<String, ({String url, DateTime expiry, int? contentLength, String? userAgent})> _ytUrlCache = {};
  final Set<int> _metadataEnrichingIndices = {};
  bool _currentTrackRecorded = false;
  int _consecutiveFailures = 0; // Safeguard against skipping loops
  DateTime? _lastAudiobookSaveTime;
  DateTime? _lastAudiobookProcessTime;
  int _lastSavedPositionMs = 0;
  String? _currentAudiobookId;
  List<AudiobookChapter>? _currentAudiobookChapters;
  
  List<MediaItem> _originalItems = [];
  AudioServiceShuffleMode _shuffleModeState = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeatModeState = AudioServiceRepeatMode.none;
  bool _isCurrentTrackLiked = false;
  int _linuxIndex = 0;
  int _currentSongPlayCount = 1;
  int? _lastIndex;
  Duration? _lastKnownPosition;
  bool _isLoopingBack = false;

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Initialize cache path
    final cacheDir = await getTemporaryDirectory();
    _cachePath = '${cacheDir.path}/audio_cache';
    final dir = io.Directory(_cachePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 1. Set the initial empty playlist
    if (!io.Platform.isLinux) {
      await _player.setAudioSource(_playlist);
    }
    print('[AudioHandler] Initialized with cache at: $_cachePath');

    // 2. Listen for playback events (playing, position, buffered, processingState)
    _player.playbackEventStream.listen((_) {}, onError: (e) {
      print('[AudioHandler] PlaybackEvent ERROR: $e');
      // If a source error occurs, stop the player to avoid being stuck in "playing" state
      stop();
    });

    _player.processingStateStream.listen((state) async {
      print('[AudioHandler] ProcessingState: $state');
      if (state == ProcessingState.completed) {
        // Save progress for the last item as completed
        final item = mediaItem.value;
        if (item != null && item.extras?['mediaType'] == 'audiobook') {
          final bookId = item.extras?['bookId'] as String?;
          final chapterIndex = item.extras?['chapterIndex'] as int?;
          if (bookId != null && chapterIndex != null) {
            try {
              final repo = getIt<AudiobookRepository>();
              final duration = item.duration ?? Duration.zero;
              await repo.saveProgress(
                bookId: bookId,
                chapterIndex: chapterIndex,
                positionMillis: duration.inMilliseconds,
                durationMillis: duration.inMilliseconds,
                isCompleted: true,
              );
              print('[AudioHandler] ProcessingState.completed: saved audiobook progress as completed.');
            } catch (e) {
              print('[AudioHandler] Error saving audiobook progress on complete: $e');
            }
          }
        }

        if (io.Platform.isLinux) {
          await skipToNext();
        } else {
          pause();
          _player.seek(Duration.zero, index: 0);
        }
      }
    });

    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state);
    });

    mediaItem.listen((item) async {
      if (item != null) {
        final torrentId = (item.extras?['torrentId'] as num?)?.toInt();
        final fileId = (item.extras?['fileId'] as num?)?.toInt();
        if (torrentId != null && fileId != null) {
          try {
            final db = getIt<AppDatabase>();
            final file = await (db.select(db.trackMetadata)
                  ..where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId)))
                .getSingleOrNull();
            _isCurrentTrackLiked = file?.isLiked ?? false;
            playbackState.add(_transformEvent(_player.playbackEvent));
          } catch (_) {
            _isCurrentTrackLiked = false;
            playbackState.add(_transformEvent(_player.playbackEvent));
          }
        } else {
          _isCurrentTrackLiked = false;
          playbackState.add(_transformEvent(_player.playbackEvent));
        }
      } else {
        _isCurrentTrackLiked = false;
        playbackState.add(_transformEvent(_player.playbackEvent));
      }
    });

    // 3. Listen for duration changes and update metadata accordingly
    _player.durationStream.listen((duration) {
      if (duration != null && _player.currentIndex != null) {
        final current = mediaItem.value;
        final sequence = _player.sequence;
        final index = _player.currentIndex!;
        
        if (sequence != null && index < sequence.length) {
          final source = sequence[index];
          if (source.tag is! MediaItem) return;
          final tagItem = source.tag as MediaItem;
          
          // 1. Identify what to broadcast: prioritize current live metadata but add duration
          if (current != null && (current.id == tagItem.id || (current.extras?['fileId'] == tagItem.extras?['fileId'] && current.extras?['torrentId'] == tagItem.extras?['torrentId']))) {
            if (current.duration != duration) {
              mediaItem.add(current.copyWith(duration: duration));
            }
          } else {
            if (tagItem.duration != duration) {
              mediaItem.add(tagItem.copyWith(duration: duration));
            }
          }

          // 2. Update the queue broadcast so subsequent skips/UI lookups have the duration
          final currentQueue = List<MediaItem>.from(queue.value);
          if (index < currentQueue.length) {
            final queueItem = currentQueue[index];
            if (queueItem.duration != duration) {
              currentQueue[index] = queueItem.copyWith(duration: duration);
              queue.add(List.unmodifiable(currentQueue));
            }
          }
        }
      }
    });

    // Centralized Queue Syncing: Listen to sequence changes and update the queue subject

    // 4. Update recorded flag when mediaItem changes
    String? lastMediaItemId;
    mediaItem.listen((item) {
      if (item != null && item.id != lastMediaItemId) {
        lastMediaItemId = item.id;
        _currentTrackRecorded = false;
        print('[AudioHandler] New track detected: ${item.title}, resetting history recorded flag.');
        
        // Last.fm: Update Now Playing — GUARD: audiobooks must NOT scrobble
        final mediaType = item.extras?['mediaType'] as String? ?? 'music';
        if (mediaType == 'music') {
          final lfmRepo = getIt<LastfmRepository>();
          if (lfmRepo.isConnected && lfmRepo.scrobbleEnabled) {
            final lfmService = getIt<LastFmService>();
            lfmService.updateNowPlaying(item, lfmRepo.sessionKey!);
          }
        }
      }
    });

    // 5. Monitor position to record history after 50% progress
    _player.positionStream.listen((position) async {
       final item = mediaItem.value;
       if (item != null) {
         _lastKnownPosition = position;
         
          // Save audiobook progress — throttled to once per second
          final mediaType = item.extras?['mediaType'] as String? ?? 'music';
          if (mediaType == 'audiobook') {
            final now = DateTime.now();
            if (_lastAudiobookProcessTime != null &&
                now.difference(_lastAudiobookProcessTime!) < const Duration(seconds: 1)) {
              _lastKnownPosition = position;
              return;
            }
            _lastAudiobookProcessTime = now;

            final bookId = item.extras?['bookId'] as String?;
            final chapterIndex = item.extras?['chapterIndex'] as int?;
            
            int activeIndex = -1;
            if (bookId != null) {
              // Load/cache chapters list for real-time tracking if it changes
              if (_currentAudiobookId != bookId || _currentAudiobookChapters == null) {
                _currentAudiobookId = bookId;
                _currentAudiobookChapters = null;
                getIt<AudiobookRepository>().getBookChapters(bookId).then((chList) {
                  if (_currentAudiobookId == bookId) {
                    _currentAudiobookChapters = chList;
                  }
                });
              }

              final chapters = _currentAudiobookChapters;
              if (chapters != null && chapters.isNotEmpty) {
                final currentPosMs = position.inMilliseconds;
                // Binary search for current chapter
                int low = 0, high = chapters.length - 1;
                while (low <= high) {
                  final mid = (low + high) >> 1;
                  final start = chapters[mid].startTimeMillis;
                  if (currentPosMs < start) {
                    high = mid - 1;
                  } else {
                    final end = (mid + 1 < chapters.length)
                        ? chapters[mid + 1].startTimeMillis
                        : double.infinity;
                    if (currentPosMs < end) {
                      activeIndex = mid;
                      break;
                    }
                    low = mid + 1;
                  }
                }

                if (activeIndex != -1 && activeIndex != chapterIndex) {
                  final newChapter = chapters[activeIndex];
                  
                  // Mark the previous chapter as completed — fire and forget
                  if (chapterIndex != null) {
                    final repo = getIt<AudiobookRepository>();
                    final prevChapter = chapters[chapterIndex];
                    final prevStart = prevChapter.startTimeMillis;
                    final prevEnd = (chapterIndex + 1 < chapters.length)
                        ? chapters[chapterIndex + 1].startTimeMillis
                        : (item.duration?.inMilliseconds ?? prevStart);
                    final prevDuration = prevEnd - prevStart;
                    
                    repo.saveProgress(
                      bookId: bookId,
                      chapterIndex: chapterIndex,
                      positionMillis: prevEnd.toInt(),
                      durationMillis: item.duration?.inMilliseconds ?? 0,
                      isCompleted: true,
                    ).catchError((_) {});
                  }

                  final updatedItem = item.copyWith(
                    title: newChapter.title,
                    extras: {
                      ...item.extras ?? {},
                      'chapterIndex': activeIndex,
                    },
                  );
                  mediaItem.add(updatedItem);
                  print('[AudioHandler] Chapter changed automatically to index $activeIndex: "${newChapter.title}"');
                }
              }
            }

            final targetChapterIndex = (activeIndex != -1) ? activeIndex : chapterIndex;
            if (bookId != null && targetChapterIndex != null) {
              final posMs = position.inMilliseconds;
              final isFirstSave = _lastAudiobookSaveTime == null;
              final timeSinceLastSave = isFirstSave ? Duration.zero : now.difference(_lastAudiobookSaveTime!);
              final posDiff = (posMs - _lastSavedPositionMs).abs();
              final isManualSeek = posDiff > 10000;
              
              if (!isFirstSave && !isManualSeek && timeSinceLastSave < const Duration(minutes: 5)) {
                // Skip — save periodically every 5 minutes unless a manual seek occurred
              } else {
                _lastAudiobookSaveTime = now;
                _lastSavedPositionMs = posMs;
                final repo = getIt<AudiobookRepository>();
                
                bool isCompleted = false;
                final chapters = _currentAudiobookChapters;
                if (chapters != null && chapters.isNotEmpty && targetChapterIndex < chapters.length) {
                  final ch = chapters[targetChapterIndex];
                  final start = ch.startTimeMillis;
                  final end = (targetChapterIndex + 1 < chapters.length)
                      ? chapters[targetChapterIndex + 1].startTimeMillis
                      : (item.duration?.inMilliseconds ?? start);
                  final chDuration = end - start;
                  final relativePos = posMs - start;
                  if (chDuration > 0 && relativePos >= chDuration - 5000) {
                    isCompleted = true;
                  }
                } else {
                  final duration = item.duration ?? Duration.zero;
                  if (duration.inMilliseconds > 0 && posMs >= duration.inMilliseconds - 5000) {
                    isCompleted = true;
                  }
                }

                // Fire and forget — don't block position stream
                repo.saveProgress(
                  bookId: bookId,
                  chapterIndex: targetChapterIndex,
                  positionMillis: posMs,
                  durationMillis: item.duration?.inMilliseconds ?? 0,
                  isCompleted: isCompleted,
                ).catchError((_) {});
              }
            }
         }
       }
        if (item == null || _currentTrackRecorded || item.duration == null || item.duration! == Duration.zero) return;

        final double progress = position.inMilliseconds / item.duration!.inMilliseconds;
        final lfmRepo = getIt<LastfmRepository>();
        final scrobbleThreshold = lfmRepo.scrobblePercentage / 100.0;

        if (progress >= scrobbleThreshold) {
          _currentTrackRecorded = true;
          
          final torrentId = (item.extras?['torrentId'] as num?)?.toInt();
          final fileId = (item.extras?['fileId'] as num?)?.toInt();
          
          // GUARD: Only record playback history for music, not audiobooks
          final mediaType = item.extras?['mediaType'] as String? ?? 'music';
          if (mediaType == 'audiobook') {
            print('[AudioHandler] Audiobook chapter — skipping music history recording.');
            // Future: save audiobook progress here via AudiobookRepository
            return;
          }
          
          if (torrentId != null && fileId != null) {
            print('[AudioHandler] Progress reached ${ (progress * 100).toStringAsFixed(0) }%. Recording playback for "${item.title}"');
            
            final repo = getIt<MusicRepository>();
            final db = getIt<AppDatabase>();
            
            try {
              final dbMeta = await db.getTrackMetadata(torrentId, fileId);
              final meta = dbMeta != null ? ItunesMeta(
                trackName: dbMeta.trackTitle,
                artistName: dbMeta.artist,
                album: dbMeta.album,
                genre: dbMeta.genre,
              ) : ItunesMeta(
                trackName: item.title,
                artistName: item.artist,
              );

              final torBoxFile = TorBoxFile(
                id: fileId,
                torrentId: torrentId,
                name: item.title,
                size: 0,
                localPath: item.extras?['localPath'],
              );

              await repo.recordPlayback(
                torBoxFile, 
                meta,
                artworkUrlLow: item.artUri?.toString(),
                artworkUrlHigh: item.artUri?.toString(),
                duration: item.duration?.inSeconds,
              );
             } catch (e) {
               print('[AudioHandler] Error recording playback: $e');
             }

            // Last.fm: Submit Scrobble — GUARD: audiobooks already returned above
            final minDurationSec = lfmRepo.minScrobbleMinutes * 60;
            final trackDurationSec = item.duration!.inSeconds;
            if (lfmRepo.isConnected && lfmRepo.scrobbleEnabled && trackDurationSec >= minDurationSec) {
              final lfmService = getIt<LastFmService>();
              lfmService.scrobble(item, lfmRepo.sessionKey!);
            }
          }
        }
    });

    _player.currentIndexStream.listen((index) async {
      if (io.Platform.isLinux) return;

      if (_isLoopingBack) {
        _isLoopingBack = false;
        _lastIndex = index;
        return;
      }

      final repeatMode = playbackState.value.repeatMode;
      if (index != null && _lastIndex != null && index != _lastIndex) {
        // Save progress for the track we just left if it is an audiobook
        final sequence = _player.sequence;
        if (sequence != null && _lastIndex! < sequence.length) {
          final prevSource = sequence[_lastIndex!];
          if (prevSource.tag is MediaItem) {
            final prevItem = prevSource.tag as MediaItem;
            if (prevItem.extras?['mediaType'] == 'audiobook') {
              final bookId = prevItem.extras?['bookId'] as String?;
              final chapterIndex = prevItem.extras?['chapterIndex'] as int?;
              if (bookId != null && chapterIndex != null) {
                try {
                  final repo = getIt<AudiobookRepository>();
                  final prevDuration = prevItem.duration ?? Duration.zero;
                  final lastPos = _lastKnownPosition ?? prevDuration;
                  
                  // If we transitioned to the next track naturally or were near the end, mark completed
                  final isCompleted = prevDuration.inMilliseconds > 0 &&
                      (lastPos.inMilliseconds >= prevDuration.inMilliseconds - 10000 || index > _lastIndex!);

                  await repo.saveProgress(
                    bookId: bookId,
                    chapterIndex: chapterIndex,
                    positionMillis: isCompleted ? prevDuration.inMilliseconds : lastPos.inMilliseconds,
                    durationMillis: prevDuration.inMilliseconds,
                    isCompleted: isCompleted,
                  );
                  print('[AudioHandler] Playlist transition: saved previous chapter $chapterIndex progress. Completed: $isCompleted');
                } catch (e) {
                  print('[AudioHandler] Error saving previous chapter progress on index transition: $e');
                }
              }
            }
          }
        }

        if (repeatMode == AudioServiceRepeatMode.one && _currentSongPlayCount < 2) {
          final lastPosition = _lastKnownPosition;
          final lastDuration = mediaItem.value?.duration;
          final wasAutoTransition = lastPosition != null && lastDuration != null &&
              (lastPosition >= lastDuration - const Duration(seconds: 2));

          if (wasAutoTransition) {
            _currentSongPlayCount++;
            _isLoopingBack = true;
            _lastKnownPosition = null;
            await _player.seek(Duration.zero, index: _lastIndex);
            return;
          }
        }
        _currentSongPlayCount = 1;
      }
      _lastIndex = index;

      _isCurrentTrackLiked = false; // Reset immediately to prevent visual like state leaking from previous track
      final sequence = _player.sequence;
      if (index == null || sequence == null || index >= sequence.length) return;

      final source = sequence[index];
      if (source.tag is! MediaItem) return;
      var tagItem = source.tag as MediaItem;

      try {
        final originalId = tagItem.extras?['originalId'] as String? ?? tagItem.id;
        final cached = _enrichedItems[originalId];
        if (cached != null) {
          tagItem = tagItem.copyWith(
            title: cached.title,
            artist: cached.artist,
            album: cached.album,
            artUri: cached.artUri ?? tagItem.artUri,
            duration: cached.duration ?? tagItem.duration,
            extras: {
              ...tagItem.extras ?? {},
              ...cached.extras ?? {},
            },
          );
        }

        print('[AudioHandler] Current track index: $index, title: "${tagItem.title}", extras: ${tagItem.extras}');
        
        // Proactively enrich from DB if available (e.g. from search/iTunes)
        final torrentId = (tagItem.extras?['torrentId'] as num?)?.toInt();
        final fileId = (tagItem.extras?['fileId'] as num?)?.toInt();
        MediaItem broadcastItem = tagItem;
        
        if (torrentId != null && fileId != null) {
          final db = getIt<AppDatabase>();
          // 1. Check external metadata cache (typically has higher quality info and artwork)
          final cacheKey = torrentId == -1 ? fileId.abs().toString() : '${tagItem.title}|${tagItem.artist}';
          final extMeta = await db.getExternalTrackMetadata(cacheKey);
          
          if (extMeta != null) {
            final hasValidArtist = tagItem.artist != null && 
                                   tagItem.artist!.toLowerCase() != 'torbox' && 
                                   tagItem.artist!.toLowerCase() != 'unknown' && 
                                   tagItem.artist!.isNotEmpty;
            final hasValidTitle = tagItem.title.isNotEmpty && 
                                  tagItem.title.toLowerCase() != 'unknown';
            broadcastItem = tagItem.copyWith(
              title: hasValidTitle ? tagItem.title : extMeta.trackTitle,
              artist: hasValidArtist ? tagItem.artist : extMeta.artist,
              artUri: extMeta.artworkUrlHigh != null 
                  ? parseArtworkUri(extMeta.artworkUrlHigh!) 
                  : (extMeta.artworkUrlLow != null ? parseArtworkUri(extMeta.artworkUrlLow!) : tagItem.artUri),
              album: extMeta.album ?? tagItem.album,
            );
          } else {
            // 2. Fallback to standard track metadata
            final dbMeta = await db.getTrackMetadata(torrentId, fileId);
            if (dbMeta != null) {
              final hasValidArtist = tagItem.artist != null && 
                                     tagItem.artist!.toLowerCase() != 'torbox' && 
                                     tagItem.artist!.toLowerCase() != 'unknown' && 
                                     tagItem.artist!.isNotEmpty;
              final hasValidTitle = tagItem.title.isNotEmpty && 
                                    tagItem.title.toLowerCase() != 'unknown';
              broadcastItem = tagItem.copyWith(
                title: hasValidTitle ? tagItem.title : (dbMeta.trackTitle ?? tagItem.title),
                artist: hasValidArtist ? tagItem.artist : (dbMeta.artist ?? tagItem.artist),
                artUri: (dbMeta.artworkUrlHigh != null && dbMeta.artworkUrlHigh!.isNotEmpty) 
                   ? parseArtworkUri(dbMeta.artworkUrlHigh!) 
                   : (dbMeta.artworkUrlLow != null && dbMeta.artworkUrlLow!.isNotEmpty) 
                       ? parseArtworkUri(dbMeta.artworkUrlLow!) 
                       : tagItem.artUri,
              );
            }
          }
        }
        
        // Merge with current mediaItem's duration if it's already known (avoid flicker)
        final current = mediaItem.value;
        if (current != null && current.id == broadcastItem.id && current.duration != null) {
          broadcastItem = broadcastItem.copyWith(duration: current.duration);
        }
        
        // Cache the latest broadcastItem
        _enrichedItems[originalId] = broadcastItem;
        
        mediaItem.add(broadcastItem);
        // Nudge playbackState for notification refresh
        playbackState.add(_transformEvent(_player.playbackEvent));

        // Recording handled by mediaItem listener above

        // --- 4a. Handle Current Track (if lazy) ---
        final isLazy = tagItem.id.contains('lazy.torbox.internal') || 
                       tagItem.id.contains('lazy.flac.internal') || 
                       tagItem.id.contains('lazy.plugin.internal') ||
                       (tagItem.extras?['linkType'] == 'soundcloud' && !tagItem.id.startsWith('http'));

        if (isLazy) {
          print('[AudioHandler] Stalling to resolve current track: $index');
          // Pause immediately to prevent just_audio from error-skipping to the next track
          final wasPlaying = _player.playing;
          await _player.pause();
          
          // If already resolving this index, wait for it to finish
          if (_resolvingIndices.contains(index)) {
            print('[AudioHandler] Resolution already in progress for $index, waiting...');
            while (_resolvingIndices.contains(index)) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
            // After waiting, check if position changed: the track may have been hot-swapped
            if (wasPlaying) _player.play();
            return; // Don't double-skip
          }
          
          final resolved = await _resolveTrack(index);
          if (resolved) {
            _consecutiveFailures = 0; // Reset on success
            if (wasPlaying) _player.play();
          } else {
            _consecutiveFailures++;
            print('[AudioHandler] Resolution failed for track $index (Failure Count: $_consecutiveFailures).');
            
            if (_consecutiveFailures >= 5) {
              print('[AudioHandler] Too many consecutive failures. Stopping to prevent loop.');
              _consecutiveFailures = 0;
              await stop();
              return;
            }

            // Remove FIRST so the index doesn't shift after seek
            try {
              await _playlist.removeAt(index);
            } catch (e) {
              print('[AudioHandler] Error removing failed track: $e');
            }
            
            // Then seek if there's something next (now at the same index due to removal)
            final currentLen = _playlist.length;
            if (currentLen > 0 && index < currentLen) {
              await _player.seek(Duration.zero, index: index);
              if (wasPlaying) _player.play();
            } else if (_player.hasNext) {
              await _player.seekToNext();
              if (wasPlaying) _player.play();
            } else {
              await stop();
            }
          }
        }
        
        // Skip all background enrichment/prefetch for audiobooks - chapters are sequential, not random
        final isAudiobook = tagItem.extras?['mediaType'] == 'audiobook' || broadcastItem.extras?['mediaType'] == 'audiobook';
        if (!isAudiobook) {
          // Fetch real extended metadata (bitrate, samplerate)
          _fetchExtendedMetadata(index);
          // --- 4c. Pre-fetch Next Track FULLY ---
          _prefetchNext(index);
          // --- 4d. Enrich Metadata for Upcoming Queue ---
          _enrichQueueInRange(index);
          // --- 4e. Dynamic/Autoplay Queue Extension ---
          _checkAndExtendQueue(index);
        }
      } catch (e) {
        print('[AudioHandler] Error in currentIndexStream: $e');
      }
    });

    // 5. Update queue when playlist changes
    _player.sequenceStream.listen((sequence) {
      if (io.Platform.isLinux) return;
      if (sequence == null) return;
      final items = sequence
          .map((s) => s.tag as MediaItem?)
          .where((item) => item != null)
          .cast<MediaItem>()
          .map((item) {
            final originalId = item.extras?['originalId'] as String? ?? item.id;
            final enriched = _enrichedItems[originalId];
            if (enriched != null) {
              // Merge duration just in case sequence has a better one
              return enriched.copyWith(duration: item.duration ?? enriched.duration);
            }
            return item;
          })
          .toList();
      queue.add(items);
    });
  }

  /// Proactively resolve and start pre-caching the next track in the queue.
  Future<void> _prefetchNext(int currentIndex) async {
    final sequence = _player.sequence;
    if (sequence == null) return;
    
    final nextIndex = currentIndex + 1;
    if (nextIndex >= sequence.length) return;

    final nextSource = sequence[nextIndex];
    final nextItem = nextSource.tag as MediaItem?;
    if (nextItem == null) return;
    
    // Check if it's already in cache or local
    final torrentId = nextItem.extras?['torrentId'];
    final fileId = nextItem.extras?['fileId'];
    final localPath = nextItem.extras?['localPath'] as String?;
    if (localPath != null && io.File(localPath).existsSync()) {
      print('[AudioHandler] Next track already local, skip prefetch: $localPath');
      return;
    }

    // 1.5 Check connectivity before remote pre-fetch
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty;
    
    if (isOffline) {
      print('[AudioHandler] Offline, skipping remote prefetch for: ${nextItem.title}');
      return;
    }

    // 1. If it's a lazy track, resolve it first
    final isLazy = nextItem.id.contains('lazy.torbox.internal') || 
                   nextItem.id.contains('lazy.flac.internal') || 
                   nextItem.id.contains('lazy.plugin.internal') ||
                   (nextItem.extras?['linkType'] == 'soundcloud' && !nextItem.id.startsWith('http'));

    if (isLazy) {
      if (!_resolvingIndices.contains(nextIndex)) {
        print('[AudioHandler] Pre-resolving next lazy track: $nextIndex');
        await _resolveTrack(nextIndex);
      } else {
        return; // Already being handled
      }
    }

    // 2. Start buffering the next track's cache.
    // LockCachingAudioSource will start downloading automatically when initialized.
    // Since it's already in the ConcatenatingAudioSource, just_audio might 
    // already be pre-buffering it slightly, but we want to ensure the CACHE 
    // is being populated.
    // However, just_audio's internal preloading usually handles the next item.
    // To explicitly force a full "cache download" for the next song without 
    // clicking play, we don't necessarily need more code if LockCachingAudioSource 
    // is already the source. 
    // But we should verify if we need to manually trigger a load. 
    // Actually, setting it as the source is usually enough for the internal player to start pre-buffering.
  }

  /// Enrich metadata for the current and next few tracks in the queue.
  Future<void> _enrichQueueInRange(int currentIndex) async {
    final currentQueue = queue.value;
    if (currentQueue.isEmpty) return;

    // Enrich current and next 8 tracks for smoother background playback
    final end = (currentIndex + 9).clamp(0, currentQueue.length);
    for (int i = currentIndex; i < end; i++) {
      _enrichTrackMetadata(i);
      // Small pause between enrichment triggers to avoid slamming the service
      if (i % 2 == 0) await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _enrichTrackMetadata(int index) async {
    final currentQueue = queue.value;
    if (index < 0 || index >= currentQueue.length) return;
    if (_metadataEnrichingIndices.contains(index)) return;

    final originalItem = currentQueue[index];
    
    // GUARD: Skip metadata enrichment for audiobook chapters
    final mediaType = originalItem.extras?['mediaType'] as String? ?? 'music';
    if (mediaType == 'audiobook') return;
    
    final originalId = originalItem.extras?['originalId'] as String? ?? originalItem.id;
    
    // Retrieve the most up-to-date version from our enriched cache if available, to avoid overwriting bitrate/sampleRate/etc.
    var item = originalItem;
    final cachedEnriched = _enrichedItems[originalId];
    if (cachedEnriched != null) {
      item = originalItem.copyWith(
        title: cachedEnriched.title,
        artist: cachedEnriched.artist,
        album: cachedEnriched.album,
        artUri: cachedEnriched.artUri ?? originalItem.artUri,
        duration: cachedEnriched.duration ?? originalItem.duration,
        extras: {
          ...originalItem.extras ?? {},
          ...cachedEnriched.extras ?? {},
        },
      );
    }
    
    if (item.extras?['enriched'] == true) return;
    
    final torrentId = (item.extras?['torrentId'] as num?)?.toInt() ?? 0;
    final fileId = (item.extras?['fileId'] as num?)?.toInt() ?? 0;

    // Determine enrichment need:
    // - Library tracks (torrentId > 0): ALWAYS re-check DB on first enrichment pass
    // - Virtual/playlist tracks (torrentId == -1 or Apple Music): always enrich
    // - Any track missing artwork, artist, or genre: enrich
    final isLibraryTrack = torrentId > 0;
    final isVirtualTrack = torrentId == -1 || item.id.contains('apple.com') || item.id.contains('lazy.flac.internal');
    final needsEnrichment = item.artist == 'TorBox' || 
                           item.artist == 'Unknown' || 
                           item.artUri == null || 
                           item.extras?['genre'] == null;
                           
    // Library tracks always do a DB pass; skip only if not a library track AND fully enriched
    if (!isLibraryTrack && !isVirtualTrack && !needsEnrichment) return;
    
    _metadataEnrichingIndices.add(index);
    try {
      final db = getIt<AppDatabase>();
      final itunes = getIt<ItunesMetadataService>();

      ItunesMeta? meta;
      
      // 1. Check Library DB first — highest authority
      if (torrentId > 0) {
        final libMeta = await db.getTrackMetadata(torrentId, fileId);
        if (libMeta != null) {
          meta = ItunesMeta(
            trackName: libMeta.trackTitle,
            artistName: libMeta.artist,
            album: libMeta.album,
            genre: libMeta.genre,
            artworkUrlHigh: libMeta.artworkUrlHigh,
            artworkUrlLow: libMeta.artworkUrlLow,
            trackTimeMillis: libMeta.trackTimeMillis,
          );
        }
      }

      // 2. Check External Cache — use title|artist as key for all track types
      if (meta == null || (meta.genre == null && meta.artworkUrlHigh == null)) {
        // Only go to cache/API if we still have incomplete data
        if (meta == null) {
          final cacheKey = '${item.title}|${item.artist ?? ''}';
          final cached = await db.getExternalTrackMetadata(cacheKey);
          
          if (cached != null && (cached.artworkUrlHigh != null || cached.genre != null)) {
            meta = ItunesMeta(
              trackName: cached.trackTitle,
              artistName: cached.artist,
              album: cached.album,
              genre: cached.genre,
              artworkUrlHigh: cached.artworkUrlHigh,
              artworkUrlLow: cached.artworkUrlLow,
              trackTimeMillis: cached.trackTimeMillis,
            );
          } else if (isVirtualTrack || needsEnrichment) {
            // 3. Fetch from iTunes as last resort
            meta = await itunes.fetchMeta(item.title, item.artist ?? '');
            if (meta != null) {
              final cacheKey2 = '${item.title}|${item.artist ?? ''}';
              await db.saveExternalTrackMetadata(ExternalTrackMetadataCompanion.insert(
                trackUrl: cacheKey2,
                trackTitle: meta.trackName ?? item.title,
                artist: meta.artistName ?? item.artist ?? 'Unknown',
                album: Value(meta.album),
                genre: Value(meta.genre),
                artworkUrlHigh: Value(meta.artworkUrlHigh),
                artworkUrlLow: Value(meta.artworkUrlLow),
                trackTimeMillis: Value(meta.trackTimeMillis),
                lastUpdated: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          }
        }
      }

      if (meta != null) {
        // Merge: prefer existing good values over fetched ones for library tracks
        final resolvedArtUri = (meta.artworkUrlHigh != null && meta.artworkUrlHigh!.isNotEmpty) 
            ? Uri.parse(meta.artworkUrlHigh!) 
            : (meta.artworkUrlLow != null && meta.artworkUrlLow!.isNotEmpty) 
                ? Uri.parse(meta.artworkUrlLow!) 
                : item.artUri;

        final hasValidArtist = item.artist != null && item.artist!.toLowerCase() != 'torbox' && item.artist!.toLowerCase() != 'unknown' && item.artist!.isNotEmpty;
        final hasValidTitle = item.title.isNotEmpty && item.title.toLowerCase() != 'unknown';

        final enrichedItem = item.copyWith(
          title: hasValidTitle ? item.title : ((meta.trackName?.isNotEmpty == true) ? meta.trackName! : item.title),
          artist: hasValidArtist 
              ? item.artist 
              : ((meta.artistName != null && meta.artistName!.toLowerCase() != 'torbox' && meta.artistName!.toLowerCase() != 'unknown') 
                  ? meta.artistName! 
                  : item.artist ?? 'Unknown'),
          album: meta.album ?? item.album,
          artUri: resolvedArtUri,
          duration: meta.trackTimeMillis != null ? Duration(milliseconds: meta.trackTimeMillis!) : item.duration,
          extras: {
            ...item.extras ?? {},
            if (meta.genre != null) 'genre': meta.genre,
            'enriched': true,
          },
        );

        // Update queue state
        _enrichedItems[originalId] = enrichedItem;
        
        final newQueue = List<MediaItem>.from(queue.value);
        if (index < newQueue.length && (newQueue[index].id == item.id || newQueue[index].extras?['originalId'] == originalId)) {
          newQueue[index] = enrichedItem;
          queue.add(newQueue);
        }

        // ALWAYS update mediaItem if this is the current track — ensures UI updates immediately
        if (index == _player.currentIndex) {
          mediaItem.add(enrichedItem);
          print('[AudioHandler] Enriched current track: "${enrichedItem.title}" | artist=${enrichedItem.artist} | genre=${enrichedItem.extras?["genre"]} | artwork=${enrichedItem.artUri != null}');
        }
      }
    } catch (e) {
      print('[AudioHandler] Metadata enrichment error at $index: $e');
    } finally {
      _metadataEnrichingIndices.remove(index);
    }
  }

  bool _isExtendingQueue = false;

  /// Automatically extend the queue if the user reaches the end.
  Future<void> _checkAndExtendQueue(int currentIndex) async {
    if (_isExtendingQueue) return;
    final currentQueue = queue.value;
    if (currentQueue.isEmpty) return;
    
    // Only check when we are at the very last track in the queue
    if (currentIndex != currentQueue.length - 1) return;
    
    _isExtendingQueue = true;
    
    if (currentIndex != currentQueue.length - 1) return;
    
    _isExtendingQueue = true;


    final currentItem = currentQueue[currentIndex];
    
    // GUARD: Don't auto-extend queue with random music when playing audiobooks
    final mediaType = currentItem.extras?['mediaType'] as String? ?? 'music';
    if (mediaType == 'audiobook') {
      _isExtendingQueue = false;
      return;
    }
    
    try {
      final db = getIt<AppDatabase>();
      final allFiles = await db.getAllFiles();
      if (allFiles.isEmpty) return; // No local library to pull from

      final allMeta = await db.getAllMetadata();
      final currentFileId = (currentItem.extras?['fileId'] as num?)?.toInt();
      
      // 1. Try to find a song by the same artist
      final matchingMeta = allMeta.where((m) => 
        m.artist != null && 
        m.artist!.isNotEmpty && 
        m.artist != 'Unknown' && 
        m.artist != 'TorBox' &&
        m.artist == currentItem.artist && 
        m.fileId != currentFileId
      ).toList();

      DbTrackMetadata? nextMeta;
      DbFile? nextFile;

      if (matchingMeta.isNotEmpty) {
        matchingMeta.shuffle();
        nextMeta = matchingMeta.first;
        final possibleFiles = allFiles.where((f) => f.id == nextMeta!.fileId && f.torrentId == nextMeta!.torrentId);
        if (possibleFiles.isNotEmpty) {
            nextFile = possibleFiles.first;
        }
      }

      // 2. If no artist match, just pick a random song from library
      if (nextFile == null) {
        final randFiles = allFiles.where((f) => f.id != currentFileId && f.torrentId != -1).toList();
        if (randFiles.isNotEmpty) {
          randFiles.shuffle();
          nextFile = randFiles.first;
          final possibleMeta = allMeta.where((m) => m.torrentId == nextFile!.torrentId && m.fileId == nextFile!.id);
          if (possibleMeta.isNotEmpty) {
             nextMeta = possibleMeta.first;
          }
        }
      }

      // Append to queue
      if (nextFile != null) {
        final strippedName = nextFile.name.split('/').last.split('\\').last;
        String title = nextMeta?.trackTitle ?? strippedName;
        String artist = nextMeta?.artist ?? 'Unknown Artist';
        String artworkUrl = nextMeta?.artworkUrlHigh ?? nextMeta?.artworkUrlLow ?? '';
        int? trackTimeMillis = nextMeta?.trackTimeMillis;

        // Proactively enrich from iTunes if it's missing artwork/proper artist
        final needsEnrichment = artist == 'Unknown Artist' || artist == 'TorBox' || artworkUrl.isEmpty;
        if (needsEnrichment && artist != 'Unknown Artist') {
           final itunes = getIt<ItunesMetadataService>();
           final meta = await itunes.fetchMeta(title, artist);
           if (meta != null) {
              title = meta.trackName ?? title;
              artist = meta.artistName ?? artist;
              artworkUrl = meta.artworkUrlHigh ?? meta.artworkUrlLow ?? artworkUrl;
              trackTimeMillis = meta.trackTimeMillis ?? trackTimeMillis;
              
              // Cache it so future lookups are fast
              final cacheKey = nextFile.torrentId == -1 ? nextFile.id.abs().toString() : '$title|$artist';
              await db.saveExternalTrackMetadata(ExternalTrackMetadataCompanion.insert(
                trackUrl: cacheKey,
                trackTitle: title,
                artist: artist,
                album: Value(meta.album),
                artworkUrlHigh: Value(meta.artworkUrlHigh),
                artworkUrlLow: Value(meta.artworkUrlLow),
                trackTimeMillis: Value(meta.trackTimeMillis),
                lastUpdated: DateTime.now().millisecondsSinceEpoch,
              ));
           }
        }

        final nextItem = MediaItem(
          id: nextFile.torrentId == -1 
              ? 'https://lazy.flac.internal/?title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist)}' 
              : 'https://lazy.torbox.internal/${nextFile.torrentId}/${nextFile.id}',
          title: title,
          artist: artist,
          artUri: artworkUrl.isNotEmpty ? Uri.parse(artworkUrl) : null,
          duration: trackTimeMillis != null ? Duration(milliseconds: trackTimeMillis) : null,
          extras: {
            'torrentId': nextFile.torrentId,
            'fileId': nextFile.id,
            'size': nextFile.size,
            'localPath': nextFile.localPath,
          },
        );

        final nextSource = await _createAudioSource(nextItem);
        await _playlist.add(nextSource);
        _originalItems.add(nextItem);
        
        print('[AudioHandler] Autoplay: Added "${nextItem.title}" to queue end.');
        
        // Enrich it fully in the background
        _enrichQueueInRange(currentIndex + 1);
      }
    } catch (e) {
      print('[AudioHandler] Autoplay Extension error: $e');
    } finally {
      _isExtendingQueue = false;
    }
  }

  // Helper to resolve a lazy track and update the playlist
  Future<bool> _resolveTrack(int index) async {
    final sequence = _player.sequence;
    if (sequence == null || index >= sequence.length) return false;
    
    final item = sequence[index].tag as MediaItem;
    final isLazy = item.id.contains('lazy.torbox.internal') || 
                   item.id.contains('lazy.flac.internal') || 
                   item.id.contains('lazy.plugin.internal') ||
                   (item.extras?['linkType'] == 'soundcloud' && !item.id.startsWith('http'));
    
    if (!isLazy) return true;

    // 1. Guard: already resolving this index — return true optimistically and let the waiter resume
    if (_resolvingIndices.contains(index)) return false;
    _resolvingIndices.add(index);

    try {
      print('[AudioHandler] Resolving track $index: ${item.title}');
      final uri = Uri.parse(item.id);
      final isFlac = uri.host == 'lazy.flac.internal';
      final isPlugin = uri.host == 'lazy.plugin.internal';
      
      final repo = getIt<MusicRepository>();
      final db = getIt<AppDatabase>();
      
      String? realUrl;
      String? resolvedLinkType;
      int? torrentId;
      int? fileId;
      
      final linkType = item.extras?['linkType'] as String?;

      if (isPlugin) {
        final pluginId = uri.pathSegments[0];
        final trackId = Uri.decodeComponent(uri.pathSegments[1]);
        print('[AudioHandler] Resolving dynamic plugin track: pluginId=$pluginId, trackId=$trackId');
        final pluginManager = getIt<PluginManager>();
        
        if (pluginId.startsWith('eclipse_')) {
          realUrl = await pluginManager.resolveEclipseStream(pluginId.replaceFirst('eclipse_', ''), trackId);
        } else {
          realUrl = await pluginManager.resolveStream(pluginId, trackId);
        }
        
        resolvedLinkType = pluginId;
        
        // Priority fallback: if original plugin resolution fails, try other active/prioritized plugins
        if (realUrl == null || realUrl.isEmpty) {
          print('[AudioHandler] Primary plugin $pluginId failed. Trying alternative plugins in priority order...');
          final prioritized = pluginManager.prioritizedActiveAddons;
          final title = item.title;
          final artist = item.artist ?? '';
          
          for (final altPlugin in prioritized) {
            final altId = altPlugin is JsPlugin ? altPlugin.id : 'eclipse_${(altPlugin as EclipseAddon).id}';
            if (altId == pluginId) continue;
            
            try {
              print('[AudioHandler] Falling back to alternative addon: $altId');
              List<ScraperResult> results;
              if (altId.startsWith('eclipse_')) {
                results = await pluginManager.searchEclipse(altId.replaceFirst('eclipse_', ''), '$artist $title');
              } else {
                results = await pluginManager.search(altId, '$artist $title');
              }
              
              if (results.isNotEmpty) {
                final match = results.first;
                final altTrackId = match.extras?['trackId'] as String? ?? match.url;
                
                String? resolvedUrl;
                if (altId.startsWith('eclipse_')) {
                  resolvedUrl = await pluginManager.resolveEclipseStream(altId.replaceFirst('eclipse_', ''), altTrackId);
                } else {
                  resolvedUrl = await pluginManager.resolveStream(altId, altTrackId);
                }
                
                if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                  print('[AudioHandler] Successfully resolved fallback URL from $altId: $resolvedUrl');
                  realUrl = resolvedUrl;
                  resolvedLinkType = altId;
                  break;
                }
              }
            } catch (e) {
              print('[AudioHandler] Failed fallback search/resolve on $altId: $e');
            }
          }
        }
        
        torrentId = -1;
        fileId = (item.extras?['fileId'] as num?)?.toInt() ?? (realUrl != null ? -realUrl.hashCode.abs() : -1);
      } else if (isFlac) {
        final title = uri.queryParameters['title'] ?? item.title;
        final artist = uri.queryParameters['artist'] ?? item.artist ?? '';
        final query = '$artist $title'.trim();
        print('[AudioHandler] Searching FLAC in background for: $query');
        final results = await repo.searchFLAC(query);
        final result = results.isEmpty ? null : results.firstWhere(
          (r) => r.isGoodMatch(title, artist),
          orElse: () => results.first,
        );
        
        if (result != null) {
          realUrl = result.url;
          resolvedLinkType = result.linkType;
          torrentId = -1; // Dummy values for LockCachingAudioSource naming
          fileId = (item.extras?['fileId'] as num?)?.toInt() ?? -result.url.hashCode.abs();
        } else {
          print('[AudioHandler] No FLAC found for $query');
          // We could auto-skip here: _player.seekToNext() if it's currently playing, but that might be infinite loop if all fail.
          return false;
        }
      } else {
        // Format: https://lazy.torbox.internal/torrentId/fileId
        torrentId = int.parse(uri.pathSegments[0]);
        fileId = int.parse(uri.pathSegments[1]);

        // Check for local persistent download first
        String? localPath = item.extras?['localPath'] as String?;
        
        // Fallback: check DB directly (crucial for offline robust resolution)
        if (localPath == null && torrentId != null && fileId != null) {
          final dbFile = await (db.select(db.files)
                ..where((f) => f.torrentId.equals(torrentId!) & f.id.equals(fileId!)))
              .getSingleOrNull();
          localPath = dbFile?.localPath;
        }

        if (localPath != null && io.File(localPath).existsSync()) {
          print('[AudioHandler] Using persistent local file: $localPath');
          final newItem = item.copyWith(
            id: Uri.file(localPath).toString(), 
            duration: item.duration,
            extras: {
              ...?item.extras,
              'torrentId': torrentId,
              'fileId': fileId,
              'originalId': item.extras?['originalId'] ?? item.id,
            },
          );
          final newSource = AudioSource.uri(
            Uri.file(localPath),
            tag: newItem,
          );
          
          final isActive = io.Platform.isLinux ? (_linuxIndex == index) : (_player.currentIndex == index);
          final currentPos = isActive ? _player.position : Duration.zero;
          final initialPosMillis = item.extras?['initialPositionMillis'] as int?;

          // Update the playlist with the new source
          if (index + 1 < _playlist.length) {
            await _playlist.insert(index + 1, newSource);
            await _playlist.removeAt(index);
          } else {
            await _playlist.add(newSource);
            await _playlist.removeAt(index);
          }

          if (isActive) {
            final targetPos = (initialPosMillis != null && initialPosMillis > 0 && currentPos == Duration.zero)
                ? Duration(milliseconds: initialPosMillis)
                : currentPos;
            if (targetPos > Duration.zero) {
              print('[AudioHandler] Using persistent local file: Re-seeking to ${targetPos.inMilliseconds}ms after replacement');
              try {
                await _player.seek(targetPos, index: index);
              } catch (_) {}
            }
          }

          // Update queue broadcast
          final currentQueue = List<MediaItem>.from(queue.value);
          if (index < currentQueue.length) {
            currentQueue[index] = newItem;
            queue.add(List.unmodifiable(currentQueue));
          }

          // IMPORTANT: If this is the active track, update mediaItem so UI changes
          if (isActive) {
            mediaItem.add(newItem);
            playbackState.add(_transformEvent(_player.playbackEvent));
            if (io.Platform.isLinux) {
              final singleSource = await _createAudioSource(newItem);
              await _player.setAudioSource(singleSource);
            }
          }
          print('[AudioHandler] Successfully resolved track $index using local file');
          return true;
        }

        realUrl = await repo.getStreamUrl(torrentId, fileId);
      }
      
      if (realUrl != null) {
        if (io.Platform.isLinux) {
          if (index >= _playlist.length) return false;
          final currentItem = (_playlist.children[index] as IndexedAudioSource).tag as MediaItem;
          if (currentItem.id != item.id) return false;
        } else {
          // Re-verify index hasn't shifted or been cleared
          final currentSequence = _player.sequence;
          if (currentSequence == null || index >= currentSequence.length) return false;
          
          // Re-verify tag (in case of total queue swap)
          final currentItem = currentSequence[index].tag as MediaItem;
          if (currentItem.id != item.id) return false;
        }

        final newItem = item.copyWith(
          id: realUrl, 
          duration: item.duration,
          extras: {
            ...?item.extras,
            'torrentId': torrentId,
            'fileId': fileId,
            'originalId': item.extras?['originalId'] ?? item.id,
            if (isFlac) 'linkType': resolvedLinkType ?? 'flac',
          },
        );
        
        final newSource = await _createAudioSource(newItem);
        
        // --- SAFER PLAYLIST UPDATE ---
        // Instead of removeAt + insert (which triggers jumps),
        // we append the new one and then remove the old one if needed.
        // Or if it's the current track, we can use a more surgical approach.
        
        final isActive = io.Platform.isLinux ? (_linuxIndex == index) : (_player.currentIndex == index);
        final currentPos = isActive ? _player.position : Duration.zero;
        final initialPosMillis = item.extras?['initialPositionMillis'] as int?;

        // If we're at the end, just add. Otherwise, insert at index + 1
        if (index + 1 < _playlist.length) {
          await _playlist.insert(index + 1, newSource);
          await _playlist.removeAt(index);
        } else {
          await _playlist.add(newSource);
          await _playlist.removeAt(index);
        }

        if (isActive) {
          final targetPos = (initialPosMillis != null && initialPosMillis > 0 && currentPos == Duration.zero)
              ? Duration(milliseconds: initialPosMillis)
              : currentPos;
          if (targetPos > Duration.zero) {
            print('[AudioHandler] Remote stream resolved: Re-seeking to ${targetPos.inMilliseconds}ms after replacement');
            try {
              await _player.seek(targetPos, index: index);
            } catch (_) {}
          }
        }

        // Update queue broadcast
        final currentQueue = List<MediaItem>.from(queue.value);
        if (index < currentQueue.length) {
          currentQueue[index] = newItem;
          queue.add(List.unmodifiable(currentQueue));
        }

        // IMPORTANT: If this is the active track, update mediaItem so UI changes
        if (isActive) {
          mediaItem.add(newItem);
          playbackState.add(_transformEvent(_player.playbackEvent));
          if (io.Platform.isLinux) {
            final singleSource = await _createAudioSource(newItem);
            await _player.setAudioSource(singleSource);
          }
        }

        print('[AudioHandler] Successfully resolved track $index');
        return true;
      }
    } catch (e, st) {
      // Only log as resolution fail if it's not a Flutter widget lifecycle error
      // (which are unrelated UI assertions that shouldn't affect audio resolution)
      final errStr = e.toString();
      if (errStr.contains('_lifecycleState') || errStr.contains('ElementLifecycle')) {
        print('[AudioHandler] Ignoring Flutter widget lifecycle error during resolution (not a real failure): $e');
        // Don't return false — resolution may have still succeeded if caught mid-update
      } else {
        print('[AudioHandler] Resolution failed for $index: $e');
        print(st);
      }
    } finally {
      _resolvingIndices.remove(index);
    }
    return false;
  }

  Future<void> _saveAudiobookProgressIfNeeded() async {
    final current = mediaItem.value;
    if (current != null && current.extras?['mediaType'] == 'audiobook') {
      try {
        final bookId = current.extras?['bookId'] as String?;
        final chapterIndex = current.extras?['chapterIndex'] as int?;
        if (bookId != null && chapterIndex != null) {
          final position = _player.position;
          final duration = current.duration ?? Duration.zero;
          if (position > Duration.zero) {
            final repo = getIt<AudiobookRepository>();
            
            bool isCompleted = false;
            final chapters = _currentAudiobookChapters;
            if (chapters != null && chapters.isNotEmpty && chapterIndex < chapters.length) {
              final ch = chapters[chapterIndex];
              final start = ch.startTimeMillis;
              final end = (chapterIndex + 1 < chapters.length)
                  ? chapters[chapterIndex + 1].startTimeMillis
                  : (duration.inMilliseconds > 0 ? duration.inMilliseconds : start);
              final chDuration = end - start;
              final relativePos = position.inMilliseconds - start;
              if (chDuration > 0 && relativePos >= chDuration - 5000) {
                isCompleted = true;
              }
            } else {
              if (duration.inMilliseconds > 0 && position.inMilliseconds >= duration.inMilliseconds - 5000) {
                isCompleted = true;
              }
            }

            print('[AudioHandler] _saveAudiobookProgressIfNeeded: bookId=$bookId ch=$chapterIndex posMs=${position.inMilliseconds} durMs=${duration.inMilliseconds} completed=$isCompleted');
            await repo.saveProgress(
              bookId: bookId,
              chapterIndex: chapterIndex,
              positionMillis: position.inMilliseconds,
              durationMillis: duration.inMilliseconds,
              isCompleted: isCompleted,
            );
            _lastSavedPositionMs = position.inMilliseconds;
            _lastAudiobookSaveTime = DateTime.now();
            print('[AudioHandler] _saveAudiobookProgressIfNeeded: saved progress.');
          }
        }
      } catch (e) {
        print('[AudioHandler] _saveAudiobookProgressIfNeeded: failed to save progress: $e');
      }
    }
  }

  Future<void> _syncHardcoverProgressIfNeeded() async {
    final current = mediaItem.value;
    if (current != null && current.extras?['mediaType'] == 'audiobook') {
      final bookId = current.extras?['bookId'] as String?;
      if (bookId != null) {
        try {
          final repo = getIt<AudiobookRepository>();
          await repo.syncHardcoverProgress(bookId);
        } catch (e) {
          print('[AudioHandler] Hardcover sync error: $e');
        }
      }
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _saveAudiobookProgressIfNeeded();
    // Hardcover sync runs in background so pause is not blocked by HTTP.
    _syncHardcoverProgressIfNeeded();
    await _player.pause();
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatModeState = repeatMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.off); // Custom play-once-more logic in currentIndexStream
        break;
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.one); // Loops the single track infinitely
        break;
      default:
        break;
    }
    // Reset play count when mode changes
    _currentSongPlayCount = 1;
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _saveAudiobookProgressIfNeeded();
    // Hardcover sync runs in background so stop is not blocked by HTTP.
    _syncHardcoverProgressIfNeeded();
    await _player.stop();
    mediaItem.add(null);
    queue.add([]);
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  @override
  Future<void> skipToNext() async {
    if (io.Platform.isLinux) {
      if (_linuxIndex + 1 < _playlist.length) {
        await _playLinuxTrack(_linuxIndex + 1);
      } else {
        await stop();
      }
    } else {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> moveQueueItem(int index, int newIndex) async {
    print('[AudioHandler] Moving queue item from $index to $newIndex');
    try {
      await _playlist.move(index, newIndex);
      if (io.Platform.isLinux) {
        _broadcastLinuxQueue();
      }
    } catch (e) {
      print('[AudioHandler] Error moving queue item: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (io.Platform.isLinux) {
      if (_player.position.inSeconds > 3) {
        await seek(Duration.zero);
      } else if (_linuxIndex > 0) {
        await _playLinuxTrack(_linuxIndex - 1);
      }
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (io.Platform.isLinux) {
      await _playLinuxTrack(index);
    } else {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    print('[AudioHandler] playMediaItem: "${item.title}"');
    print('[AudioHandler] playMediaItem: ID/URL: ${item.id.substring(0, item.id.length > 50 ? 50 : item.id.length)}...');
    print('[AudioHandler] playMediaItem: Extras: ${item.extras}');
    
    // Stop current playback cleanly to avoid state locks
    try {
      if (_player.playing) await _player.pause();
      await _playlist.clear();
    } catch (e) {
      print('[AudioHandler] Pre-play reset error: $e');
    }
    
    // Legacy support for single track play
    await updateQueue([item]);
    if (io.Platform.isLinux) {
      // updateQueue already plays it on Linux
      return;
    }
    if (item.id.contains('lazy.torbox.internal') || item.id.contains('lazy.flac.internal')) {
      print('[AudioHandler] playMediaItem: Pre-resolving track 0 before play()');
      await _resolveTrack(0);
    }
    try {
      final initialPos = item.extras?['initialPositionMillis'] as int?;
      if (initialPos != null && initialPos > 0) {
        print('[AudioHandler] playMediaItem: Seeking to initial position ${initialPos}ms before play');
        try {
          await _player.seek(Duration(milliseconds: initialPos), index: 0);
        } catch (seekError) {
          print('[AudioHandler] playMediaItem: Seek failed ($seekError), playing from beginning.');
        }
      }
      print('[AudioHandler] playMediaItem: Calling _player.play()');
      await _player.play();
      print('[AudioHandler] playMediaItem: _player.play() returned');
    } catch (e) {
      print('[AudioHandler] Playback failed: $e');
    }
  }

  /// Safely update the current media item's metadata (e.g. after enrichment)
  Future<void> broadcastMetadata(MediaItem item) async {
    mediaItem.add(item);
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    final source = await _createAudioSource(item);
    await _playlist.add(source);
    
    _originalItems.add(item);
    print('[AudioHandler] Item added to queue: ${item.title}');
    if (io.Platform.isLinux) {
      _broadcastLinuxQueue();
    }
  }

  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final currentIdx = _player.currentIndex;
    final isCurrent = currentIdx == index;

    await _playlist.removeAt(index);

    if (index < _originalItems.length) {
      _originalItems.removeAt(index);
    }

    if (io.Platform.isLinux) {
      _broadcastLinuxQueue();
    } else {
      final newQueue = List<MediaItem>.from(queue.value);
      if (index < newQueue.length) {
        newQueue.removeAt(index);
        queue.add(newQueue);
      }
    }

    if (currentIdx != null && !isCurrent && index < currentIdx) {
      await _player.seek(Duration.zero, index: currentIdx - 1);
    }

    if (isCurrent) {
      await skipToNext();
    }
  }  @override
  Future<void> updateQueue(List<MediaItem> items) async {
    _originalItems = List.from(items);
    _shuffleModeState = AudioServiceShuffleMode.none;

    await _playlist.clear();
    final sources = await Future.wait(items.map((item) => _createAudioSource(item)));
    await _playlist.addAll(sources);
    print('[AudioHandler] Queue updated: ${items.length} items');
    
    if (io.Platform.isLinux) {
      _broadcastLinuxQueue();
      if (items.isNotEmpty) {
        await _playLinuxTrack(0);
      }
    } else {
      // Proactively update mediaItem to the first item if current index is null OR if we just swapped everything
      if (items.isNotEmpty) {
        mediaItem.add(items.first);
      }
    }
  }

  static Duration parseDuration(dynamic durationVal) {
    if (durationVal == null) return Duration.zero;
    if (durationVal is num) {
      return Duration(milliseconds: durationVal.toInt());
    }
    final durationStr = durationVal.toString().trim();
    if (durationStr == 'Unknown' || durationStr.isEmpty) return Duration.zero;
    
    final ms = int.tryParse(durationStr);
    if (ms != null) {
      return Duration(milliseconds: ms);
    }
    
    final parts = durationStr.split(':');
    try {
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      } else if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return Duration.zero;
  }

  static Uri? parseArtworkUri(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('file://')) {
      return Uri.parse(path);
    }
    if (path.startsWith('/')) {
      return Uri.file(path);
    }
    return Uri.tryParse(path);
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'like' || name == 'unlike') {
      final item = mediaItem.value;
      if (item != null) {
        final torrentId = (item.extras?['torrentId'] as num?)?.toInt();
        final fileId = (item.extras?['fileId'] as num?)?.toInt();
        if (torrentId != null && fileId != null) {
          final db = getIt<AppDatabase>();
          final liked = name == 'like';
          await db.toggleTrackLike(
            torrentId,
            fileId,
            liked,
            title: item.title,
            artist: item.artist,
            album: item.album,
            artworkUrlLow: item.artUri?.toString(),
            artworkUrlHigh: item.artUri?.toString(),
          );
          
          _isCurrentTrackLiked = liked;
          playbackState.add(_transformEvent(_player.playbackEvent));
        }
      }
      return;
    }

    if (name == 'bookmark') {
      final item = mediaItem.value;
      if (item != null && item.extras?['mediaType'] == 'audiobook') {
        final bookId = item.extras?['bookId'] as String?;
        if (bookId != null) {
          final chapterIndex = item.extras?['chapterIndex'] as int? ?? 0;
          final position = _player.position.inMilliseconds;
          final repo = getIt<AudiobookRepository>();
          await repo.addBookmark(bookId, chapterIndex, position);
        }
      }
      return;
    }

    if (name == 'refresh_metadata') {
      final torrentId = (extras?['torrentId'] as num?)?.toInt() ?? 0;
      final fileId = (extras?['fileId'] as num?)?.toInt() ?? 0;
      final current = mediaItem.value;
      if (current == null) return true;
      
      final currentTorrentId = (current.extras?['torrentId'] as num?)?.toInt();
      final currentFileId = (current.extras?['fileId'] as num?)?.toInt();
      
      if (currentTorrentId == torrentId && currentFileId == fileId) {
        // Directly read fresh data from DB and broadcast immediately — bypasses enrichment lock
        try {
          final db = getIt<AppDatabase>();
          final libMeta = await db.getTrackMetadata(torrentId, fileId);
          if (libMeta != null) {
            final resolvedArtUri = (libMeta.artworkUrlHigh != null && libMeta.artworkUrlHigh!.isNotEmpty)
                ? Uri.parse(libMeta.artworkUrlHigh!)
                : (libMeta.artworkUrlLow != null && libMeta.artworkUrlLow!.isNotEmpty)
                    ? Uri.parse(libMeta.artworkUrlLow!)
                    : current.artUri;

            final refreshed = current.copyWith(
              title: libMeta.trackTitle ?? current.title,
              artist: libMeta.artist ?? current.artist,
              album: libMeta.album ?? current.album,
              artUri: resolvedArtUri,
              extras: {
                if (current.extras != null) ...current.extras!,
                if (libMeta.genre != null) 'genre': libMeta.genre,
              },
            );
            mediaItem.add(refreshed);
            // Also update queue entry
            final index = playbackState.value.queueIndex;
            if (index != null) {
              final newQueue = List<MediaItem>.from(queue.value);
              if (index < newQueue.length) {
                newQueue[index] = refreshed;
                queue.add(newQueue);
              }
              // Force re-enrichment of adjacent tracks
              _metadataEnrichingIndices.remove(index);
            }
            print('[AudioHandler] refresh_metadata: broadcasted fresh data for "${refreshed.title}" | art=${refreshed.artUri != null}');
          }
        } catch (e) {
          print('[AudioHandler] refresh_metadata error: $e');
        }
      }
      return true;
    }

    if (name == 'add_next' || name == 'add_to_queue') {
      if (extras == null) return false;
      
      final url = extras['url'] as String?;
      if (url == null) return false;

      final title = extras['title'] as String? ?? 'Unknown';
      final artist = extras['artist'] as String? ?? 'Unknown Artist';
      final artworkUrl = extras['artworkUrl'] as String? ?? '';
      final trackExtras = extras['extras'] as Map<String, dynamic>? ?? {};

      final item = MediaItem(
        id: url,
        title: title,
        artist: artist,
        album: extras['album'] as String? ?? '',
        artUri: parseArtworkUri(artworkUrl),
        duration: extras['duration'] != null ? parseDuration(extras['duration']) : null,
        extras: trackExtras,
      );

      final source = await _createAudioSource(item);
      final index = name == 'add_next' 
          ? (_player.currentIndex != null ? _player.currentIndex! + 1 : _player.sequence?.length ?? 0)
          : _player.sequence?.length ?? 0;

      final seqSource = _player.audioSource;
      if (seqSource is ConcatenatingAudioSource) {
        await seqSource.insert(index, source);
        
        // Update our broadcast queue
        final newQueue = List<MediaItem>.from(queue.value);
        if (index >= newQueue.length) {
          newQueue.add(item);
        } else {
          newQueue.insert(index, item);
        }
        queue.add(newQueue);
      }
      
      return true;
    }

    if (name == 'play' && extras != null) {
      final requestedExtras = extras['extras'] as Map<String, dynamic>?;
      final replaceCurrent = extras['replaceCurrent'] == true;
      final forceReplace = extras['forceReplace'] == true;
      final queueItems = extras['queue'] as List<dynamic>?;
      final url = extras['url'] as String?;
      
      // 1. Fresh Playback (Full Queue Swap)
      if (forceReplace || _player.processingState == ProcessingState.idle || _player.sequence == null || _player.sequence!.isEmpty) {
        if (url == null) return;

        if (queueItems != null) {
          final items = queueItems.map((e) {
            final m = e as Map<String, dynamic>;
            return MediaItem(
              id: m['url']?.toString() ?? '',
              title: m['title']?.toString() ?? 'Unknown track',
              artist: m['artist']?.toString() ?? 'TorBox',
              artUri: parseArtworkUri(m['artworkUrl'] as String?),
              duration: m['duration'] != null ? parseDuration(m['duration']) : null,
              extras: m['extras'] as Map<String, dynamic>?,
            );
          }).toList();

          final initialIndex = extras['index'] as int? ?? 0;
          
          // Use rotation logic to put chosen song at index 0 (cleaner "Up Next" UI)
          final List<MediaItem> rotatedItems;
          if (initialIndex > 0 && initialIndex < items.length) {
            rotatedItems = [...items.sublist(initialIndex), ...items.sublist(0, initialIndex)];
          } else {
            rotatedItems = items;
          }

          await updateQueue(rotatedItems);
          mediaItem.add(rotatedItems.first);
          await _player.seek(Duration.zero, index: 0);
          _consecutiveFailures = 0; // Reset on new play request
          
          if (rotatedItems.first.id.contains('lazy.torbox.internal') || rotatedItems.first.id.contains('lazy.flac.internal')) {
            print('[AudioHandler] play: Pre-resolving track 0 for rotated items');
            await _resolveTrack(0);
          }
          await _player.play();
          _enrichQueueInRange(0);
        } else {
          final item = MediaItem(
            id: url,
            title: extras['title'] as String? ?? 'Unknown',
            artist: extras['artist'] as String? ?? 'TorBox',
            artUri: parseArtworkUri(extras['artworkUrl'] as String?),
            duration: extras['duration'] != null ? parseDuration(extras['duration']) : null,
            extras: {
              ...?requestedExtras,
              if (extras['mediaType'] != null) 'mediaType': extras['mediaType'],
            },
          );
          mediaItem.add(item);
          await playMediaItem(item);
        }
        return;
      }

      // 2. Add to Existing Queue / Play Next
      if (_player.currentIndex != null) {
        final currentQueue = queue.value;
        final reqFileId = (requestedExtras?['fileId'] as num?)?.toInt();
        final reqTorrentId = (requestedExtras?['torrentId'] as num?)?.toInt();

        int matchIndex = -1;
        if (reqFileId != null && reqTorrentId != null) {
          matchIndex = currentQueue.indexWhere((item) => 
            item.extras?['fileId'] == reqFileId && 
            item.extras?['torrentId'] == reqTorrentId
          );
        }

        if (matchIndex != -1 || replaceCurrent) {
          final targetIndex = matchIndex != -1 ? matchIndex : _player.currentIndex!;
          
          final item = MediaItem(
            id: url ?? '',
            title: extras['title'] as String? ?? 'Unknown',
            artist: extras['artist'] as String? ?? 'TorBox',
            artUri: parseArtworkUri(extras['artworkUrl'] as String?),
            duration: extras['duration'] != null ? parseDuration(extras['duration']) : currentQueue[targetIndex].duration,
            extras: requestedExtras,
          );

          final newSource = await _createAudioSource(item);
          final wasPlaying = _player.playing;
          final isCurrentTrack = targetIndex == _player.currentIndex;

          if (isCurrentTrack) {
            final position = _player.position;
            await _playlist.insert(targetIndex + 1, newSource);
            await _player.seek(position, index: targetIndex + 1);
            await _playlist.removeAt(targetIndex);
            mediaItem.add(item);
          } else {
            await _playlist.insert(targetIndex + 1, newSource);
            await _playlist.removeAt(targetIndex);
          }
          if (wasPlaying) _player.play();
        } else {
          // Default: Play Next logic
          final item = MediaItem(
            id: url ?? '',
            title: extras['title'] as String? ?? 'Unknown',
            artist: extras['artist'] as String? ?? 'TorBox',
            artUri: parseArtworkUri(extras['artworkUrl'] as String?),
            duration: extras['duration'] != null ? parseDuration(extras['duration']) : null,
            extras: requestedExtras,
          );
          final source = await _createAudioSource(item);
          final insertAt = _player.currentIndex! + 1;
          await _playlist.insert(insertAt, source);
          _originalItems.insert(insertAt, item);
          print('[AudioHandler] Play Next: Added "${item.title}" at $insertAt');
          _enrichTrackMetadata(insertAt);
        }
        return;
      }
    } else if (name == 'shuffle') {
      final currentQueue = List<MediaItem>.from(queue.value);
      if (currentQueue.isEmpty) return false;
      final currentIndex = _player.currentIndex ?? 0;

      if (_shuffleModeState == AudioServiceShuffleMode.none) {
        _shuffleModeState = AudioServiceShuffleMode.all;
        final history = currentQueue.sublist(0, currentIndex + 1);
        final upNext = currentQueue.sublist(currentIndex + 1);
        if (upNext.isEmpty) {
          playbackState.add(_transformEvent(_player.playbackEvent));
          return true;
        }
        upNext.shuffle();
        final newQueue = [...history, ...upNext];
        if (currentIndex + 1 < _playlist.length) {
          await _playlist.removeRange(currentIndex + 1, _playlist.length);
        }
        final newSources = await Future.wait(upNext.map((item) => _createAudioSource(item)));
        await _playlist.addAll(newSources);
        queue.add(newQueue);
      } else {
        _shuffleModeState = AudioServiceShuffleMode.none;
        final currentTrack = currentQueue[currentIndex];
        final matchIndex = _originalItems.indexWhere((item) => 
          item.extras?['fileId'] == currentTrack.extras?['fileId'] && 
          item.extras?['torrentId'] == currentTrack.extras?['torrentId']);

        if (matchIndex != -1) {
          final upNext = _originalItems.sublist(matchIndex + 1);
          final restoredQueue = [..._originalItems.sublist(0, matchIndex + 1), ...upNext];
          if (currentIndex + 1 < _playlist.length) {
            await _playlist.removeRange(currentIndex + 1, _playlist.length);
          }
          final newSources = await Future.wait(upNext.map((item) => _createAudioSource(item)));
          await _playlist.addAll(newSources);
          queue.add(restoredQueue);
        }
      }
      playbackState.add(_transformEvent(_player.playbackEvent));
      return true;
    } else if (name == 'updateUpNext' && extras != null) {
      final listExtras = extras['items'] as List<dynamic>?;
      if (listExtras != null && _player.currentIndex != null) {
        final currentIndex = _player.currentIndex!;
        
        final newItems = listExtras.map((e) {
          final m = e as Map<String, dynamic>;
          return MediaItem(
            id: m['url']?.toString() ?? '',
            title: m['title']?.toString() ?? 'Unknown track',
            artist: m['artist']?.toString() ?? 'TorBox',
            artUri: parseArtworkUri(m['artworkUrl'] as String?),
            duration: m['duration'] != null ? parseDuration(m['duration']) : null,
            extras: m['extras'] as Map<String, dynamic>?,
          );
        }).toList();

        // 1. Remove everything after current index
        if (currentIndex + 1 < _playlist.length) {
          await _playlist.removeRange(currentIndex + 1, _playlist.length);
        }
        
        // 2. Add new items
        final newSources = await Future.wait(newItems.map((item) => _createAudioSource(item)));
        await _playlist.addAll(newSources);

        // 3. Update _originalItems
        if (currentIndex + 1 <= _originalItems.length) {
            _originalItems.removeRange(currentIndex + 1, _originalItems.length);
        } else {
            _originalItems.length = currentIndex + 1; // Pad if needed (shouldn't happen)
        }
        _originalItems.addAll(newItems);
        
        // The queue is updated by _playlist listeners automatically.
        if (newItems.isNotEmpty) {
           _enrichQueueInRange(currentIndex + 1);
        }
      }
      return true;
    } else if (name == 'setVolume' && extras != null) {
      final volume = extras['volume'] as double?;
      if (volume != null) _player.setVolume(volume);
      return true;
    } else if (name == 'setSpeed' && extras != null) {
      final speed = extras['speed'] as double?;
      if (speed != null) _player.setSpeed(speed);
      return true;
    }
    return super.customAction(name, extras);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    final currentItem = mediaItem.value;
    final isAudiobook = currentItem?.extras?['mediaType'] == 'audiobook';
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        if (isAudiobook)
          const MediaControl(
            androidIcon: 'drawable/ic_heart_border',
            label: 'Bookmark',
            action: MediaAction.setRating,
            customAction: CustomMediaAction(name: 'bookmark'),
          )
        else
          _isCurrentTrackLiked
              ? const MediaControl(
                  androidIcon: 'drawable/ic_heart_filled',
                  label: 'Unlike',
                  action: MediaAction.setRating,
                  customAction: CustomMediaAction(name: 'unlike'),
                )
              : const MediaControl(
                  androidIcon: 'drawable/ic_heart_border',
                  label: 'Like',
                  action: MediaAction.setRating,
                  customAction: CustomMediaAction(name: 'like'),
                ),
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      shuffleMode: _shuffleModeState,
      repeatMode: _repeatModeState,
    );
  }

  Future<AudioSource> _createAudioSource(MediaItem item) async {
    final torrentId = (item.extras?['torrentId'] as num?)?.toInt();
    final fileId = (item.extras?['fileId'] as num?)?.toInt();
    String? localPath = item.extras?['localPath'] as String?;
    final uri = Uri.parse(item.id);

    // Fallback: Check DB if localPath is missing from extras
    if (localPath == null && torrentId != null && fileId != null) {
      final db = getIt<AppDatabase>();
      final dbFile = await (db.select(db.files)
            ..where((f) => f.torrentId.equals(torrentId!) & f.id.equals(fileId!)))
          .getSingleOrNull();
      localPath = dbFile?.localPath;
    }

    // 1. If we have a local persistent download, use it directly
    if (localPath != null && io.File(localPath).existsSync()) {
      final newItem = item.copyWith(
        id: Uri.file(localPath).toString(),
        extras: {...?item.extras, 'localPath': localPath},
      );
      return AudioSource.uri(
        Uri.file(localPath),
        tag: newItem,
      );
    }

    // 1b. Check if item.id itself is a local file path or file:// URI
    final isLocalFile = item.id.startsWith('/') || item.id.startsWith('file://');
    if (isLocalFile) {
      String path = item.id;
      try {
        if (item.id.startsWith('file://')) {
          path = Uri.parse(item.id).toFilePath();
        }
      } catch (e) {
        // Fallback to decoding the URI manually if it fails
        path = Uri.decodeComponent(item.id.replaceFirst('file://', ''));
      }
      if (io.File(path).existsSync()) {
        final newItem = item.copyWith(
          id: Uri.file(path).toString(),
          extras: {...?item.extras, 'localPath': path},
        );
        return AudioSource.uri(
          Uri.file(path),
          tag: newItem,
        );
      }
    }
    
    print('[AudioHandler] _createAudioSource: uri=${uri.toString().substring(0, uri.toString().length > 50 ? 50 : uri.toString().length)}...');
    
    // 2. Otherwise use LockCachingAudioSource for remote streams
    final extras = item.extras ?? {};
    final isYouTube = extras['linkType'] == 'youtube' || 
                      extras['source']?.toString().toLowerCase().contains('youtube') == true ||
                      uri.toString().contains('googlevideo.com') ||
                      uri.toString().contains('youtube.com');

    print('[AudioHandler] _createAudioSource: "${item.title}" (isYouTube: $isYouTube, linkType: ${extras['linkType']})');

    if (isYouTube) {
       print('[AudioHandler] _createAudioSource: Returning _YouTubeStreamAudioSource for "${item.title}"');
       return _YouTubeStreamAudioSource(
         this, // Pass handler for access to _yt
         item,
       );
    }

    if (item.id.contains('lazy.torbox.internal') || 
        item.id.contains('lazy.flac.internal') || 
        item.id.contains('lazy.plugin.internal') ||
        (item.extras?['linkType'] == 'soundcloud' && !item.id.startsWith('http'))) {
        print('[AudioHandler] _createAudioSource: Returning _StallingAudioSource for "${item.title}" pending resolution');
        return _StallingAudioSource(item);
    }
    
    final commonHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    if (!io.Platform.isLinux && !isYouTube && torrentId != null && fileId != null) {
      String ext = '.mp3';
      final db = getIt<AppDatabase>();
      final dbFile = await (db.select(db.files)
            ..where((f) => f.torrentId.equals(torrentId!) & f.id.equals(fileId!)))
          .getSingleOrNull();
      if (dbFile != null) {
        final dot = dbFile.name.lastIndexOf('.');
        if (dot != -1) {
          ext = dbFile.name.substring(dot).toLowerCase();
        }
      }

      final cacheFile = io.File('$_cachePath/${torrentId}_$fileId$ext');
      print('[AudioHandler] Using LockCachingAudioSource for ${item.title}. Cache exists: ${cacheFile.existsSync()}');
      return LockCachingAudioSource(
        uri,
        cacheFile: cacheFile,
        tag: item,
        headers: commonHeaders,
      );
    }
    

    return AudioSource.uri(
      uri,
      tag: item,
      headers: commonHeaders,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  Future<void> _fetchExtendedMetadata(int index) async {
    try {
      final currentQueue = queue.value;
      if (index >= currentQueue.length) return;
      final currentItem = currentQueue[index];
      
      final originalId = currentItem.extras?['originalId'] as String? ?? currentItem.id;
      
      // Retrieve existing enriched cache to avoid overwriting or losing genre/art
      var mergedItem = currentItem;
      final cachedEnriched = _enrichedItems[originalId];
      if (cachedEnriched != null) {
        mergedItem = currentItem.copyWith(
          title: cachedEnriched.title,
          artist: cachedEnriched.artist,
          album: cachedEnriched.album,
          artUri: cachedEnriched.artUri ?? currentItem.artUri,
          duration: cachedEnriched.duration ?? currentItem.duration,
          extras: {
            ...currentItem.extras ?? {},
            ...cachedEnriched.extras ?? {},
          },
        );
      }
      
      // Prevent fetching multiple times if we already got the bitrate
      if (mergedItem.extras?.containsKey('bitrate') == true || mergedItem.extras?.containsKey('sampleRate') == true) {
        return;
      }
      
      final audioMetadataService = getIt<AudioMetadataService>();
      
      if (index >= _playlist.children.length) return;
      final source = _playlist.children[index];
      
      String targetUrl = mergedItem.id;
      
      if (source is UriAudioSource) {
        targetUrl = source.uri.toString();
      } else if (source is ClippingAudioSource) {
        final child = source.child;
        if (child is UriAudioSource) targetUrl = child.uri.toString();
      }
      
      if (targetUrl.contains('lazy.')) return;
      
      // Determine file source (local or cache)
      final torrentId = (mergedItem.extras?['torrentId'] as num?)?.toInt();
      final fileId = (mergedItem.extras?['fileId'] as num?)?.toInt();

      String? localPath = mergedItem.extras?['localPath'] as String?;
      if (localPath == null && torrentId != null && fileId != null) {
        final db = getIt<AppDatabase>();
        final dbFile = await (db.select(db.files)
              ..where((f) => f.torrentId.equals(torrentId!) & f.id.equals(fileId!)))
            .getSingleOrNull();
        if (dbFile != null) {
          localPath = dbFile.localPath;
        }
      }

      String? fileToExtract = localPath;

      // If no permanent local path, wait for LockCachingAudioSource to write the cache file
      if (fileToExtract == null && torrentId != null && fileId != null) {
        String ext = '.mp3';
        final db = getIt<AppDatabase>();
        final dbFile = await (db.select(db.files)
              ..where((f) => f.torrentId.equals(torrentId!) & f.id.equals(fileId!)))
            .getSingleOrNull();
        if (dbFile != null) {
          final dot = dbFile.name.lastIndexOf('.');
          if (dot != -1) {
            ext = dbFile.name.substring(dot).toLowerCase();
          }
        }

        final cacheFile = io.File('$_cachePath/${torrentId}_$fileId$ext');
        // Wait up to 3 seconds for the playing audio handler to start writing the cache file
        for (int i = 0; i < 6; i++) {
          if (cacheFile.existsSync() && cacheFile.lengthSync() > 32768) { // 32KB is enough for header metadata
            fileToExtract = cacheFile.path;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // If we don't have a local file path (neither downloaded nor cached), do not fetch extended metadata
      if (fileToExtract == null) {
        return;
      }

      final extMeta = await audioMetadataService.fetchMetadata(fileToExtract, format: mergedItem.extras?['format'] as String?);
      if (extMeta != null && (extMeta.bitRate != null || extMeta.sampleRate != null)) {
        final updatedExtras = Map<String, dynamic>.from(mergedItem.extras ?? {});
        if (extMeta.bitRate != null) updatedExtras['bitrate'] = extMeta.bitRate;
        if (extMeta.sampleRate != null) updatedExtras['sampleRate'] = extMeta.sampleRate;
        
        final updatedItem = mergedItem.copyWith(extras: updatedExtras);
        _enrichedItems[originalId] = updatedItem;
        
        if (mediaItem.value?.id == updatedItem.id || mediaItem.value?.extras?['originalId'] == originalId) {
          mediaItem.add(updatedItem);
        }
        
        final newQueue = List<MediaItem>.from(queue.value);
        if (index < newQueue.length && (newQueue[index].id == updatedItem.id || newQueue[index].extras?['originalId'] == originalId)) {
          newQueue[index] = updatedItem;
          queue.add(newQueue);
        }
      }
    } catch (e) {
      print('[AudioHandler] Failed to fetch extended metadata: $e');
    }
  }

  Future<void> _playLinuxTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _linuxIndex = index;
    
    // Get the MediaItem from the playlist at index
    final source = _playlist.children[index];
    if (source is! IndexedAudioSource || source.tag is! MediaItem) return;
    var tagItem = source.tag as MediaItem;
    
    // Check cache/enrichment
    final originalId = tagItem.extras?['originalId'] as String? ?? tagItem.id;
    final cached = _enrichedItems[originalId];
    if (cached != null) {
      tagItem = tagItem.copyWith(
        title: cached.title,
        artist: cached.artist,
        album: cached.album,
        artUri: cached.artUri ?? tagItem.artUri,
        duration: cached.duration ?? tagItem.duration,
        extras: {
          ...tagItem.extras ?? {},
          ...cached.extras ?? {},
        },
      );
    }
    
    // Check liked state
    try {
      final db = getIt<AppDatabase>();
      final torrentId = (tagItem.extras?['torrentId'] as num?)?.toInt();
      final fileId = (tagItem.extras?['fileId'] as num?)?.toInt();
      if (torrentId != null && fileId != null) {
        final file = await (db.select(db.trackMetadata)
              ..where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId)))
            .getSingleOrNull();
        _isCurrentTrackLiked = file?.isLiked ?? false;
      } else {
        _isCurrentTrackLiked = false;
      }
    } catch (_) {
      _isCurrentTrackLiked = false;
    }
    
    // Update mediaItem
    mediaItem.add(tagItem);
    playbackState.add(_transformEvent(_player.playbackEvent));
    
    // Stalling / Resolution for lazy sources
    final isLazy = tagItem.id.contains('lazy.torbox.internal') || 
                   tagItem.id.contains('lazy.flac.internal') || 
                   tagItem.id.contains('lazy.plugin.internal') ||
                   (tagItem.extras?['linkType'] == 'soundcloud' && !tagItem.id.startsWith('http'));
                   
    if (isLazy) {
      print('[AudioHandler] Linux resolving track $index: ${tagItem.title}');
      final wasPlaying = _player.playing;
      _player.pause();
      final resolved = await _resolveTrack(index);
      if (resolved) {
        // Re-read tag item after resolution
        final updatedSource = _playlist.children[index];
        tagItem = (updatedSource as IndexedAudioSource).tag as MediaItem;
        if (wasPlaying) _player.play();
      } else {
        // Skip next
        await skipToNext();
        return;
      }
    } else {
      // Create native single AudioSource
      final singleSource = await _createAudioSource(tagItem);
      await _player.setAudioSource(singleSource);
      await _player.play();
    }
    
    // Trigger pre-fetch, enrichments, autoplay etc.
    _fetchExtendedMetadata(index);
    _prefetchNext(index);
    _enrichQueueInRange(index);
    _checkAndExtendQueue(index);
  }

  void _broadcastLinuxQueue() {
    final items = _playlist.children
        .map((s) => s is IndexedAudioSource ? s.tag as MediaItem? : null)
        .where((item) => item != null)
        .cast<MediaItem>()
        .map((item) {
          final originalId = item.extras?['originalId'] as String? ?? item.id;
          final enriched = _enrichedItems[originalId];
          if (enriched != null) {
            return enriched.copyWith(duration: item.duration ?? enriched.duration);
          }
          return item;
        })
        .toList();
    queue.add(List.unmodifiable(items));
  }
}

class _StallingAudioSource extends StreamAudioSource {
  final MediaItem item;

  _StallingAudioSource(this.item) : super(tag: item);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Hang for a while to keep player in buffering state 
    // until `_resolveTrack` completes and hot-swaps this source out.
    // We don't want to hang FOREVER because if resolution fails, 
    // we want just_audio to eventually realize it.
    await Future.delayed(const Duration(seconds: 15));
    throw Exception('Stalled source timed out');
  }
}






class _YouTubeStreamAudioSource extends StreamAudioSource {
  final MyAudioHandler handler;
  final MediaItem item;
  String? _resolvedUrl;
  int? _contentLength;
  Future<void>? _resolveFuture; // Track ongoing resolution

  _YouTubeStreamAudioSource(this.handler, this.item) : super(tag: item);

  @override
  Duration? get duration => item.duration;

  Future<void> _resolve() async {
    if (_resolvedUrl != null) return;
    if (_resolveFuture != null) return _resolveFuture!;

    _resolveFuture = _resolveInternal();
    try {
      await _resolveFuture!;
    } finally {
      _resolveFuture = null; // Always reset so concurrent is guarded but full re-resolves can happen if URL is cleared
    }
  }

  Future<void> _resolveInternal() async {
    final videoId = item.id;

    // Check the handler's session-level cache first
    final cached = handler._ytUrlCache[videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      _resolvedUrl = cached.url;
      _contentLength = cached.contentLength;
      print('[YouTubeSource] Cache HIT for $videoId (expires ${cached.expiry})');
      return;
    }

    if (_resolvedUrl != null) return;

    try {
      print('[YouTubeSource] Resolving via youtube_explode for $videoId');
      final manifest = await handler._yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: handler._ytClients,
      );
      final streamInfo = manifest.audioOnly
          .where((s) => s.container.toString().toLowerCase().contains('mp4'))
          .withHighestBitrate();
      _resolvedUrl = streamInfo.url.toString();
      _contentLength = streamInfo.size.totalBytes;
      handler._ytUrlCache[videoId] = (
        url: _resolvedUrl!,
        expiry: DateTime.now().add(const Duration(hours: 5)),
        contentLength: _contentLength,
        userAgent: 'com.google.ios.youtube/20.10.4 (iPhone; U; iOS 18.0; en_US)',
      );
      print('[YouTubeSource] Resolved and cached $videoId via youtube_explode');
    } catch (e) {
      print('[YouTubeSource] youtube_explode failed, trying InnerTube: $e');
      try {
        final service = YoutubeVideoService();
        final res = await service.resolveAudioUrlInnerTube(videoId);
        if (res == null) throw Exception('No audio URL from InnerTube');

        _resolvedUrl = res.url;
        _contentLength = null;

        // Store in session cache with a 5-hour expiry (YouTube URLs last ~6h)
        handler._ytUrlCache[videoId] = (
          url: _resolvedUrl!,
          expiry: DateTime.now().add(const Duration(hours: 5)),
          contentLength: _contentLength,
          userAgent: res.userAgent,
        );
        print('[YouTubeSource] Resolved and cached $videoId via InnerTube');
      } catch (e2) {
        print('[YouTubeSource] All resolution methods failed: $e2');
        rethrow;
      }
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    print('[YouTubeSource] REQUEST received for ${item.title} (Start: $start, End: $end)');
    await _resolve();
    
    final client = io.HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    
    int retryCount = 0;
    while (retryCount < 2) {
      if (_resolvedUrl == null) await _resolve();
      if (_resolvedUrl == null) throw Exception('Failed to resolve stream URL');
      
      final cached = handler._ytUrlCache[item.id];
      final userAgent = cached?.userAgent ?? 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip';
      
      final request = await client.getUrl(Uri.parse(_resolvedUrl!));
      
      request.headers.set('User-Agent', userAgent);
      request.headers.set('Accept', '*/*');
      
      if (userAgent.contains('com.google.android.youtube')) {
        request.headers.set('X-YouTube-Client-Name', '3'); 
        request.headers.set('X-YouTube-Client-Version', '19.05.35');
      }
      
      if (start != null || end != null) {
        final range = 'bytes=${start ?? 0}-${end ?? ''}';
        request.headers.set('Range', range);
        print('[YouTubeSource] Requesting range: $range with UA: $userAgent (Retry: $retryCount)');
      } else {
        request.headers.set('Range', 'bytes=0-');
      }

      try {
        final response = await request.close();
        if (response.statusCode == 403 || response.statusCode >= 500) {
          print('[YouTubeSource] HTTP ${response.statusCode} received, clearing URL and retrying... (Attempt $retryCount)');
          _resolvedUrl = null; 
          handler._ytUrlCache.remove(item.id); // Clear stale cache
          retryCount++;
          continue;
        }

        if (response.statusCode >= 400) {
          print('[YouTubeSource] HTTP Error ${response.statusCode} for ${item.id}');
          throw Exception('HTTP Error ${response.statusCode}');
        }

        print('[YouTubeSource] Stream opened for ${item.id} (Offset: ${start ?? 0}, Size: ${response.contentLength})');
        
        return StreamAudioResponse(
          sourceLength: _contentLength,
          contentLength: response.contentLength,
          offset: start ?? 0,
          contentType: 'audio/mp4',
          stream: response,
        );
      } catch (e) {
        if (retryCount >= 1) rethrow;
        print('[YouTubeSource] Request failed, retrying... $e');
        _resolvedUrl = null;
        retryCount++;
      }
    }
    throw Exception('Failed to open YouTube stream after all retries');
  }
}

