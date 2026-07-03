import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../music/presentation/now_playing_screen.dart';
import '../../music/data/music_models.dart';
import '../../audiobooks/presentation/audiobook_now_playing_screen.dart';
import '../../audiobooks/data/audiobook_models.dart';
import '../../podcast/presentation/podcast_now_playing_screen.dart';
import '../../../main.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/glassmorphism.dart' hide GlassCard;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../music/presentation/music_providers.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show GlassCard, LiquidRoundedSuperellipse, LiquidGlassSettings;

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _getOffset(double drag, double sensitivity) {
    final absDrag = drag.abs();
    final sign = drag.sign;
    if (absDrag <= sensitivity) {
      return drag;
    } else {
      // Small rubber-band stretch past the sensitivity threshold (max 12px extra)
      final overDrag = absDrag - sensitivity;
      return sign * (sensitivity + 12.0 * (1.0 - (1.0 / (1.0 + overDrag / 15.0))));
    }
  }

  void _animateBack() {
    _slideAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.duration = const Duration(milliseconds: 250);
    _animationController.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _hasTriggeredHaptic = false;
      });
    });
  }

  void _triggerSkip(bool next) {
    if (next) {
      print('[MiniPlayer] Skip triggered: next');
      audioHandler.skipToNext();
    } else {
      print('[MiniPlayer] Skip triggered: previous');
      audioHandler.skipToPrevious();
    }

    // Elastic spring back to center
    _slideAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.duration = const Duration(milliseconds: 700);
    _animationController.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _hasTriggeredHaptic = false;
      });
      _animationController.duration = const Duration(milliseconds: 250);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      initialData: audioHandler.mediaItem.value,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();
        final isAudiobook = mediaItem.extras?['mediaType'] == 'audiobook';
        final isPodcast = mediaItem.extras?['mediaType'] == 'podcast';

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          initialData: audioHandler.playbackState.value,
          builder: (context, snapshot) {
            final playbackState = snapshot.data;
            final playing = playbackState?.playing ?? false;

            final settings = ref.watch(settingsProvider);
            final useLiquid = settings.appThemeStyle == 'apple' && settings.appleUseLiquidGlass;
            final sensitivity = settings.miniPlayerSwipeSensitivity;

            Widget miniPlayerContent = GestureDetector(
              onHorizontalDragStart: (_) {
                _animationController.stop();
                setState(() {
                  _dragOffset = 0.0;
                  _hasTriggeredHaptic = false;
                });
              },
              onHorizontalDragUpdate: (details) {
                if (settings.miniPlayerSwipeEnabled) {
                  setState(() {
                    _dragOffset += details.primaryDelta ?? 0;
                    // Provide a tactile tick as soon as they cross the threshold
                    if (_dragOffset.abs() > sensitivity && !_hasTriggeredHaptic) {
                      HapticFeedback.mediumImpact();
                      _hasTriggeredHaptic = true;
                    } else if (_dragOffset.abs() <= sensitivity && _hasTriggeredHaptic) {
                      _hasTriggeredHaptic = false;
                    }
                  });
                }
              },
              onHorizontalDragEnd: (_) {
                if (settings.miniPlayerSwipeEnabled) {
                  if (_dragOffset.abs() > sensitivity) {
                    _triggerSkip(_dragOffset < 0);
                  } else {
                    _animateBack();
                  }
                } else {
                  _animateBack();
                }
              },
              child: Container(
                height: 68,
                decoration: useLiquid
                    ? null
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ]
                              : [
                                  Colors.white.withOpacity(0.85),
                                  Colors.white.withOpacity(0.7),
                                ],
                        ),
                      ),
                child: Column(
                  children: [
                    StreamBuilder<Duration>(
                      stream: AudioService.position,
                      builder: (context, posSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final duration = mediaItem.duration ?? Duration.zero;
                        double progress = 0;
                        if (duration.inMilliseconds > 0) {
                          progress = (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                        }
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.accentColor,
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(useLiquid ? 30 : 14),
                          onTap: () {
                            final extras = mediaItem.extras;
                            if (extras != null) {
                              final file = TorBoxFile(
                                id: (extras['fileId'] as num?)?.toInt() ?? -1,
                                torrentId: (extras['torrentId'] as num?)?.toInt() ?? -1,
                                size: (extras['size'] as num?)?.toInt() ?? 0,
                                name: mediaItem.title,
                                localPath: extras['localPath'] as String?,
                              );
                              final navState = navigatorKey.currentState;
                              
                              Route createRoute() {
                                return PageRouteBuilder(
                                  transitionDuration: const Duration(milliseconds: 500),
                                  reverseTransitionDuration: const Duration(milliseconds: 450),
                                  pageBuilder: (context, animation, secondaryAnimation) {
                                    if (isAudiobook) {
                                      final bookId = extras['bookId'] as String? ?? mediaItem.id;
                                      return AudiobookNowPlayingScreen(
                                        book: AudiobookResult(
                                          id: bookId,
                                          title: mediaItem.album ?? mediaItem.title,
                                          author: mediaItem.artist ?? 'Unknown Author',
                                          artworkUrl: mediaItem.artUri?.toString(),
                                        ),
                                      );
                                    }
                                    if (isPodcast) {
                                      return PodcastNowPlayingScreen.fromMediaItem();
                                    }
                                    return NowPlayingScreen(
                                      file: file,
                                      customQueue: file.torrentId == -1 ? [file] : null,
                                    );
                                  },
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.fastOutSlowIn,
                                        reverseCurve: const ElasticInCurve(0.95),
                                      ),
                                    );
                                    return FadeTransition(
                                      opacity: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.fastOutSlowIn,
                                        reverseCurve: Curves.easeInToLinear,
                                      ),
                                      child: ScaleTransition(
                                        scale: scaleAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                                );
                              }

                              if (navState != null) {
                                navState.push(createRoute());
                              } else {
                                Navigator.push(context, createRoute());
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'artwork_hero',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: mediaItem.artUri != null
                                        ? (mediaItem.artUri!.scheme == 'file'
                                            ? Image.file(
                                                File(mediaItem.artUri!.toFilePath()),
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => _artworkPlaceholder(context),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: mediaItem.artUri.toString(),
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => _artworkPlaceholder(context),
                                                errorWidget: (context, url, error) => _artworkPlaceholder(context),
                                              ))
                                        : _artworkPlaceholder(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mediaItem.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,),
                                      ),
                                      Text(
                                        mediaItem.artist ?? 'TorBox',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark 
                                              ? Colors.white54 
                                              : Colors.black45,),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GlassIconButton(
                                      icon: playing 
                                          ? Icons.pause_rounded 
                                          : Icons.play_arrow_rounded,
                                      size: 36,
                                      gradient: LinearGradient(
                                        colors: context.accentGradient,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        if (playing) {
                                          audioHandler.pause();
                                        } else {
                                          audioHandler.play();
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {},
                                      behavior: HitTestBehavior.opaque,
                                      child: GlassIconButton(
                                        icon: (isAudiobook || isPodcast)
                                            ? Icons.stop_rounded 
                                            : Icons.skip_next_rounded,
                                        size: 32,
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          if (isAudiobook || isPodcast) {
                                            audioHandler.stop();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final borderRadius = useLiquid ? 32.0 : 16.0;
            Widget playerWidget;

            if (useLiquid) {
              playerWidget = Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  useOwnLayer: true,
                  shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
                  settings: LiquidGlassSettings(
                    glassColor: (isDark ? Colors.black : Colors.white)
                        .withOpacity(settings.appleLiquidGlassOpacity),
                    thickness: 20,
                    blur: 15,
                  ),
                  child: miniPlayerContent,
                ),
              );
            } else {
              playerWidget = Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: miniPlayerContent,
                  ),
                ),
              );
            }

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final rawOffset = _animationController.isAnimating ? _slideAnimation.value : _dragOffset;
                final offset = _getOffset(rawOffset, sensitivity);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: playerWidget,
            );
          },
        );
      },
    );
  }

  Widget _artworkPlaceholder(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.accentColor.withOpacity(0.3),
            context.accentGradientEnd.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note, 
        color: Colors.white54,
        size: 20,
      ),
    );
  }
}
