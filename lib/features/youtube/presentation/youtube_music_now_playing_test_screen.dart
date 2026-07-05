import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/youtube_video_service.dart';
import '../data/youtube_models.dart';

class YoutubeMusicNowPlayingTestScreen extends StatefulWidget {
  const YoutubeMusicNowPlayingTestScreen({super.key});

  @override
  State<YoutubeMusicNowPlayingTestScreen> createState() => _YoutubeMusicNowPlayingTestScreenState();
}

class _YoutubeMusicNowPlayingTestScreenState extends State<YoutubeMusicNowPlayingTestScreen> {
  final _service = YoutubeVideoService();
  final _searchController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final Player _videoPlayer = Player();
  VideoController? _videoController;

  YoutubeVideoInfo? _videoInfo;
  YoutubeStreamInfo? _selectedVideo;
  YoutubeStreamInfo? _selectedAudio;
  bool _loading = false;
  String _status = 'Search for a song to start';

  bool _videoEnabled = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _muted = false;

  final _logs = <String>[];
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_videoPlayer);
    _setupAudioListeners();
    _initPlayerProperties();
  }

  Future<void> _initPlayerProperties() async {
    try {
      await (_videoPlayer.platform as dynamic).setProperty('user-agent', 'com.google.android.youtube/19.05.35 (Linux; U; Android 14; en_US; Pixel 7)');
    } catch (_) {}
  }

  void _setupAudioListeners() {
    _audioPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() => _position = p);
        if (_videoEnabled && _videoPlayer.state.playing) {
          final diff = (p - _videoPlayer.state.position).inMilliseconds.abs();
          if (diff > 1200) {
            _videoPlayer.seek(p);
          }
        }
      }
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() { if (d != null) _duration = d; });
    });
    _audioPlayer.playerStateStream.listen((s) {
      if (mounted) {
        setState(() => _isPlaying = s.playing);
        if (s.playing) {
          if (_videoEnabled) {
            _videoPlayer.seek(_audioPlayer.position);
            _videoPlayer.play();
          }
        } else {
          _videoPlayer.pause();
        }
      }
    });
    _audioPlayer.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    _videoPlayer.dispose();
    super.dispose();
  }

  void _log(String msg) {
    _logs.insert(0, '${DateTime.now().millisecondsSinceEpoch % 100000}: $msg');
    if (_logs.length > 200) _logs.removeRange(100, _logs.length);
    debugPrint('[YTMusic] $msg');
  }

  Future<void> _searchAndPlay(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _status = 'Searching...';
      _videoInfo = null;
      _videoEnabled = false;
    });

    try {
      final t0 = DateTime.now();
      final query = '${_searchController.text.trim()} official music video';
      final results = await _service.search(query);
      if (results.isEmpty) {
        setState(() { _loading = false; _status = 'No results'; });
        return;
      }

      setState(() => _status = 'Fetching streams (${results.first.title})...');
      final info = await _service.getVideoInfo(results.first.id);
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (info != null && mounted) {
        await _startPlayback(info);
        setState(() => _status = '${info.title} — ${info.author} (${ms}ms)');
      } else {
        setState(() { _loading = false; _status = 'Failed to fetch streams'; });
      }
    } catch (e) {
      setState(() { _loading = false; _status = 'Error: $e'; });
    }
    setState(() => _loading = false);
  }

  Future<void> _startPlayback(YoutubeVideoInfo info) async {
    final video = info.videoStreams.isNotEmpty
        ? info.videoStreams.firstWhere(
            (s) => s.height == 480,
            orElse: () => info.videoStreams.firstWhere(
              (s) => s.height == 360,
              orElse: () => info.videoStreams.firstWhere(
                (s) => s.height == 720,
                orElse: () => info.videoStreams.first,
              ),
            ),
          )
        : null;
    final audio = info.audioStreams.isNotEmpty ? info.audioStreams.first : null;

    _log('starting playback: video=${video?.qualityLabel} audio=${audio?.qualityLabel}');

    if (video != null) {
      await _initVideoPlayer(Uri.parse(video.url));
    }

    if (audio != null) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audio.url),
            headers: {
              'User-Agent': 'com.google.android.youtube/19.05.35 (Linux; U; Android 14; en_US; Pixel 7)',
              'Accept': '*/*',
              'X-YouTube-Client-Name': '3',
              'X-YouTube-Client-Version': '19.05.35',
            },
          ),
        );
        await _audioPlayer.play();
        _log('audio playback started');
      } catch (e) {
        _log('audio playback error: $e');
      }
    }

    setState(() {
      _videoInfo = info;
      _selectedVideo = video;
      _selectedAudio = audio;
    });
  }

  Future<void> _initVideoPlayer(Uri url) async {
    try {
      final media = Media(
        url.toString(),
        httpHeaders: {
          'Accept': '*/*',
          'X-YouTube-Client-Name': '3',
          'X-YouTube-Client-Version': '19.05.35',
        },
      );
      await _videoPlayer.open(media, play: false);
      await _videoPlayer.setVolume(0.0);
      _log('video player initialized');
    } catch (e) {
      _log('video init error: $e');
    }
  }

  Future<void> _changeVideoQuality(YoutubeStreamInfo stream) async {
    await _initVideoPlayer(Uri.parse(stream.url));
    setState(() => _selectedVideo = stream);
    if (_isPlaying) _videoPlayer.play();
  }

  void _toggleVideo() {
    setState(() {
      _videoEnabled = !_videoEnabled;
      if (!_videoEnabled) {
        _videoPlayer.pause();
      } else {
        _videoPlayer.seek(_audioPlayer.position);
        if (_isPlaying) {
          _videoPlayer.play();
        }
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seekTo(double value) {
    final pos = Duration(seconds: value.toInt());
    _audioPlayer.seek(pos);
    if (_videoEnabled) {
      _videoPlayer.seek(pos);
    }
  }

  String _formatDur(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_videoInfo == null)
                  Expanded(child: _buildEmptyState())
                else ...[
                  Expanded(child: _buildNowPlaying()),
                ],
              ],
            ),
          ),
          if (_showDebug) _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final artworkUrl = _videoInfo?.thumbnailUrl ?? '';
    final hasArtwork = artworkUrl.isNotEmpty;

    if (hasArtwork) {
      return Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: artworkUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A2E)),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ],
      );
    }
    return Container(color: const Color(0xFF121212));
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search artist / song...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          suffixIcon: _loading
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)))
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white54, size: 20),
                  onPressed: () => _searchAndPlay(_searchController.text),
                ),
        ),
        onSubmitted: _searchAndPlay,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_video_rounded, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNowPlaying() {
    final info = _videoInfo!;
    final artworkUrl = info.thumbnailUrl ?? '';
    final hasArtwork = artworkUrl.isNotEmpty;
    final dur = _duration.inSeconds > 0 ? _duration : Duration(seconds: info.durationSeconds);
    final posSec = _position.inSeconds.toDouble();
    final durSec = dur.inSeconds.toDouble();

    return Column(
      children: [
        const SizedBox(height: 8),
        // Album art area (centered, ~60% of available height)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: _buildArtworkWithVideo(hasArtwork, artworkUrl),
            ),
          ),
        ),
        // Track info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Text(info.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(info.author, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Seek bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Text(_formatDur(_position), style: const TextStyle(color: Colors.white60, fontSize: 11)),
            Expanded(child: Slider(
              value: posSec.clamp(0, durSec > 0 ? durSec : 1),
              max: durSec > 0 ? durSec : 1,
              onChanged: _seekTo,
              activeColor: Colors.white, inactiveColor: Colors.white24,
            )),
            Text(_formatDur(dur), style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ),
        // Transport controls
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28), onPressed: () {}),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 32),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28), onPressed: () {}),
        ]),
        const SizedBox(height: 8),
        // Volume + quality + debug
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
            onPressed: () {
              setState(() => _muted = !_muted);
              _audioPlayer.setVolume(_muted ? 0.0 : _volume);
            },
          ),
          SizedBox(width: 80, child: Slider(
            value: _volume, onChanged: (v) {
              setState(() => _volume = v);
              _audioPlayer.setVolume(_muted ? 0.0 : v);
            },
            activeColor: Colors.white, inactiveColor: Colors.white24,
          )),
          if (_selectedVideo != null && info.videoStreams.length > 1)
            PopupMenuButton<YoutubeStreamInfo>(
              tooltip: 'Video quality',
              icon: const Icon(Icons.hd, color: Colors.white70, size: 20),
              onSelected: _changeVideoQuality,
              itemBuilder: (_) => info.videoStreams.map((s) {
                final isSelected = s.url == _selectedVideo?.url;
                return PopupMenuItem(
                  value: s,
                  child: Text(
                    '${s.qualityLabel} | ${s.width}x${s.height}',
                    style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : null, color: isSelected ? Colors.blue : null),
                  ),
                );
              }).toList(),
            ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white38, size: 18),
            onPressed: () => setState(() => _showDebug = true),
          ),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildArtworkWithVideo(bool hasArtwork, String artworkUrl) {
    return GestureDetector(
      onTap: _toggleVideo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background: album art or video
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: _videoEnabled && _videoController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Video(
                        controller: _videoController!,
                        fit: BoxFit.contain,
                        controls: NoVideoControls,
                      ),
                    )
                  : (hasArtwork
                      ? CachedNetworkImage(imageUrl: artworkUrl, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF2A2A3E)))
                      : Container(color: const Color(0xFF2A2A3E))),
            ),
          ),
  
          // Video toggle button at center (only shown when video is NOT active)
          if (_videoInfo != null && _selectedVideo != null && !_videoEnabled)
            IgnorePointer(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showDebug = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
              child: Row(children: [
                const SizedBox(width: 8),
                const Icon(Icons.bug_report, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                const Text('Debug Logs', style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                const Spacer(),
                TextButton(onPressed: () => setState(() => _logs.clear()),
                    child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 11))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                    onPressed: () => setState(() => _showDebug = false)),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, i) => Text(
                  _logs[i],
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
