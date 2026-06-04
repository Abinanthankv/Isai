import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/theme/apple_music_theme.dart';
import '../data/music_models.dart';
import 'discovery_providers.dart';
import 'source_picker_sheet.dart';

class DiscoverySwipeScreen extends ConsumerStatefulWidget {
  const DiscoverySwipeScreen({super.key});

  @override
  ConsumerState<DiscoverySwipeScreen> createState() => _DiscoverySwipeScreenState();
}

class _DiscoverySwipeScreenState extends ConsumerState<DiscoverySwipeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  StreamSubscription? _positionSubscription;

  // Swipe gesture state
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;
  bool _hasTriggeredHaptic = false; // Prevent repeated haptics during one swipe

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    _positionSubscription = ref
        .read(discoveryProvider.notifier)
        .previewPlayer
        .positionStream
        .listen((pos) {
      if (!mounted) return;
      final dur = ref.read(discoveryProvider.notifier).previewPlayer.duration;
      if (dur != null && dur.inMilliseconds > 0) {
        _progressController.value = pos.inMilliseconds / dur.inMilliseconds;
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _progressController.dispose();
    // Stop preview when leaving the screen
    try {
      ref.read(discoveryProvider.notifier).stopPreview();
    } catch (_) {}
    super.dispose();
  }

  void _onSwipeComplete(DiscoveryNotifier notifier, bool liked) {
    HapticFeedback.lightImpact();
    setState(() {
      _dragX = 0;
      _dragY = 0;
      _isDragging = false;
      _hasTriggeredHaptic = false;
    });
    if (liked) {
      notifier.likeCurrentTrack();
    } else {
      notifier.skipCurrentTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final notifier = ref.read(discoveryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          notifier.stopPreview();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () {
              notifier.stopPreview();
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Vibe Swipe',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5),
          ),
          centerTitle: true,
        ),
        body: state.isLoading && state.tracks.isEmpty
            ? _buildLoadingState()
            : state.error != null && state.tracks.isEmpty
                ? _buildErrorState(state.error!)
                : _buildSwipeBody(state, notifier, isDark, screenWidth),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
          const SizedBox(height: 24),
          Text(
            'Finding your vibe...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load tracks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeBody(DiscoveryState state, DiscoveryNotifier notifier, bool isDark, double screenWidth) {
    if (state.currentIndex >= state.tracks.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
            const SizedBox(height: 16),
            Text('Fetching more vibes...', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    final currentTrack = state.tracks[state.currentIndex];
    final hasNext = state.currentIndex + 1 < state.tracks.length;
    final nextTrack = hasNext ? state.tracks[state.currentIndex + 1] : null;

    // Swipe feedback calculations
    final swipeProgress = (_dragX / (screenWidth * 0.4)).clamp(-1.0, 1.0);
    final isLikeSwipe = swipeProgress > 0;
    final feedbackOpacity = swipeProgress.abs().clamp(0.0, 1.0);
    final rotation = swipeProgress * 0.05; // subtle rotation

    return Column(
      children: [
        // ── Card area (takes most of the screen) ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next card (behind, slightly smaller)
                if (nextTrack != null)
                  Transform.scale(
                    scale: 0.92 + (feedbackOpacity * 0.03),
                    child: _buildArtworkCard(nextTrack, isDark, isTop: false),
                  ),

                // Current card with drag gesture
                GestureDetector(
                  onPanStart: (_) => setState(() {
                    _isDragging = true;
                    _hasTriggeredHaptic = false;
                  }),
                  onPanUpdate: (details) {
                    setState(() {
                      _dragX += details.delta.dx;
                      _dragY += details.delta.dy;
                    });
                    // Haptic when crossing the decision threshold
                    if (!_hasTriggeredHaptic && _dragX.abs() > screenWidth * 0.3) {
                      _hasTriggeredHaptic = true;
                      HapticFeedback.mediumImpact();
                    }
                  },
                  onPanEnd: (details) {
                    final velocity = details.velocity.pixelsPerSecond.dx;
                    if (_dragX.abs() > screenWidth * 0.3 || velocity.abs() > 800) {
                      _onSwipeComplete(notifier, _dragX > 0);
                    } else {
                      setState(() {
                        _dragX = 0;
                        _dragY = 0;
                        _isDragging = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.identity()
                      ..translate(_dragX, _dragY * 0.3)
                      ..rotateZ(rotation),
                    transformAlignment: Alignment.center,
                    child: Stack(
                      children: [
                        _buildArtworkCard(currentTrack, isDark, isTop: true),

                        // Swipe feedback overlay
                        if (feedbackOpacity > 0.1)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Container(
                                color: (isLikeSwipe
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF5252))
                                    .withOpacity(feedbackOpacity * 0.35),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: isLikeSwipe ? -0.2 : 0.2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: (isLikeSwipe ? Colors.green : Colors.red)
                                              .withOpacity(feedbackOpacity),
                                          width: 4,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        isLikeSwipe ? 'LIKE' : 'NOPE',
                                        style: TextStyle(
                                          color: (isLikeSwipe ? Colors.green : Colors.red)
                                              .withOpacity(feedbackOpacity),
                                          fontSize: 42,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Song info + controls below the card ──
        _buildInfoSection(currentTrack, notifier, isDark),
      ],
    );
  }

  Widget _buildArtworkCard(DiscoveryTrack track, bool isDark, {required bool isTop}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          if (isTop)
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Album artwork
            CachedNetworkImage(
              imageUrl: track.artworkUrl,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppleMusicTheme.primaryPink.withOpacity(0.3),
                      AppleMusicTheme.primaryPurple.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 64),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppleMusicTheme.primaryPink.withOpacity(0.3),
                      AppleMusicTheme.primaryPurple.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // Preview progress bar at bottom of card
            if (isTop)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.black.withOpacity(0.3),
                      color: AppleMusicTheme.primaryPink,
                      minHeight: 3,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(DiscoveryTrack track, DiscoveryNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song title
          Text(
            track.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Artist name
          Text(
            track.artist,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip button
              _buildActionButton(
                icon: Icons.close_rounded,
                color: const Color(0xFFFF5252),
                size: 56,
                iconSize: 32,
                onTap: () => notifier.skipCurrentTrack(),
              ),

              // Listen Full button
              _buildActionButton(
                icon: Icons.play_arrow_rounded,
                color: AppleMusicTheme.primaryPink,
                size: 64,
                iconSize: 38,
                onTap: () {
                  // Stop preview completely
                  notifier.stopPreview();

                  final itunesTrack = ItunesTrack(
                    trackId: int.tryParse(track.id) ?? 0,
                    trackName: track.title,
                    artistName: track.artist,
                    collectionName: '',
                    artworkUrl: track.artworkUrl,
                  );

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SourcePickerSheet(
                      track: itunesTrack,
                      forceReplace: true,
                    ),
                  ).then((_) {
                    // Only resume if we're still on this screen
                    if (mounted) {
                      notifier.resumePreview();
                    }
                  });
                },
              ),

              // Like button
              _buildActionButton(
                icon: Icons.favorite_rounded,
                color: const Color(0xFF4CAF50),
                size: 56,
                iconSize: 32,
                onTap: () => notifier.likeCurrentTrack(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hint text
          Text(
            '← Swipe left to skip  •  Swipe right to like →',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.black26,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
