import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audiobook_providers.dart';
import '../data/audiobook_models.dart';
import '../data/audiobook_repository.dart';
import 'package:isai/main.dart'; // For audioHandler
import 'package:isai/core/di/injection.dart';
import 'epub_reader_screen.dart';
import '../../music/presentation/music_providers.dart'; // for settingsProvider

class AudiobookNowPlayingScreen extends ConsumerStatefulWidget {
  final AudiobookResult book;

  const AudiobookNowPlayingScreen({super.key, required this.book});

  @override
  ConsumerState<AudiobookNowPlayingScreen> createState() => _AudiobookNowPlayingScreenState();
}

class _AudiobookNowPlayingScreenState extends ConsumerState<AudiobookNowPlayingScreen> with WidgetsBindingObserver {
  StreamSubscription<PlaybackState>? _playbackStateSub;
  bool _wasPlaying = false;
  bool _showingEpub = false;
  String? _epubFilePath;
  bool _epubSearchDone = false;
  Timer? _seekDebounceTimer;
  int _accumulatedSeekSeconds = 0;
  Duration? _initialSeekPosition;

  // Sleep timer
  int? _sleepTimerMinutes; // null = off, otherwise minutes
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;

  // Playback speed
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  int _selectedTabIndex = 0;

  void _accumulateSeek(int seconds, Duration currentPosition) {
    if (_initialSeekPosition == null) {
      _initialSeekPosition = currentPosition;
      _accumulatedSeekSeconds = 0;
    }
    
    _accumulatedSeekSeconds += seconds;
    _seekDebounceTimer?.cancel();
    
    // Provide a brief screen feedback overlay/snackbar if needed, or simple status message
    final totalJump = _accumulatedSeekSeconds;
    final direction = totalJump > 0 ? 'Forward' : 'Rewind';
    final absSeconds = totalJump.abs();
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 32, left: 80, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(milliseconds: 600),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              totalJump > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: onPrimaryColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '$direction ${absSeconds}s',
              style: TextStyle(
                color: onPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    
    _seekDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (_initialSeekPosition != null) {
        final targetPos = _initialSeekPosition! + Duration(seconds: _accumulatedSeekSeconds);
        audioHandler.seek(targetPos < Duration.zero ? Duration.zero : targetPos);
        _initialSeekPosition = null;
        _accumulatedSeekSeconds = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Save on pause
    _playbackStateSub = audioHandler.playbackState.listen((state) {
      final isPlaying = state.playing;
      if (_wasPlaying && !isPlaying) {
        _saveCurrentProgress();
      }
      _wasPlaying = isPlaying;

      // Check sleep timer expiration
      if (_sleepTimerEnd != null && !isPlaying && _sleepTimer != null) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        if (mounted) setState(() { _sleepTimerMinutes = null; _sleepTimerEnd = null; });
      }
    });
    // Find epub file in background
    _findEpubFile();
    // Load saved playback speed
    _loadPlaybackSpeed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(audiobookBookmarksProvider(widget.book.id));
    }
  }

  Future<void> _loadPlaybackSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('audiobook_speed_${widget.book.id}') ?? 1.0;
    if (mounted) {
      setState(() => _playbackSpeed = saved);
      await audioHandler.customAction('setSpeed', {'speed': saved});
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await audioHandler.customAction('setSpeed', {'speed': speed});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('audiobook_speed_${widget.book.id}', speed);
  }

  /// Determines the local folder for this book and searches for an .epub file.
  Future<void> _findEpubFile() async {
    if (_epubSearchDone) return;
    _epubSearchDone = true;

    try {
      String? folderPath;
      final bookId = widget.book.id;

      if (bookId.startsWith('local:')) {
        // local: ID encodes the absolute path of the folder or file
        final rawPath = bookId.substring('local:'.length);
        final entity = FileSystemEntity.typeSync(rawPath);
        if (entity == FileSystemEntityType.directory) {
          folderPath = rawPath;
        } else {
          // It's a single file — use its parent folder
          folderPath = File(rawPath).parent.path;
        }
      } else if (bookId.startsWith('torrent:')) {
        // For torrent books, check if there's a downloaded subfolder in audiobookFolder
        final settingsVal = ref.read(settingsProvider);
        final audiobookFolder = settingsVal.audiobookFolder;
        if (audiobookFolder != null && audiobookFolder.isNotEmpty) {
          // Subfolders are named after the book title (sanitized)
          final sanitized = widget.book.title
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'\s+'), '_');
          folderPath = '$audiobookFolder/$sanitized';
        }
      }

