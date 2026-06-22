import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'audiobook_providers.dart';
import '../data/audiobook_models.dart';
import '../data/audiobook_repository.dart';
import 'package:isai/main.dart'; // For audioHandler
import 'package:isai/core/di/injection.dart';

class AudiobookNowPlayingScreen extends ConsumerStatefulWidget {
  final AudiobookResult book;

  const AudiobookNowPlayingScreen({super.key, required this.book});

  @override
  ConsumerState<AudiobookNowPlayingScreen> createState() => _AudiobookNowPlayingScreenState();
}

class _AudiobookNowPlayingScreenState extends ConsumerState<AudiobookNowPlayingScreen> {
  Timer? _progressSaveTimer;
  StreamSubscription<PlaybackState>? _playbackStateSub;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    // Periodic save every 15 seconds while playing
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveCurrentProgress();
    });
    // Save on pause
    _playbackStateSub = audioHandler.playbackState.listen((state) {
      final isPlaying = state.playing;
      if (_wasPlaying && !isPlaying) {
        // Transitioned from playing to paused — save progress
        _saveCurrentProgress();
      }
      _wasPlaying = isPlaying;
    });
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _playbackStateSub?.cancel();
    // Final save on screen close
    _saveCurrentProgress();
    super.dispose();
  }

  Future<void> _saveCurrentProgress() async {
    try {
      final mediaItem = audioHandler.mediaItem.value;
      if (mediaItem == null) return;
      final bookId = mediaItem.extras?['bookId'] as String?;
      final chapterIndex = mediaItem.extras?['chapterIndex'] as int?;
      if (bookId == null || chapterIndex == null) return;
      // Only save if this media item belongs to the current book
      if (bookId != widget.book.id) return;
      final position = audioHandler.playbackState.value.position;
      final duration = mediaItem.duration ?? Duration.zero;
      if (position == Duration.zero) return; // Don't save zeroed position
      final repo = getIt<AudiobookRepository>();
      await repo.saveProgress(
        bookId: bookId,
        chapterIndex: chapterIndex,
        positionMillis: position.inMilliseconds,
        durationMillis: duration.inMilliseconds,
        isCompleted: duration.inMilliseconds > 0 &&
            position.inMilliseconds >= duration.inMilliseconds - 5000,
      );
    } catch (e) {
      // Ignore errors in background save
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailsAsync = ref.watch(bookDetailsProvider(widget.book.id));
    final chaptersAsync = ref.watch(bookChaptersProvider(widget.book.id));
    final displayBook = detailsAsync.value ?? widget.book;
    
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      initialData: audioHandler.mediaItem.value,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        final title = mediaItem?.title ?? displayBook.title;
        final author = (mediaItem != null && mediaItem.title != displayBook.title)
            ? '${displayBook.title} • ${displayBook.author}'
            : displayBook.author;
        final artworkUrl = displayBook.artworkUrl ?? mediaItem?.artUri?.toString();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Now Playing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            centerTitle: true,
            actions: [
              Consumer(builder: (context, ref, child) {
                final isLibrary = displayBook.id.startsWith('torrent:');
                if (!isLibrary) return const SizedBox.shrink();
                
                final chaptersVal = chaptersAsync.value;
                if (chaptersVal == null || chaptersVal.isEmpty) return const SizedBox.shrink();
                
                final allLocal = chaptersVal.every((ch) => ch.streamUrl != null && (ch.streamUrl!.startsWith('/') || ch.streamUrl!.startsWith('file://')));
                final downloadState = ref.watch(audiobookDownloadProvider)[displayBook.id];
                final progress = downloadState?.progress ?? -100.0;
                
                if (allLocal) {
                  return IconButton(
                    icon: const Icon(Icons.offline_pin_rounded, color: Colors.green),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Download'),
                          content: Text('Are you sure you want to remove "${displayBook.title}" from local storage?'),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context),
                            ),
                            TextButton(
                              child: const Text('Delete', style: const TextStyle(color: Colors.red)),
                              onPressed: () {
                                ref.read(audiobookDownloadProvider.notifier).deleteDownloadedBook(displayBook, chaptersVal);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                
                if (downloadState != null && downloadState.status == 'downloading' && progress >= 0.0 && progress < 1.0) {
                  return IconButton(
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Icon(Icons.pause_rounded, size: 10),
                      ],
                    ),
                    onPressed: () {
                      ref.read(audiobookDownloadProvider.notifier).pauseBook(displayBook.id);
                    },
                  );
                }

                if (progress == -4.0) {
                  return IconButton(
                    icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.orange),
                    onPressed: () {
                      ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chaptersVal);
                    },
                  );
                }

                if (progress == -5.0) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                
                return IconButton(
                  icon: const Icon(Icons.download_for_offline_rounded),
                  onPressed: () {
                    ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chaptersVal);
                  },
                );
              }),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background Blur Artwork
              if (artworkUrl != null) ...[
                Positioned.fill(
                  child: Image(
                    image: (artworkUrl.startsWith('/') || artworkUrl.startsWith('file://'))
                        ? FileImage(File(artworkUrl.startsWith('file://') ? Uri.parse(artworkUrl).toFilePath() : artworkUrl)) as ImageProvider
                        : CachedNetworkImageProvider(artworkUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65),
                    ),
                  ),
                ),
              ],
              
              // Scrollable Layout
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Large Artwork
                        Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: artworkUrl != null
                                  ? ((artworkUrl.startsWith('/') || artworkUrl.startsWith('file://'))
                                      ? Image.file(
                                          File(artworkUrl.startsWith('file://') ? Uri.parse(artworkUrl).toFilePath() : artworkUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : CachedNetworkImage(imageUrl: artworkUrl, fit: BoxFit.cover))
                                  : Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.book, size: 100),
                                    ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        // Metadata Info
                        Column(
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              author,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        // Progress Bar
                        StreamBuilder<Duration>(
                          stream: AudioService.position,
                          builder: (context, posSnapshot) {
                            final position = posSnapshot.data ?? Duration.zero;
                            final duration = mediaItem?.duration ?? Duration.zero;
                            double progress = 0.0;
                            if (duration.inMilliseconds > 0) {
                              progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: progress,
                                    activeColor: Theme.of(context).colorScheme.primary,
                                    inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    onChanged: (val) {
                                      final seekPos = Duration(milliseconds: (val * duration.inMilliseconds).toInt());
                                      audioHandler.seek(seekPos);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                                      Text(_formatDuration(duration), style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        // Playback Action Controls
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final playbackState = stateSnapshot.data;
                            final playing = playbackState?.playing ?? false;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_10_rounded, size: 36),
                                  onPressed: () {
                                    final newPos = (playbackState?.position ?? Duration.zero) - const Duration(seconds: 10);
                                    audioHandler.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                  },
                                ),
                                const SizedBox(width: 24),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 40,
                                    ),
                                    onPressed: () {
                                      if (playing) {
                                        audioHandler.pause();
                                      } else {
                                        audioHandler.play();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 24),
                                IconButton(
                                  icon: const Icon(Icons.forward_10_rounded, size: 36),
                                  onPressed: () {
                                    final newPos = (playbackState?.position ?? Duration.zero) + const Duration(seconds: 10);
                                    audioHandler.seek(newPos);
                                  },
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 40),
                        // Scroll down indicator / Divider
                        Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Chapters',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        
                        // Chapter Selection List
                        chaptersAsync.when(
                          data: (chapters) {
                            if (chapters.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No chapters found.'),
                              );
                            }
                             return StreamBuilder<Duration>(
                               stream: AudioService.position,
                               initialData: Duration.zero,
                               builder: (context, posSnapshot) {
                                 final currentPos = posSnapshot.data ?? Duration.zero;
                                 final currentPosMs = currentPos.inMilliseconds;
                                 final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);

                                 return ListView.builder(
                                   shrinkWrap: true,
                                   physics: const NeverScrollableScrollPhysics(),
                                   itemCount: chapters.length,
                                   itemBuilder: (context, index) {
                                     final chapter = chapters[index];
                                     
                                     bool isCurrent = false;
                                     final isCurrentBook = mediaItem?.extras?['bookId'] == widget.book.id;
                                     if (isCurrentBook) {
                                       if (hasOffsets) {
                                         final start = chapter.startTimeMillis;
                                         final end = (index + 1 < chapters.length)
                                             ? chapters[index + 1].startTimeMillis
                                             : double.infinity;
                                         isCurrent = currentPosMs >= start && currentPosMs < end;
                                       } else {
                                         isCurrent = (mediaItem?.extras?['chapterIndex'] == index) || 
                                                     (mediaItem?.title == chapter.title);
                                       }
                                     }
                                     
                                     return ListTile(
                                       contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                       leading: Container(
                                         width: 36,
                                         height: 36,
                                         decoration: BoxDecoration(
                                           color: isCurrent 
                                               ? Theme.of(context).colorScheme.primaryContainer
                                               : Theme.of(context).colorScheme.secondaryContainer,
                                           shape: BoxShape.circle,
                                         ),
                                         child: Center(
                                           child: isCurrent 
                                               ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 18)
                                               : Text(
                                                   '${index + 1}',
                                                   style: TextStyle(
                                                     color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                         ),
                                       ),
                                       title: Text(
                                         chapter.title,
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                         style: TextStyle(
                                           fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                           color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                                         ),
                                       ),
                                       subtitle: (chapter.startTimeMillis > 0 || chapter.durationMillis > 0)
                                           ? Text(
                                               'Start: ${_formatDuration(Duration(milliseconds: chapter.startTimeMillis))}' +
                                               (chapter.durationMillis > 0 
                                                   ? ' • Duration: ${_formatDuration(Duration(milliseconds: chapter.durationMillis))}'
                                                   : ''),
                                               style: TextStyle(
                                                 fontSize: 11,
                                                 color: isCurrent 
                                                     ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                                     : Theme.of(context).colorScheme.onSurfaceVariant,
                                               ),
                                             )
                                           : null,
                                       onTap: () async {
                                         await audioHandler.customAction('play', {
                                           'url': chapter.streamUrl ?? '',
                                           'title': chapter.title,
                                           'artist': widget.book.author,
                                           'artworkUrl': widget.book.artworkUrl ?? '',
                                           'forceReplace': true,
                                           'mediaType': 'audiobook',
                                           'extras': {
                                             'bookId': widget.book.id,
                                             'chapterIndex': index,
                                             'initialPositionMillis': chapter.startTimeMillis,
                                           },
                                         });
                                       },
                                     );
                                   },
                                 );
                               },
                             );
                           },
                           loading: () => const Center(
                             child: Padding(
                               padding: EdgeInsets.all(20.0),
                               child: CircularProgressIndicator(),
                             ),
                           ),
                           error: (e, st) => Padding(
                             padding: const EdgeInsets.all(20.0),
                             child: Text('Error loading chapters: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                           ),
                         ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }
}
