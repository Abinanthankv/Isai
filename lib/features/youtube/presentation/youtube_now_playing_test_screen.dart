import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../data/youtube_models.dart';
import '../data/youtube_video_service.dart';

class YoutubeNowPlayingTestScreen extends StatefulWidget {
  final YoutubeVideoInfo info;
  final YoutubeVideoService? service;

  const YoutubeNowPlayingTestScreen({
    super.key,
    required this.info,
    this.service,
  });

  @override
  State<YoutubeNowPlayingTestScreen> createState() => _YoutubeNowPlayingTestScreenState();
}

class _YoutubeNowPlayingTestScreenState extends State<YoutubeNowPlayingTestScreen> {
  YoutubeStreamInfo? _selectedAudio;
  YoutubeStreamInfo? _selectedVideo;

  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playerStateSub;
  VideoController? _videoController;
  final Player _videoPlayer = Player();
  bool _videoInitialized = false;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _muted = false;
  String? _errorMsg;

  final _logs = <String>[];
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_videoPlayer);
    _videoInitialized = true;
    _pickBestStreams();
    _setupListeners();
    _startPlayback();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _videoPlayer.dispose();
    super.dispose();
  }

  void _log(String msg) {
    _logs.insert(0, '${DateTime.now().millisecondsSinceEpoch % 100000}: $msg');
    if (_logs.length > 200) _logs.removeRange(100, _logs.length);
    debugPrint('[YTPlayer] $msg');
  }

  void _pickBestStreams() {
    _log('picking streams: ${widget.info.videoStreams.length} video, ${widget.info.audioStreams.length} audio');

    if (widget.info.videoStreams.isNotEmpty) {
      widget.info.videoStreams.sort((a, b) => b.height.compareTo(a.height));
      _selectedVideo = widget.info.videoStreams.firstWhere(
        (s) => s.height == 480,
        orElse: () => widget.info.videoStreams.firstWhere(
          (s) => s.height == 360,
          orElse: () => widget.info.videoStreams.firstWhere(
            (s) => s.height == 720,
            orElse: () => widget.info.videoStreams.first,
          ),
        ),
      );
      _log('default video: ${_selectedVideo!.qualityLabel} ${_selectedVideo!.codec}');
    }

    if (widget.info.audioStreams.isNotEmpty) {
      widget.info.audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      _selectedAudio = widget.info.audioStreams.first;
    }

    _log('selected: video=${_selectedVideo?.qualityLabel} audio=${_selectedAudio?.qualityLabel}');
  }

  void _setupListeners() {
    _positionSub = _videoPlayer.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _playingSub = _videoPlayer.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    _durationSub = _videoPlayer.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playerStateSub = _videoPlayer.stream.completed.listen((completed) {
      if (completed) {
        _log('playback completed');
      }
    });
    _videoPlayer.stream.error.listen((errorMsg) {
      _log('Player error: $errorMsg');
      if (mounted) {
        setState(() => _errorMsg = errorMsg);
      }
    });
  }

  Future<void> _initPlayerProperties() async {
    try {
      await (_videoPlayer.platform as dynamic).setProperty('user-agent', 'com.google.android.youtube/19.05.35 (Linux; U; Android 14; en_US; Pixel 7; Build/UP1A.231005.007)');
      await (_videoPlayer.platform as dynamic).setProperty('hwdec', 'mediacodec');
      _log('Player properties set successfully (hwdec=mediacodec)');
    } catch (e) {
      _log('Failed to set global player properties: $e');
    }
  }

  Future<void> _startPlayback() async {
    try {
      await _initPlayerProperties();
      final videoStream = _selectedVideo;
      final audioStream = _selectedAudio;
      if (videoStream != null) {
        final videoUrl = await _resolveStreamUrl(videoStream);
        await _initVideoPlayer(videoUrl);

        await Future.delayed(const Duration(milliseconds: 300));
        if (audioStream != null) {
          final audioUrl = await _resolveStreamUrl(audioStream);
          _log('attaching audio stream: ${audioStream.qualityLabel}');
          await _videoPlayer.setAudioTrack(AudioTrack.uri(audioUrl.toString()));
        }
        await _videoPlayer.play();
      } else if (audioStream != null) {
        final audioUrl = await _resolveStreamUrl(audioStream);
        await _initVideoPlayer(audioUrl);
        await _videoPlayer.play();
      }
    } catch (e) {
      _log('playback error: $e');
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    }
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
      await _videoPlayer.setVolume(_muted ? 0.0 : _volume * 100.0);
      _log('playing video');
    } catch (e) {
      _log('video init error: $e');
    }
  }

  Future<Uri> _resolveStreamUrl(YoutubeStreamInfo stream) async {
    _log('using InnerTube stream URL');
    return Uri.parse(stream.url);
  }

  Future<void> _togglePlayPause() async {
    try {
      await _videoPlayer.playOrPause();
    } catch (e) {
      _log('toggle error: $e');
    }
  }

  Future<void> _seekTo(double value) async {
    try {
      await _videoPlayer.seek(Duration(seconds: value.toInt()));
    } catch (e) {
      _log('seek error: $e');
    }
  }

  Future<void> _changeQuality(YoutubeStreamInfo? stream, bool isVideo) async {
    if (stream == null) return;

    _log('switching to ${isVideo ? "video" : "audio"}: ${stream.qualityLabel}');

    try {
      final url = await _resolveStreamUrl(stream);
      final p = _position;
      final playing = _isPlaying;

      if (isVideo) {
        await _initVideoPlayer(url);
        await Future.delayed(const Duration(milliseconds: 300));
        if (_selectedAudio != null) {
          final audioUrl = await _resolveStreamUrl(_selectedAudio!);
          await _videoPlayer.setAudioTrack(AudioTrack.uri(audioUrl.toString()));
        }
        setState(() => _selectedVideo = stream);
      } else {
        await _videoPlayer.setAudioTrack(AudioTrack.uri(url.toString()));
        setState(() => _selectedAudio = stream);
      }

      await _videoPlayer.seek(p);
      if (playing) {
        await _videoPlayer.play();
      } else {
        await _videoPlayer.pause();
      }
    } catch (e) {
      _log('switch error: $e');
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _videoPlayer.setVolume(_muted ? 0.0 : _volume * 100.0);
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
          _buildControls(),
          _buildBackButton(),
          if (_errorMsg != null) _buildErrorBanner(),
          if (_showDebug) _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_videoInitialized && _videoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: _videoController!),
        ),
      );
    }
    return Container(
      color: const Color(0xFF121212),
      child: widget.info.thumbnailUrl != null
          ? Image.network(widget.info.thumbnailUrl!, fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.3))
          : null,
    );
  }

  Widget _buildControls() {
    final dur = _duration.inSeconds > 0 ? _duration : Duration(seconds: widget.info.durationSeconds);
    final posSec = _position.inSeconds.toDouble();
    final durSec = dur.inSeconds.toDouble();

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.info.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(widget.info.author, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              Text(_formatDur(_position), style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Expanded(child: Slider(
                value: posSec.clamp(0, durSec > 0 ? durSec : 1),
                max: durSec > 0 ? durSec : 1,
                onChanged: _seekTo,
                activeColor: Colors.white, inactiveColor: Colors.white24,
              )),
              Text(_formatDur(dur), style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _qualityButton(Icons.music_note, 'Audio', _selectedAudio),
              const SizedBox(width: 16),
              _iconButton(Icons.skip_previous_rounded, () {}, 28),
              const SizedBox(width: 12),
              _playButton(),
              const SizedBox(width: 12),
              _iconButton(Icons.skip_next_rounded, () {}, 28),
              const SizedBox(width: 16),
              _qualityButton(Icons.videocam, 'Video', _selectedVideo),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _iconButton(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, _toggleMute, 20),
              SizedBox(width: 80, child: Slider(
                value: _volume, onChanged: (v) {
                  setState(() => _volume = v);
                  _videoPlayer.setVolume(_muted ? 0.0 : v * 100.0);
                },
                activeColor: Colors.white, inactiveColor: Colors.white24,
              )),
              const Spacer(),
              if (!_showDebug)
                IconButton(
                  icon: const Icon(Icons.bug_report, color: Colors.white38, size: 18),
                  onPressed: () => setState(() => _showDebug = true),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.black, size: 32),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, double size) {
    return IconButton(icon: Icon(icon, color: Colors.white, size: size), onPressed: onTap);
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.error, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.white, fontSize: 12))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => setState(() => _errorMsg = null),
          ),
        ]),
      ),
    );
  }

  Widget _qualityButton(IconData icon, String label, YoutubeStreamInfo? selected) {
    final streams = label == 'Video' ? widget.info.videoStreams : widget.info.audioStreams;
    return PopupMenuButton<YoutubeStreamInfo>(
      tooltip: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          if (selected != null)
            Text('${selected.qualityLabel} | ${selected.bitrate ~/ 1000}kbps',
                style: const TextStyle(color: Colors.white38, fontSize: 8)),
        ],
      ),
      onSelected: (s) => _changeQuality(s, label == 'Video'),
      itemBuilder: (context) => streams.map((s) {
        return PopupMenuItem(
          value: s,
          child: Text('${s.qualityLabel}${s.isVideo ? " | ${s.width}x${s.height}" : ""} | ${s.bitrate ~/ 1000}kbps'
              '${s.codec.contains(",") ? " [muxed]" : ""}'
              '${s.rawStreamInfo != null ? " ✓" : ""}',
              style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
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
                TextButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                  onPressed: () => setState(() => _showDebug = false),
                ),
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