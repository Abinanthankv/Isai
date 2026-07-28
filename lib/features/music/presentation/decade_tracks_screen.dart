import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stats_providers.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';

class DecadeTracksScreen extends ConsumerWidget {
  final int decade;

  const DecadeTracksScreen({super.key, required this.decade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksByDecadeProvider(decade));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${decade}s'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F6),
      body: tracks.isEmpty
          ? Center(
              child: Text('No tracks from the ${decade}s',
                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final title = track['title'] as String? ?? '';
                final artist = track['artist'] as String? ?? '';
                final releaseYear = track['releaseYear'] as int?;
                final artworkUrl = (track['artworkUrlLow'] as String?) ?? (track['artworkUrlHigh'] as String?);
                final plays = track['plays'] as int? ?? 0;
                final fileId = track['fileId'] as int?;
                final torrentId = track['torrentId'] as int?;

                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final library = ref.read(libraryProvider);
                    TorBoxFile? file;
                    if (fileId != null && torrentId != null) {
                      file = library.allAudioFiles.where(
                        (f) => f.id == fileId && f.torrentId == torrentId,
                      ).firstOrNull;
                    }
                    file ??= library.findMatchingTrack(title, artist);
                    file ??= TorBoxFile(
                      id: title.hashCode,
                      torrentId: -1,
                      name: '$artist - $title',
                      size: 0,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NowPlayingScreen(file: file!),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: artworkUrl != null && artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artworkUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                                  ),
                                  if (releaseYear != null) ...[
                                    Text(' • ',
                                        style: TextStyle(
                                            fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                                    Text('$releaseYear',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white54 : Colors.black54)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text('$plays',
                            style: TextStyle(
                                fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
