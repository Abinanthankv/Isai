import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../music/presentation/now_playing_screen.dart';
import '../../music/data/music_models.dart';
import '../../../main.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      initialData: audioHandler.mediaItem.value,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        print('[MiniPlayer] build: mediaItem=${mediaItem?.title} (hasData: ${snapshot.hasData})');
        if (mediaItem == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          initialData: audioHandler.playbackState.value,
          builder: (context, snapshot) {
            final playbackState = snapshot.data;
            final playing = playbackState?.playing ?? false;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
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
                                AppleMusicTheme.primaryPink,
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
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
                                  if (navState != null) {
                                    navState.push(
                                      MaterialPageRoute(
                                        builder: (_) => NowPlayingScreen(
                                          file: file,
                                          customQueue: file.torrentId == -1 ? [file] : null,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NowPlayingScreen(
                                          file: file,
                                          customQueue: file.torrentId == -1 ? [file] : null,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: mediaItem.artUri != null
                                          ? CachedNetworkImage(
                                              imageUrl: mediaItem.artUri.toString(),
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => _artworkPlaceholder(),
                                              errorWidget: (context, url, error) => _artworkPlaceholder(),
                                            )
                                          : _artworkPlaceholder(),
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
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                          Text(
                                            mediaItem.artist ?? 'TorBox',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark 
                                                  ? Colors.white54 
                                                  : Colors.black45,
                                            ),
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
                                            colors: [
                                              AppleMusicTheme.primaryPink,
                                              AppleMusicTheme.primaryPurple,
                                            ],
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
                                        GlassIconButton(
                                          icon: Icons.skip_next_rounded,
                                          size: 32,
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            audioHandler.skipToNext();
                                          },
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
                ),
              ),
            );
      },
    );
  },
);
  }

  Widget _artworkPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppleMusicTheme.primaryPink.withOpacity(0.3),
            AppleMusicTheme.primaryPurple.withOpacity(0.3),
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
