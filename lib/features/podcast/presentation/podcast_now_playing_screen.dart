import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../data/podcast_models.dart';
import '../data/podcast_api_service.dart';
import 'podcast_providers.dart';
import 'podcast_artwork.dart';
import 'package:isai/main.dart';
import '../../player/presentation/cast_button.dart';

class PodcastNowPlayingScreen extends ConsumerStatefulWidget {
  final PodcastEpisode episode;
  final List<PodcastEpisode>? allEpisodes;
  final int initialIndex;
  final String? podcastArtwork;
  final String podcastTitle;
  final String podcastArtist;
  final String? feedUrl;
  final String? primaryGenre;

  const PodcastNowPlayingScreen({
    super.key,
    required this.episode,
    this.allEpisodes,
    this.initialIndex = 0,
    this.podcastArtwork,
    this.podcastTitle = '',
    this.podcastArtist = '',
    this.feedUrl,
    this.primaryGenre,
  });

  factory PodcastNowPlayingScreen.fromMediaItem() {
    final item = audioHandler.mediaItem.value;
    final extras = item?.extras ?? {};
    final epId = extras['episodeId'] as String? ?? item?.id ?? '';
    final ep = PodcastEpisode(
      id: epId,
      title: extras['episodeTitle'] as String? ?? item?.title ?? '',
      description: extras['episodeDescription'] as String?,
      audioUrl: item?.id,
      durationSec: extras['episodeDuration'] as int?,
      artworkUrl: (extras['episodeArtwork'] as String?)?.isNotEmpty == true
          ? extras['episodeArtwork'] as String?
          : extras['podcastArtwork'] as String? ?? item?.artUri?.toString(),
      chaptersUrl: extras['chaptersUrl'] as String?,
    );
    return PodcastNowPlayingScreen(
      episode: ep,
      allEpisodes: [ep],
      podcastTitle: extras['podcastTitle'] as String? ?? item?.album ?? '',
      podcastArtist: extras['podcastArtist'] as String? ?? item?.artist ?? '',
      podcastArtwork: extras['podcastArtwork'] as String? ?? item?.artUri?.toString(),
      feedUrl: extras['feedUrl'] as String?,
      primaryGenre: extras['primaryGenre'] as String?,
    );
  }

  @override
  ConsumerState<PodcastNowPlayingScreen> createState() => _PodcastNowPlayingScreenState();
}

class _PodcastNowPlayingScreenState extends ConsumerState<PodcastNowPlayingScreen> {
  StreamSubscription<PlaybackState>? _playbackStateSub;
  double _playbackSpeed = 1.0;
  int? _sleepTimerMinutes;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  int _lastSleepDisplayMinutes = -1;
  bool _wasPlaying = false;
  ContinueListeningData? _savedEpisodeData;
  PodcastProgressNotifier? _progressNotifier;
  LastPlayedPodcastNotifier? _lastPlayedNotifier;
  bool _chaptersExpanded = false;
  bool _descriptionExpanded = false;
  Timer? _saveDebounceTimer;
  int _lastSavedPosition = 0;
  bool _isLoading = false;

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

