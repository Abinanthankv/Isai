import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import 'playlist_picker_sheet.dart';
import 'torrent_picker_sheet.dart';
import 'metadata_picker_sheet.dart';
import 'playlist_providers.dart';
import 'source_picker_sheet.dart';
import 'package:isai/main.dart';

class TrackActionSheet extends ConsumerWidget {
  final ItunesTrack track;
  final TorBoxFile? libraryFile;
  final int? playlistTrackId;

  const TrackActionSheet({
    super.key,
    required this.track,
    this.libraryFile,
    this.playlistTrackId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c1c1e).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Track Info Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: track.artworkUrl?.replaceAll('170x170bb', '200x200bb') ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.trackName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artistName,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppleMusicTheme.primaryPink,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 8),
              
              // Actions
              _buildActionItem(
                context,
                icon: Icons.playlist_play_rounded,
                label: 'Play Next',
                onTap: () async {
                  await _handleQueueAction(ref, 'add_next');
                  if (context.mounted) Navigator.pop(context);
                },
                isDark: isDark,
              ),
              _buildActionItem(
                context,
                icon: Icons.queue_music_rounded,
                label: 'Add to End of Queue',
                onTap: () async {
                  await _handleQueueAction(ref, 'add_to_queue');
                  if (context.mounted) Navigator.pop(context);
                },
                isDark: isDark,
              ),
              
              _buildActionItem(
                context,
                icon: Icons.add_box_rounded,
                label: 'Add to Playlist',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => PlaylistPickerSheet(track: track, libraryFile: libraryFile),
                  );
                },
                isDark: isDark,
              ),

              if (playlistTrackId != null)
                _buildActionItem(
                  context,
                  icon: Icons.playlist_remove_rounded,
                  label: 'Remove from Playlist',
                  onTap: () async {
                    await ref.read(playlistProvider.notifier).deletePlaylistTrack(playlistTrackId!);
                    if (context.mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from playlist')),
                    );
                  },
                  isDark: isDark,
                  isDestructive: true,
                ),

              if (libraryFile != null || playlistTrackId != null)
                 _buildActionItem(
                  context,
                  icon: Icons.edit_note_rounded,
                  label: 'Edit Metadata',
                  onTap: () {
                    Navigator.pop(context);
                    final fileForMeta = libraryFile ?? TorBoxFile(
                      id: -(playlistTrackId ?? 0),
                      torrentId: -1,
                      name: '${track.artistName} - ${track.trackName}',
                      size: 0,
                    );
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => MetadataPickerSheet(
                        file: fileForMeta,
                        initialQuery: '${track.artistName} ${track.trackName}',
                        initialArtist: track.artistName,
                      ),
                    );
                  },
                  isDark: isDark,
                ),
              
              if (libraryFile == null)
                _buildActionItem(
                  context,
                  icon: Icons.download_for_offline_rounded,
                  label: 'Download (Torrent)',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TorrentPickerSheet(track: track),
                    );
                  },
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQueueAction(WidgetRef ref, String action) async {
    final torrentId = libraryFile?.torrentId ?? -1;
    final fileId = libraryFile?.id ?? track.trackId;
    
    // Construct the URL for the audio handler
    String url;
    if (torrentId == -1) {
      url = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(track.trackName)}&artist=${Uri.encodeComponent(track.artistName)}';
    } else {
      url = 'https://lazy.torbox.internal/$torrentId/$fileId';
    }

    await audioHandler.customAction(action, {
      'url': url,
      'title': track.trackName,
      'artist': track.artistName,
      'album': track.collectionName,
      'artworkUrl': track.artworkUrl,
      'extras': {
        'torrentId': torrentId,
        'fileId': fileId,
        'size': libraryFile?.size ?? 0,
        'localPath': libraryFile?.localPath,
      },
    });
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black)).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.2)),
      onTap: onTap,
    );
  }
}
