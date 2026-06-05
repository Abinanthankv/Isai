import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/theme_provider.dart';
import '../../player/presentation/player_providers.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';

import '../../music/data/music_models.dart';
import 'package:isai/main.dart'; // for navigatorKey and audioHandler
import 'lastfm_provider.dart';
import 'lastfm_loved_tracks_screen.dart';

class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedSongsState = ref.watch(likedSongsProvider);
    final lastfm = ref.watch(lastfmProvider);
    final showLastfmFolder = lastfm.isConnected && lastfm.username != null;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0a0a0a), Color(0xFF000000)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFf5f5f7), Color(0xFFefeff1)],
                ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: AppleMusicTheme.primaryPink),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Liked Songs',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 48, bottom: 16),
              ),
            ),
            likedSongsState.when(
              data: (entries) {
                if (entries.isEmpty && !showLastfmFolder) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: subTextColor),
                          const SizedBox(height: 16),
                          Text(
                            'No liked songs yet',
                            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Songs you like will appear here.',
                            style: TextStyle(color: subTextColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (showLastfmFolder && index == 0) {
                        return _buildLastfmFolder(context, lastfm.username!);
                      }
                      
                      final adjustedIndex = showLastfmFolder ? index - 1 : index;
                      if (adjustedIndex >= entries.length) return null;

                      final entry = entries[adjustedIndex];
                      final trackMeta = entry.meta;
                      final file = entry.file;
                      final parsed = _parseFilename(file.displayName);

                      return AppleMusicListTile(
                        title: trackMeta.trackName ?? parsed.title,
                        subtitle: trackMeta.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox'),
                        imageUrl: trackMeta.artworkUrlLow,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.favorite, color: AppleMusicTheme.primaryPink, size: 22),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ref.read(likedSongsProvider.notifier).toggleLike(
                                  file.torrentId,
                                  file.id,
                                  true, // it is currently liked
                                  title: trackMeta.trackName ?? parsed.title,
                                  artist: trackMeta.artistName ?? parsed.artist,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.play_arrow_rounded,
                              color: isDark ? Colors.white30 : Colors.black26,
                              size: 26,
                            ),
                          ],
                        ),
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final customQueue = entries.map((e) => e.file).toList();
                          final url = file.localPath != null 
                              ? Uri.file(file.localPath!).toString() 
                              : 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';
      
                          await audioHandler.customAction('play', {
                            'url': url,
                            'title': trackMeta.trackName ?? parsed.title,
                            'artist': trackMeta.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : 'TorBox'),
                            'artworkUrl': trackMeta.artworkUrlHigh ?? trackMeta.artworkUrlLow ?? '',
                            'forceReplace': true,
                            'queue': entries.map((e) {
                              final qFile = e.file;
                              final qMeta = e.meta;
                              final qParsed = _parseFilename(qFile.displayName);
                              String fUrl = 'https://lazy.torbox.internal/${qFile.torrentId}/${qFile.id}';
                              if (qFile.torrentId == -1) {
                                fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qMeta.trackName ?? qParsed.title)}&artist=${Uri.encodeComponent(qMeta.artistName ?? qParsed.artist)}';
                              }
                              return {
                                'url': fUrl,
                                'title': qMeta.trackName ?? qParsed.title,
                                'artist': qMeta.artistName ?? qParsed.artist,
                                'artworkUrl': qMeta.artworkUrlHigh ?? qMeta.artworkUrlLow ?? '',
                                'extras': {
                                  'torrentId': qFile.torrentId,
                                  'fileId': qFile.id,
                                  'size': qFile.size,
                                  'localPath': qFile.localPath,
                                }
                              };
                            }).toList(),
                            'index': index,
                          });

                          if (context.mounted) {
                            navigatorKey.currentState?.push(
                              MaterialPageRoute(
                                builder: (context) => NowPlayingScreen(
                                  file: file,
                                  customQueue: customQueue,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                    childCount: entries.length + (showLastfmFolder ? 1 : 0),
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppleMusicTheme.primaryPink),
                  ),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Text('Error: $error', style: TextStyle(color: textColor)),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for mini player
          ],
        ),
      ),
    );
  }
}

Widget _buildLastfmFolder(BuildContext context, String username) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Column(
    children: [
      AppleMusicListTile(
        title: 'Last.fm Loved Tracks',
        subtitle: 'From @$username',
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppleMusicTheme.primaryPink.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.favorite, color: AppleMusicTheme.primaryPink),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LastfmLovedTracksScreen()),
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.only(left: 72),
        child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      ),
    ],
  );
}
({String title, String artist}) _parseFilename(String displayName) {
  var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
  name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');
  final match = RegExp(r' [-–] ').firstMatch(name);
  if (match != null) {
    return (
      artist: name.substring(0, match.start).trim(),
      title: name.substring(match.end).trim(),
    );
  }
  return (title: name.trim(), artist: '');
}