  @override
  void initState() {
    super.initState();
    _progressNotifier = ref.read(podcastProgressProvider.notifier);
    _lastPlayedNotifier = ref.read(lastPlayedPodcastProvider.notifier);
    final current = audioHandler.mediaItem.value;
    final currentId = current?.id;
    final currentEpId = current?.extras?['episodeId'] as String?;
    final isAlreadyPlaying = currentId == widget.episode.audioUrl
        || currentEpId == widget.episode.id;
    if (!isAlreadyPlaying) {
      _isLoading = true;
      _play().catchError((_) { if (mounted) setState(() => _isLoading = false); });
    }
    _playbackStateSub = audioHandler.playbackState.listen((state) {
      if (_sleepTimerEnd != null && !state.playing && _sleepTimer != null) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        if (mounted) setState(() { _sleepTimerMinutes = null; _sleepTimerEnd = null; });
      }
      if (_wasPlaying && !state.playing) {
        _saveProgress();
      }
      if (!_wasPlaying && state.playing) {
        _savedEpisodeData = ContinueListeningData(
          podcastTitle: widget.podcastTitle,
          podcastArtist: widget.podcastArtist,
          podcastArtwork: widget.podcastArtwork,
          episodeArtwork: widget.episode.artworkUrl,
          episodeTitle: widget.episode.title,
          episodeId: widget.episode.id,
          audioUrl: widget.episode.audioUrl ?? widget.episode.id,
          duration: audioHandler.mediaItem.value?.duration
              ?? Duration(seconds: widget.episode.durationSec ?? 0),
          feedUrl: widget.feedUrl,
          primaryGenre: widget.primaryGenre,
        );
      }
      if (_isLoading && state.playing) {
        if (mounted) setState(() => _isLoading = false);
      }
      _wasPlaying = state.playing;
    });
  }

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _sleepTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _saveNow();
    super.dispose();
  }

  void _saveProgress() {
    final data = _savedEpisodeData;
    if (data == null) return;
    final state = audioHandler.playbackState.value;
    final pos = state.position.inMilliseconds;
    if (pos < 5000 || pos == _lastSavedPosition) return;
    _lastSavedPosition = pos;
    final key = data.episodeKey;
    final savedData = data.copyWith(
      position: Duration(milliseconds: pos),
      lastPlayedAt: DateTime.now(),
    );
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _progressNotifier?.save(key, pos);
      _lastPlayedNotifier?.save(savedData);

      final guid = widget.episode.guid ?? widget.episode.id;
      final feedUrl = widget.feedUrl ?? '';
      final dur = data.duration.inMilliseconds;
      ref.read(podcastRepositoryProvider).saveProgress(
        guid: guid,
        feedUrl: feedUrl,
        positionMillis: pos,
        durationMillis: dur,
        isCompleted: dur > 0 && (pos / dur) > 0.95,
      );
    });
  }

  void _saveNow() {
    final data = _savedEpisodeData;
    if (data == null) return;
    final state = audioHandler.playbackState.value;
    final pos = state.position.inMilliseconds;
    if (pos < 5000 || pos == _lastSavedPosition) return;
    _lastSavedPosition = pos;
    _progressNotifier?.save(data.episodeKey, pos);
    _lastPlayedNotifier?.save(data.copyWith(
      position: Duration(milliseconds: pos),
      lastPlayedAt: DateTime.now(),
    ));

    final guid = widget.episode.guid ?? widget.episode.id;
    final feedUrl = widget.feedUrl ?? '';
    final dur = data.duration.inMilliseconds;
    ref.read(podcastRepositoryProvider).saveProgress(
      guid: guid,
      feedUrl: feedUrl,
      positionMillis: pos,
      durationMillis: dur,
      isCompleted: dur > 0 && (pos / dur) > 0.95,
    );
  }

  Future<void> _play() async {
    var episode = widget.episode;
    var audioUrl = episode.audioUrl;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      final resolved = await PodcastApiService.resolveAudioUrl(audioUrl);
      if (resolved.isNotEmpty) {
        await _startPlayback(resolved);
        return;
      }
    }
    if (widget.feedUrl != null && widget.feedUrl!.isNotEmpty) {
      final fresh = await PodcastApiService().fetchEpisodes(widget.feedUrl!);
      final match = fresh.where((e) =>
        (episode.guid != null && e.guid == episode.guid) ||
        e.title == episode.title
      ).firstOrNull;
      if (match?.audioUrl != null) episode = match!;
    }
    final url = episode.audioUrl ?? '';
    final resolved = url.isNotEmpty ? await PodcastApiService.resolveAudioUrl(url) : url;
    if (resolved.isNotEmpty) {
      await _startPlayback(resolved);
    }
  }

  Future<void> _startPlayback(String resolved) async {
    await audioHandler.customAction('play', {
      'url': resolved,
      'title': widget.episode.title,
      'artist': widget.podcastArtist,
      'artworkUrl': widget.episode.artworkUrl ?? widget.podcastArtwork ?? '',
      'forceReplace': true,
      'mediaType': 'podcast',
      'extras': {
        'mediaType': 'podcast',
        'podcastTitle': widget.podcastTitle,
        'podcastArtist': widget.podcastArtist,
        'podcastArtwork': widget.podcastArtwork ?? '',
        'episodeId': widget.episode.id,
        'episodeTitle': widget.episode.title,
        'episodeDescription': widget.episode.description ?? '',
        'episodeDuration': widget.episode.durationSec,
        'feedUrl': widget.feedUrl ?? '',
        'chaptersUrl': widget.episode.chaptersUrl ?? '',
        'episodeArtwork': widget.episode.artworkUrl ?? '',
        if (widget.primaryGenre != null) 'primaryGenre': widget.primaryGenre,
      },
    });
  }

  Future<void> _playEpisode(PodcastEpisode episode, int index) async {
    _saveProgress();
    if (widget.feedUrl != null && widget.feedUrl!.isNotEmpty) {
      final fresh = await PodcastApiService().fetchEpisodes(widget.feedUrl!);
      final match = fresh.where((e) =>
        (episode.guid != null && e.guid == episode.guid) ||
        e.title == episode.title
      ).firstOrNull;
      if (match?.audioUrl != null) episode = match!;
    }
    final url = episode.audioUrl ?? '';
    final resolved = url.isNotEmpty ? await PodcastApiService.resolveAudioUrl(url) : url;
    await audioHandler.customAction('play', {
      'url': resolved,
      'title': episode.title,
      'artist': widget.podcastArtist,
      'artworkUrl': episode.artworkUrl ?? widget.podcastArtwork ?? '',
      'forceReplace': true,
      'mediaType': 'podcast',
      'extras': {
        'mediaType': 'podcast',
        'podcastTitle': widget.podcastTitle,
        'podcastArtist': widget.podcastArtist,
        'podcastArtwork': widget.podcastArtwork ?? '',
        'episodeId': episode.id,
        'episodeTitle': episode.title,
        'episodeDuration': episode.durationSec,
        'feedUrl': widget.feedUrl ?? '',
        'chaptersUrl': episode.chaptersUrl ?? '',
        'episodeArtwork': episode.artworkUrl ?? '',
        if (widget.primaryGenre != null) 'primaryGenre': widget.primaryGenre,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final artworkUrl = widget.episode.artworkUrl ?? widget.podcastArtwork;
    final podcastDescAsync = widget.feedUrl != null
        ? ref.watch(podcastDescriptionProvider(widget.feedUrl!))
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.podcastTitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          const CastButton(),
          IconButton(
            icon: _sleepTimerMinutes != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.bedtime_rounded, size: 24),
                      Positioned(top: 0, right: 0, child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      )),
                    ],
                  )
                : const Icon(Icons.bedtime_outlined),
            tooltip: _sleepTimerMinutes != null
                ? 'Sleep timer: ${_sleepTimeRemaining?.inMinutes ?? 0} min remaining'
                : 'Sleep timer',
            onPressed: _showSleepTimerSheet,
          ),
          IconButton(
            icon: Text('${_playbackSpeed}x',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: _playbackSpeed != 1.0 ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            tooltip: 'Playback speed',
            onPressed: _showSpeedSheet,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (artworkUrl != null) ...[
            Positioned.fill(
              child: PodcastArtworkImage(
                imageUrl: artworkUrl, fit: BoxFit.cover, memCacheWidth: 200,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65),
                ),
              ),
            ),
          ],
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: PodcastArtworkImage(
                        imageUrl: artworkUrl,
                        width: 220,
                        height: 220,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.episode.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.podcastTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _PodcastProgressBar(
                      onPreviousEpisode: _previousEpisode,
                      onNextEpisode: _nextEpisode,
                    ),
                    const SizedBox(height: 24),
                    _buildChaptersSection(context),
                    if (widget.episode.description != null && widget.episode.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('About this Episode'),
                      const SizedBox(height: 8),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _descriptionExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Text(
                          widget.episode.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondChild: Text(
                          widget.episode.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (widget.episode.description!.length > 200)
                        GestureDetector(
                          onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _descriptionExpanded ? 'Show less' : 'Show more',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),
                    podcastDescAsync?.when(
                      data: (desc) {
                        if (desc == null || desc.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('About the Podcast'),
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 40,
                        child: Center(child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))),
                      error: (_, __) => const SizedBox.shrink(),
                    ) ?? const SizedBox.shrink(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Loading episode…',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChaptersSection(BuildContext context) {
    final chaptersAsync = ref.watch(podcastChaptersProvider(widget.episode));
    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        final currentPos = audioHandler.playbackState.value.position.inMilliseconds;
        final currentIndex = _getCurrentChapterIndex(chapters, currentPos);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _chaptersExpanded = !_chaptersExpanded),
              child: Row(
                children: [
                  _buildSectionHeader('Chapters (${chapters.length})'),
                  const Spacer(),
                  Icon(
                    _chaptersExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!_chaptersExpanded && currentIndex >= 0)
              _buildChapterTile(chapters[currentIndex], currentIndex, true, chapters)
            else if (_chaptersExpanded)
              ...List.generate(chapters.length, (i) =>
                _buildChapterTile(chapters[i], i, i == currentIndex, chapters)),
          ],
        );
      },
      loading: () => const SizedBox(height: 40,
        child: Center(child: SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  int _getCurrentChapterIndex(List<PodcastChapter> chapters, int positionMs) {
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (positionMs >= chapters[i].startTimeMs) return i;
    }
    return -1;
  }

  Widget _buildChapterTile(PodcastChapter chapter, int index, bool isCurrent, List<PodcastChapter> chapters) {
    final theme = Theme.of(context);
    final endMs = index + 1 < chapters.length
        ? chapters[index + 1].startTimeMs
        : chapter.endTimeMs;
    final durationMs = endMs - chapter.startTimeMs;
    return InkWell(
      onTap: () {
        audioHandler.seek(Duration(milliseconds: chapter.startTimeMs));
        audioHandler.play();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isCurrent ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 2,
              height: 32,
              decoration: BoxDecoration(
                color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isCurrent ? FontWeight.bold : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(Duration(milliseconds: durationMs > 0 ? durationMs : 0)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousEpisode() {
    final pos = audioHandler.playbackState.value.position;
    final seekTarget = pos - const Duration(seconds: 60);
    audioHandler.seek(seekTarget.isNegative ? Duration.zero : seekTarget);
  }

  void _nextEpisode() {
    final pos = audioHandler.playbackState.value.position;
    audioHandler.seek(pos + const Duration(seconds: 60));
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    final end = DateTime.now().add(Duration(minutes: minutes));
    setState(() { _sleepTimerMinutes = minutes; _sleepTimerEnd = end; });
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

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
                  setState(() => _playbackSpeed = speed);
                  audioHandler.customAction('setSpeed', {'speed': speed});
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}

class _PodcastProgressBar extends StatefulWidget {
  final VoidCallback onPreviousEpisode;
  final VoidCallback onNextEpisode;

  const _PodcastProgressBar({
    required this.onPreviousEpisode,
    required this.onNextEpisode,
  });

  @override
  State<_PodcastProgressBar> createState() => _PodcastProgressBarState();
}

class _PodcastProgressBarState extends State<_PodcastProgressBar> {
  Timer? _positionTimer;
  Timer? _seekDebounceTimer;
  Duration _currentPosition = Duration.zero;
  Duration? _initialSeekPosition;
  int _accumulatedSeekSeconds = 0;

  @override
  void initState() {
    super.initState();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _currentPosition = audioHandler.playbackState.value.position;
      });
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _seekDebounceTimer?.cancel();
    super.dispose();
  }

  void _accumulateSeek(int seconds) {
    if (_initialSeekPosition == null) {
      _initialSeekPosition = _currentPosition;
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
              color: onPrimaryColor, size: 16,
            ),
            const SizedBox(width: 8),
            Text('$direction ${absSeconds}s',
              style: TextStyle(color: onPrimaryColor, fontWeight: FontWeight.bold, fontSize: 12.5),
              maxLines: 1, overflow: TextOverflow.ellipsis,
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
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final mediaItem = audioHandler.mediaItem.value;
        final duration = mediaItem?.duration ?? Duration.zero;

        double sliderValue = 0.0;
        if (duration.inMilliseconds > 0) {
          sliderValue = (_currentPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        }

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: sliderValue,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                onChanged: (val) {
                  final seekPos = Duration(milliseconds: (val * duration.inMilliseconds).toInt());
                  setState(() => _currentPosition = seekPos);
                },
                onChangeEnd: (val) {
                  final seekPos = Duration(milliseconds: (val * duration.inMilliseconds).toInt());
                  audioHandler.seek(seekPos);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_currentPosition), style: Theme.of(context).textTheme.bodySmall),
                  Text(_formatDuration(duration),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind_rounded, size: 32),
                  onPressed: widget.onPreviousEpisode,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, size: 32),
                  onPressed: () => _accumulateSeek(-10),
                ),
                const SizedBox(width: 8),
                Container(
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, size: 32),
                  onPressed: () => _accumulateSeek(10),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.fast_forward_rounded, size: 32),
                  onPressed: widget.onNextEpisode,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}