      if (folderPath != null) {
        final epub = await findEpubInFolder(folderPath);
        if (mounted && epub != null) {
          setState(() => _epubFilePath = epub);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackStateSub?.cancel();
    _seekDebounceTimer?.cancel();
    _sleepTimer?.cancel();
    // Final save on screen close
    _saveCurrentProgress();
    super.dispose();
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    final end = DateTime.now().add(Duration(minutes: minutes));
    setState(() {
      _sleepTimerMinutes = minutes;
      _sleepTimerEnd = end;
    });
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(end)) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        setState(() { _sleepTimerMinutes = null; _sleepTimerEnd = null; });
        audioHandler.pause();
      } else {
        setState(() {});
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() { _sleepTimerMinutes = null; _sleepTimerEnd = null; });
  }

  Duration? get _sleepTimeRemaining {
    if (_sleepTimerEnd == null) return null;
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Sleep Timer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            _sleepTimerOption(ctx, '15 minutes', 15),
            _sleepTimerOption(ctx, '30 minutes', 30),
            _sleepTimerOption(ctx, '45 minutes', 45),
            _sleepTimerOption(ctx, '60 minutes', 60),
            if (_sleepTimerMinutes != null)
              _sleepTimerOption(ctx, 'Cancel Timer', -1),
          ],
        ),
      ),
    );
  }

  Widget _sleepTimerOption(BuildContext ctx, String label, int minutes) {
    return ListTile(
      title: Text(label),
      trailing: _sleepTimerMinutes == minutes && minutes > 0
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        if (minutes == -1) {
          _cancelSleepTimer();
        } else {
          _startSleepTimer(minutes);
        }
      },
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Playback Speed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            ..._speedOptions.map((speed) => ListTile(
              title: Text('${speed}x'),
              trailing: _playbackSpeed == speed
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _setPlaybackSpeed(speed);
              },
            )),
          ],
        ),
      ),
    );
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

          // If epub reader is active, show it instead
          if (_showingEpub && _epubFilePath != null) {
            return Scaffold(
              body: EpubReaderScreen(
                epubFilePath: _epubFilePath!,
                bookId: widget.book.id,
                onClose: () => setState(() => _showingEpub = false),
              ),
            );
          }

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
              // Sleep timer
              IconButton(
                icon: _sleepTimerMinutes != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.bedtime_rounded, size: 24),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Icon(Icons.bedtime_outlined),
                tooltip: _sleepTimerMinutes != null
                    ? 'Sleep timer: ${_sleepTimeRemaining?.inMinutes ?? 0} min remaining'
                    : 'Sleep timer',
                onPressed: _showSleepTimerSheet,
              ),
              // Bookmark
              IconButton(
                icon: ref.watch(audiobookBookmarksProvider(widget.book.id)).when(
                  data: (bookmarks) => bookmarks.isNotEmpty
                      ? Badge(
                          label: Text('${bookmarks.length}', style: const TextStyle(fontSize: 10)),
                          child: const Icon(Icons.bookmark_rounded),
                        )
                      : const Icon(Icons.bookmark_border_rounded),
                  loading: () => const Icon(Icons.bookmark_border_rounded),
                  error: (_, __) => const Icon(Icons.bookmark_border_rounded),
                ),
                tooltip: 'Bookmark',
                onPressed: () => _addBookmark(ref),
              ),
              // Playback speed
              IconButton(
                icon: Text(
                  '${_playbackSpeed}x',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _playbackSpeed != 1.0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                tooltip: 'Playback speed',
                onPressed: _showSpeedSheet,
              ),
              // Epub reader toggle — only show if epub file was found
              if (_epubFilePath != null)
                IconButton(
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: 'Read book',
                  onPressed: () => setState(() => _showingEpub = true),
                ),
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
                        // Large Artwork (swipe up/down for chapter navigation)
                        GestureDetector(
                          onVerticalDragEnd: (details) {
                            // Only trigger for fast swipes
                            if (details.primaryVelocity == null) return;
                            chaptersAsync.whenData((chapters) {
                              if (chapters.isEmpty) return;
                              final currentIdx = mediaItem?.extras?['chapterIndex'] as int? ?? 0;
                              int targetIdx;
                              if (details.primaryVelocity! < -200) {
                                // Swipe up → next chapter
                                targetIdx = (currentIdx + 1).clamp(0, chapters.length - 1);
                              } else if (details.primaryVelocity! > 200) {
                                // Swipe down → previous chapter
                                targetIdx = (currentIdx - 1).clamp(0, chapters.length - 1);
                              } else {
                                return;
                              }
                              if (targetIdx == currentIdx) return;
                              final ch = chapters[targetIdx];
                              audioHandler.customAction('play', {
                                'url': ch.streamUrl ?? '',
                                'title': ch.title,
                                'artist': widget.book.author,
                                'artworkUrl': widget.book.artworkUrl ?? '',
                                'forceReplace': true,
                                'mediaType': 'audiobook',
                                'extras': {
                                  'bookId': widget.book.id,
                                  'chapterIndex': targetIdx,
                                  'initialPositionMillis': ch.startTimeMillis,
                                },
                              });
                            });
                          },
                          child: Center(
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
                        // Chapter info + time remaining
                        chaptersAsync.when(
                          data: (chapters) {
                            if (chapters.isEmpty) return const SizedBox.shrink();
                            final chaptersList = chapters;
                            return StreamBuilder<Duration>(
                              stream: AudioService.position,
                              builder: (context, posSnapshot) {
                                final position = posSnapshot.data ?? Duration.zero;
                                final currentPosMs = position.inMilliseconds;
                                final hasOffsets = chaptersList.any((ch) => ch.startTimeMillis > 0);

                                int currentIdx = 0;
                                if (hasOffsets) {
                                  for (int i = 0; i < chaptersList.length; i++) {
                                    final start = chaptersList[i].startTimeMillis;
                                    final end = (i + 1 < chaptersList.length)
                                        ? chaptersList[i + 1].startTimeMillis
                                        : double.infinity;
                                    if (currentPosMs >= start && currentPosMs < end) {
                                      currentIdx = i;
                                      break;
                                    }
                                  }
                                } else {
                                  currentIdx = mediaItem?.extras?['chapterIndex'] as int? ?? 0;
                                }

                                final ch = chaptersList[currentIdx];
                                final chStart = ch.startTimeMillis;
                                final chEnd = (currentIdx + 1 < chaptersList.length)
                                    ? chaptersList[currentIdx + 1].startTimeMillis
                                    : (mediaItem?.duration?.inMilliseconds ?? chStart);
                                final chDuration = chEnd - chStart;
                                final chElapsed = hasOffsets ? (currentPosMs - chStart).clamp(0, chDuration) : position.inMilliseconds;
                                final chRemaining = (chDuration - chElapsed).clamp(0, chDuration);

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        'Chapter ${currentIdx + 1} of ${chaptersList.length}  •  ${_formatDuration(Duration(milliseconds: chRemaining))} remaining',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Progress
                                    StreamBuilder<Duration>(
                                      stream: AudioService.position,
                                      builder: (context, posSnapshot2) {
                                        final pos = posSnapshot2.data ?? Duration.zero;
                                        final dur = mediaItem?.duration ?? Duration.zero;
                                        double prog = 0.0;
                                        if (dur.inMilliseconds > 0) {
                                          prog = (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
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
                                                value: prog,
                                                activeColor: Theme.of(context).colorScheme.primary,
                                                inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                onChanged: (val) {
                                                  final seekPos = Duration(milliseconds: (val * dur.inMilliseconds).toInt());
                                                  audioHandler.seek(seekPos);
                                                },
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(_formatDuration(pos), style: Theme.of(context).textTheme.bodySmall),
                                                  Text(' -${_formatDuration(Duration(milliseconds: (dur.inMilliseconds - pos.inMilliseconds).clamp(0, dur.inMilliseconds)))}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
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
                                    _accumulateSeek(-10, playbackState?.position ?? Duration.zero);
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
                                    _accumulateSeek(10, playbackState?.position ?? Duration.zero);
                                  },
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Tab bar
                        Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTabIndex = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedTabIndex == 0
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Chapters',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                      color: _selectedTabIndex == 0
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTabIndex = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedTabIndex == 1
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Bookmarks',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                          color: _selectedTabIndex == 1
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Consumer(builder: (context, ref, child) {
                                        final bookmarks = ref.watch(audiobookBookmarksProvider(widget.book.id)).asData?.value ?? [];
                                        final count = bookmarks.length;
                                        if (count == 0) return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _selectedTabIndex == 1
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedTabIndex == 1
                                                    ? Theme.of(context).colorScheme.onPrimary
                                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Tab content
                        if (_selectedTabIndex == 0) ...[
                          const SizedBox(height: 8),
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
                                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
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
                        ] else ...[
                          const SizedBox(height: 8),
                          // Bookmarks
                          Consumer(builder: (context, ref, child) {
                            final bookmarksAsync = ref.watch(audiobookBookmarksProvider(widget.book.id));
                            final bookmarks = bookmarksAsync.asData?.value ?? [];
                            if (bookmarks.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(Icons.bookmark_border_rounded, size: 48,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text('No bookmarks yet',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      const SizedBox(height: 4),
                                      Text('Tap the bookmark icon in the top bar to add one',
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Clear all'),
                                      onPressed: () async {
                                        await ref.read(audiobookRepositoryProvider).deleteAllBookmarks(widget.book.id);
                                        ref.invalidate(audiobookBookmarksProvider(widget.book.id));
                                      },
                                    ),
                                  ],
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: bookmarks.length,
                                  itemBuilder: (context, index) {
                                    final bm = bookmarks[index];
                                    final ts = Duration(milliseconds: bm.positionMillis);
                                    return Dismissible(
                                      key: ValueKey(bm.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        color: Colors.red,
                                        child: const Icon(Icons.delete_outline, color: Colors.white),
                                      ),
                                      onDismissed: (_) async {
                                        await ref.read(audiobookRepositoryProvider).deleteBookmark(bm.id);
                                        ref.invalidate(audiobookBookmarksProvider(widget.book.id));
                                      },
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          radius: 18,
                                          child: Text('${index + 1}', style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          )),
                                        ),
                                        title: Text(bm.label ?? 'Bookmark ${index + 1}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: Text('Ch. ${bm.chapterIndex + 1} at ${_formatDuration(ts)}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.label_outline, size: 18),
                                          onPressed: () => _editBookmarkLabel(context, ref, bm),
                                        ),
                                        onTap: () async {
                                          final chapters = ref.read(bookChaptersProvider(widget.book.id)).asData?.value ?? [];
                                          final targetCh = bm.chapterIndex < chapters.length ? chapters[bm.chapterIndex] : null;
                                          if (targetCh == null) return;
                                          await audioHandler.customAction('play', {
                                            'url': targetCh.streamUrl ?? '',
                                            'title': targetCh.title,
                                            'artist': widget.book.author,
                                            'artworkUrl': widget.book.artworkUrl ?? '',
                                            'forceReplace': true,
                                            'mediaType': 'audiobook',
                                            'extras': {
                                              'bookId': widget.book.id,
                                              'chapterIndex': bm.chapterIndex,
                                              'initialPositionMillis': bm.positionMillis,
                                            },
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          }),
                        ],
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

  void _onBookmarkPressed(WidgetRef ref) {
    final bookmarks = ref.read(audiobookBookmarksProvider(widget.book.id)).asData?.value ?? [];
    if (bookmarks.isEmpty) {
      _addBookmark(ref);
    } else {
      _showBookmarksSheet(ref);
    }
  }

  Future<void> _addBookmark(WidgetRef ref) async {
    final mediaItem = audioHandler.mediaItem.value;
    if (mediaItem == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start playing to add a bookmark'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    final position = audioHandler.playbackState.value.position;
    final chapterIndex = mediaItem.extras?['chapterIndex'] as int? ?? 0;
    await ref.read(audiobookRepositoryProvider).addBookmark(
      widget.book.id,
      chapterIndex,
      position.inMilliseconds,
    );
    ref.invalidate(audiobookBookmarksProvider(widget.book.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark added'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _showBookmarksSheet(WidgetRef ref) {
    final bookmarksAsync = ref.read(audiobookBookmarksProvider(widget.book.id));
    final bookmarks = bookmarksAsync.asData?.value ?? [];
    if (bookmarks.isEmpty) {
      _addBookmark(ref);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _BookmarkSheet(
        book: widget.book,
        bookmarks: bookmarks,
        onSeek: (bm) async {
          Navigator.pop(ctx);
          final chapters = ref.read(bookChaptersProvider(widget.book.id)).asData?.value ?? [];
          final targetCh = bm.chapterIndex < chapters.length ? chapters[bm.chapterIndex] : null;
          if (targetCh == null) return;
          await audioHandler.customAction('play', {
            'url': targetCh.streamUrl ?? '',
            'title': targetCh.title,
            'artist': widget.book.author,
            'artworkUrl': widget.book.artworkUrl ?? '',
            'forceReplace': true,
            'mediaType': 'audiobook',
            'extras': {
              'bookId': widget.book.id,
              'chapterIndex': bm.chapterIndex,
              'initialPositionMillis': bm.positionMillis,
            },
          });
        },
        onDelete: (bm) async {
          await ref.read(audiobookRepositoryProvider).deleteBookmark(bm.id);
          ref.invalidate(audiobookBookmarksProvider(widget.book.id));
        },
        onEditLabel: (bm) => _editBookmarkLabel(context, ref, bm),
        onAdd: () {
          Navigator.pop(ctx);
          _addBookmark(ref);
        },
        repo: ref.read(audiobookRepositoryProvider),
        onChanged: () => ref.invalidate(audiobookBookmarksProvider(widget.book.id)),
      ),
    );
  }

  Future<void> _editBookmarkLabel(BuildContext context, WidgetRef ref, AudiobookBookmark bm) async {
    final controller = TextEditingController(text: bm.label ?? '');
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bookmark Label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter a label...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newLabel != null && mounted) {
      await ref.read(audiobookRepositoryProvider).updateBookmarkLabel(bm.id, newLabel);
      ref.invalidate(audiobookBookmarksProvider(widget.book.id));
    }
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

class _BookmarkSheet extends StatelessWidget {
  final AudiobookResult book;
  final List<AudiobookBookmark> bookmarks;
  final Function(AudiobookBookmark) onSeek;
  final Function(AudiobookBookmark) onDelete;
  final Function(AudiobookBookmark) onEditLabel;
  final VoidCallback onAdd;
  final AudiobookRepository repo;
  final VoidCallback onChanged;

  const _BookmarkSheet({
    required this.book,
    required this.bookmarks,
    required this.onSeek,
    required this.onDelete,
    required this.onEditLabel,
    required this.onAdd,
    required this.repo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text('Bookmarks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: onAdd,
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bm = bookmarks[index];
                final ts = Duration(milliseconds: bm.positionMillis);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    radius: 16,
                    child: Text('${index + 1}', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    )),
                  ),
                  title: Text(bm.label ?? 'Bookmark ${index + 1}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Ch. ${bm.chapterIndex + 1} at ${_fmt(ts)}'),
                  trailing: PopupMenuButton(
                    itemBuilder: (_) => [
                      PopupMenuItem(child: const Text('Edit label'), onTap: () => onEditLabel(bm)),
                      PopupMenuItem(child: const Text('Delete'), onTap: () => onDelete(bm)),
                    ],
                  ),
                  onTap: () => onSeek(bm),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
