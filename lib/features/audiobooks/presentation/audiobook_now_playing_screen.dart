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
  int _lastSleepDisplayMinutes = -1;

  // Playback speed
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  int _selectedTabIndex = 0;

  late final Stream<Duration> _throttledPositionStream;
  DateTime? _lastThrottledPositionTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _throttledPositionStream = AudioService.position.where((pos) {
      final now = DateTime.now();
      if (_lastThrottledPositionTime == null ||
          now.difference(_lastThrottledPositionTime!) >= const Duration(milliseconds: 300)) {
        _lastThrottledPositionTime = now;
        return true;
      }
      return false;
    }).asBroadcastStream();

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

  Future<void> _findEpubFile() async {
    if (_epubSearchDone) return;
    _epubSearchDone = true;

    try {
      String? folderPath;
      final bookId = widget.book.id;

      if (bookId.startsWith('local:')) {
        final rawPath = bookId.substring('local:'.length);
        final entity = FileSystemEntity.typeSync(rawPath);
        if (entity == FileSystemEntityType.directory) {
          folderPath = rawPath;
        } else {
          folderPath = File(rawPath).parent.path;
        }
      } else if (bookId.startsWith('torrent:')) {
        final settingsVal = ref.read(settingsProvider);
        final audiobookFolder = settingsVal.audiobookFolder;
        if (audiobookFolder != null && audiobookFolder.isNotEmpty) {
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

  void _accumulateSeek(int seconds) {
    final currentPosition = audioHandler.playbackState.value.position;
    if (_initialSeekPosition == null) {
      _initialSeekPosition = currentPosition;
      _accumulatedSeekSeconds = 0;
    }
    
    _accumulatedSeekSeconds += seconds;
    _seekDebounceTimer?.cancel();
    
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackStateSub?.cancel();
    _seekDebounceTimer?.cancel();
    _sleepTimer?.cancel();
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
        final remaining = end.difference(DateTime.now());
        final displayMinutes = remaining.inMinutes;
        if (displayMinutes != _lastSleepDisplayMinutes) {
          _lastSleepDisplayMinutes = displayMinutes;
          setState(() {});
        }
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
      if (bookId != widget.book.id) return;
      final position = audioHandler.playbackState.value.position;
      final duration = mediaItem.duration ?? Duration.zero;
      if (position == Duration.zero) return;
      final repo = getIt<AudiobookRepository>();
      await repo.saveProgress(
        bookId: bookId,
        chapterIndex: chapterIndex,
        positionMillis: position.inMilliseconds,
        durationMillis: duration.inMilliseconds,
        isCompleted: duration.inMilliseconds > 0 &&
            position.inMilliseconds >= duration.inMilliseconds - 5000,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailsAsync = ref.watch(bookDetailsProvider(widget.book.id));
    final chaptersAsync = ref.watch(bookChaptersProvider(widget.book.id));
    final displayBook = detailsAsync.value ?? widget.book;

    if (_showingEpub && _epubFilePath != null) {
      return Scaffold(
        body: EpubReaderScreen(
          epubFilePath: _epubFilePath!,
          bookId: widget.book.id,
          onClose: () => setState(() => _showingEpub = false),
        ),
      );
    }

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
          body: Column(
            children: [
              // Fixed Header & Controls (No blur, 100% smooth)
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Artwork Container
                      GestureDetector(
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity == null) return;
                          chaptersAsync.whenData((chapters) {
                            if (chapters.isEmpty) return;
                            final currentIdx = mediaItem?.extras?['chapterIndex'] as int? ?? 0;
                            int targetIdx;
                            if (details.primaryVelocity! < -200) {
                              targetIdx = (currentIdx + 1).clamp(0, chapters.length - 1);
                            } else if (details.primaryVelocity! > 200) {
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
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black45 : Colors.black12,
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: artworkUrl != null
                                ? ((artworkUrl.startsWith('/') || artworkUrl.startsWith('file://'))
                                    ? Image.file(
                                        File(artworkUrl.startsWith('file://') ? Uri.parse(artworkUrl).toFilePath() : artworkUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: artworkUrl,
                                        memCacheWidth: 200,
                                        memCacheHeight: 200,
                                        fit: BoxFit.cover,
                                      ))
                                : Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.book, size: 80),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title & Author
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Isolated Progress Slider (Only this updates on position tick!)
              _PerformanceProgressSlider(
                positionStream: _throttledPositionStream,
                chapters: chaptersAsync.value ?? [],
                mediaItem: mediaItem,
              ),

              const SizedBox(height: 8),

              // Playback Controls
              _PerformancePlaybackButtons(
                onSeekAccumulate: _accumulateSeek,
              ),

              const SizedBox(height: 12),

              // Tab Bar
              Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                              if (bookmarks.isEmpty) return const SizedBox.shrink();
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
                                    '${bookmarks.length}',
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

              // Expandable Lazy Virtualized List (Only builds visible items!)
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildChaptersList(context, chaptersAsync, mediaItem, widget.book)
                    : _buildBookmarksList(context, ref, widget.book),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChaptersList(
    BuildContext context,
    AsyncValue<List<AudiobookChapter>> chaptersAsync,
    MediaItem? mediaItem,
    AudiobookResult book,
  ) {
    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) {
          return const Center(child: Text('No chapters found.'));
        }
        final activeChapterIdx = (mediaItem?.extras?['chapterIndex'] as int?) ?? 0;
        final isCurrentBook = mediaItem?.extras?['bookId'] == book.id;

        return RepaintBoundary(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final isCurrent = isCurrentBook && (activeChapterIdx == index);

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCurrent
                        ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    fontSize: 13,
                  ),
                ),
                subtitle: (chapter.startTimeMillis > 0 || chapter.durationMillis > 0)
                    ? Text(
                        'Start: ${_formatDuration(Duration(milliseconds: chapter.startTimeMillis))}${chapter.durationMillis > 0 ? " • ${_formatDuration(Duration(milliseconds: chapter.durationMillis))}" : ""}',
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
                    'artist': book.author,
                    'artworkUrl': book.artworkUrl ?? '',
                    'forceReplace': true,
                    'mediaType': 'audiobook',
                    'extras': {
                      'bookId': book.id,
                      'chapterIndex': index,
                      'initialPositionMillis': chapter.startTimeMillis,
                    },
                  });
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading chapters: $e')),
    );
  }

  Widget _buildBookmarksList(BuildContext context, WidgetRef ref, AudiobookResult book) {
    final bookmarksAsync = ref.watch(audiobookBookmarksProvider(book.id));
    final bookmarks = bookmarksAsync.asData?.value ?? [];

    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('No bookmarks yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Tap the bookmark icon in the top bar to add one',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return RepaintBoundary(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ref.invalidate(audiobookBookmarksProvider(book.id));
            },
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                radius: 14,
                child: Text('${index + 1}', style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                )),
              ),
              title: Text(bm.label ?? 'Bookmark ${index + 1}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              subtitle: Text('Ch. ${bm.chapterIndex + 1} at ${_formatDuration(ts)}', style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.label_outline, size: 18),
                onPressed: () => _editBookmarkLabel(context, ref, bm),
              ),
              onTap: () async {
                final chapters = ref.read(bookChaptersProvider(book.id)).asData?.value ?? [];
                final targetCh = bm.chapterIndex < chapters.length ? chapters[bm.chapterIndex] : null;
                if (targetCh == null) return;
                await audioHandler.customAction('play', {
                  'url': targetCh.streamUrl ?? '',
                  'title': targetCh.title,
                  'artist': book.author,
                  'artworkUrl': book.artworkUrl ?? '',
                  'forceReplace': true,
                  'mediaType': 'audiobook',
                  'extras': {
                    'bookId': book.id,
                    'chapterIndex': bm.chapterIndex,
                    'initialPositionMillis': bm.positionMillis,
                  },
                });
              },
            ),
          );
        },
      ),
    );
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

/// Isolated High-Performance Progress Slider Component
class _PerformanceProgressSlider extends StatefulWidget {
  final Stream<Duration> positionStream;
  final List<AudiobookChapter> chapters;
  final MediaItem? mediaItem;

  const _PerformanceProgressSlider({
    required this.positionStream,
    required this.chapters,
    required this.mediaItem,
  });

  @override
  State<_PerformanceProgressSlider> createState() => _PerformanceProgressSliderState();
}

class _PerformanceProgressSliderState extends State<_PerformanceProgressSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final chaptersList = widget.chapters;
    final mediaItem = widget.mediaItem;
    final dur = mediaItem?.duration ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        final currentPosMs = position.inMilliseconds;
        final currentIdx = (mediaItem?.extras?['chapterIndex'] as int?) ?? 0;

        String chapterInfo = '';
        if (chaptersList.isNotEmpty) {
          final clampedIdx = currentIdx.clamp(0, chaptersList.length - 1);
          final ch = chaptersList[clampedIdx];
          final chStart = ch.startTimeMillis;
          final chEnd = (clampedIdx + 1 < chaptersList.length)
              ? chaptersList[clampedIdx + 1].startTimeMillis
              : (dur.inMilliseconds > 0 ? dur.inMilliseconds : chStart);
          final chDuration = chEnd - chStart;
          final hasOffsets = chaptersList.any((c) => c.startTimeMillis > 0);
          final chElapsed = hasOffsets ? (currentPosMs - chStart).clamp(0, chDuration) : position.inMilliseconds;
          final chRemaining = (chDuration - chElapsed).clamp(0, chDuration);
          chapterInfo = 'Chapter ${clampedIdx + 1} of ${chaptersList.length}  •  ${_formatDuration(Duration(milliseconds: chRemaining))} remaining';
        }

        double prog = 0.0;
        if (dur.inMilliseconds > 0) {
          prog = (position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        }
        final displayVal = _dragValue ?? prog;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chapterInfo.isNotEmpty)
                  Text(
                    chapterInfo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: displayVal.clamp(0.0, 1.0),
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    onChangeStart: (val) {
                      setState(() => _dragValue = val);
                    },
                    onChanged: (val) {
                      setState(() => _dragValue = val);
                    },
                    onChangeEnd: (val) {
                      _dragValue = null;
                      final seekPos = Duration(milliseconds: (val * dur.inMilliseconds).toInt());
                      audioHandler.seek(seekPos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '-${_formatDuration(Duration(milliseconds: (dur.inMilliseconds - position.inMilliseconds).clamp(0, dur.inMilliseconds)))}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

/// Isolated High-Performance Playback Buttons Component
class _PerformancePlaybackButtons extends StatelessWidget {
  final Function(int seconds) onSeekAccumulate;

  const _PerformancePlaybackButtons({required this.onSeekAccumulate});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StreamBuilder<PlaybackState>(
        stream: audioHandler.playbackState,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final playing = state?.playing ?? false;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, size: 36),
                onPressed: () => onSeekAccumulate(-10),
              ),
              const SizedBox(width: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 36,
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
                onPressed: () => onSeekAccumulate(10),
              ),
            ],
          );
        },
      ),
    );
  }
}
