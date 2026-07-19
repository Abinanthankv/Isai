import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'playlists_screen.dart';
import 'package:isai/core/theme/apple_music_theme.dart';

class PlaylistGridScreen extends StatefulWidget {
  final String title;
  final List<AppleMusicPlaylist> playlists;

  const PlaylistGridScreen({
    super.key,
    required this.title,
    required this.playlists,
  });

  @override
  State<PlaylistGridScreen> createState() => _PlaylistGridScreenState();
}

class _PlaylistGridScreenState extends State<PlaylistGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Color> _getGradientForIndex(int index) {
    final gradients = [
      AppleMusicTheme.pinkGradient,
      AppleMusicTheme.purpleGradient,
      AppleMusicTheme.orangeGradient,
      AppleMusicTheme.blueGradient,
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredPlaylists = widget.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Apple Style Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search playlists...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black54),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white54 : Colors.black54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Grid
          Expanded(
            child: filteredPlaylists.isEmpty
                ? Center(
                    child: Text(
                      'No playlists found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final crossAxisCount = maxWidth > 900 ? 4 : maxWidth > 600 ? 3 : 2;
                      final cardWidth = (maxWidth - (16 * 2) - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
                      final cardHeight = cardWidth;
                      final aspectRatio = cardWidth / (cardHeight + 50);

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: filteredPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = filteredPlaylists[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailsScreen(
                                    appleMusicPlaylist: playlist,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          playlist.artworkUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: playlist.artworkUrl,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                                    ),
                                                    child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 48),
                                                  ),
                                                )
                                              : Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                                  ),
                                                  child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 48),
                                                ),
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                                  stops: const [0.6, 1.0],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  playlist.name,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
