import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'playlist_providers.dart';
import 'music_providers.dart';
import '../data/itunes_metadata_service.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';

class PlaylistPickerSheet extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final TorBoxFile? libraryFile;

  const PlaylistPickerSheet({
    super.key,
    required this.track,
    this.libraryFile,
  });

  @override
  ConsumerState<PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends ConsumerState<PlaylistPickerSheet> {
  final _nameController = TextEditingController();
  final Set<int> _selectedPlaylistIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistProvider);
    // Force dark theme for this sheet as it's often opened from the dark NowPlayingScreen
    const isDark = true; 

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            dividerColor: Colors.white10,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add to Playlist',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_selectedPlaylistIds.isNotEmpty)
                      Text(
                        '${_selectedPlaylistIds.length} selected',
                        style: const TextStyle(
                          color: AppleMusicTheme.primaryPink,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // New Playlist Button
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppleMusicTheme.primaryPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppleMusicTheme.primaryPink),
                  ),
                  title: const Text(
                    'New Playlist...',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                  ),
                  onTap: () => _showCreatePlaylistDialog(context),
                ),
                const Divider(height: 32, color: Colors.white10),
                
                // Playlists List
                playlistsAsync.when(
                  data: (allPlaylists) {
                    final playlists = allPlaylists.where((p) => p.playlist.sourceUrl == null || !p.playlist.sourceUrl!.contains('album_')).toList();
                    if (playlists.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No playlists yet', style: TextStyle(color: Colors.white54)),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final p = playlists[index];
                          final isSelected = _selectedPlaylistIds.contains(p.playlist.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: p.playlist.artworkUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: p.playlist.artworkUrl!, 
                                      width: 48, 
                                      height: 48, 
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.white10),
                                      errorWidget: (context, url, e) => Container(color: Colors.white10, child: const Icon(Icons.music_note_rounded, color: Colors.white54)),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.white10,
                                      child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                                    ),
                            ),
                            title: Text(
                              p.playlist.name,
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                            subtitle: Text('${p.count} songs', style: const TextStyle(color: Colors.white54)),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: AppleMusicTheme.primaryPink,
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white30, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedPlaylistIds.add(p.playlist.id);
                                  } else {
                                    _selectedPlaylistIds.remove(p.playlist.id);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPlaylistIds.remove(p.playlist.id);
                                } else {
                                  _selectedPlaylistIds.add(p.playlist.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink)),
                  error: (e, _) => Text('Error loading playlists: $e', style: const TextStyle(color: Colors.redAccent)),
                ),

                const SizedBox(height: 24),
                // Done Button
                SizedBox(
                  width: double.infinity,
                  child: AppleMusicButton(
                    label: 'Done',
                    backgroundColor: _selectedPlaylistIds.isEmpty ? Colors.white24 : AppleMusicTheme.primaryPink,
                    foregroundColor: _selectedPlaylistIds.isEmpty ? Colors.white30 : Colors.white,
                    onTap: _selectedPlaylistIds.isEmpty
                        ? null
                        : () => _addTrackToSelectedPlaylists(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addTrackToSelectedPlaylists(BuildContext context) async {
    final notifier = ref.read(playlistProvider.notifier);
    int addedCount = 0;
    
    for (final playlistId in _selectedPlaylistIds) {
      bool added = false;
      if (widget.libraryFile != null) {
        final library = ref.read(libraryProvider);
        final meta = library.metadata['${widget.libraryFile!.torrentId}-${widget.libraryFile!.id}'];
        added = await notifier.addFileToPlaylist(
          playlistId, 
          widget.libraryFile!, 
          meta ?? ItunesMeta(trackName: widget.libraryFile!.name)
        );
      } else {
        added = await notifier.addTrackToPlaylist(playlistId, widget.track);
      }
      if (added) {
        addedCount++;
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addedCount > 0 
              ? 'Added to $addedCount playlist${addedCount > 1 ? 's' : ''}'
              : 'Already in the selected playlist${_selectedPlaylistIds.length > 1 ? 's' : ''}'),
          backgroundColor: addedCount > 0 ? Colors.green.withOpacity(0.9) : AppleMusicTheme.primaryPink.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                final id = await ref.read(playlistProvider.notifier).createPlaylist(name);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {
                    _selectedPlaylistIds.add(id);
                  });
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
