import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/apple_music_theme.dart';

/// A story-format (9:16) card designed to be rendered off-screen,
/// captured via RepaintBoundary.toImage(), and shared as a PNG.
class NowPlayingShareCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? artworkUrl;
  final String? album;

  const NowPlayingShareCard({
    super.key,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.album,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = artworkUrl != null && artworkUrl!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 360,
        height: 640,
        child: Stack(
        children: [
          // ── Solid base ──
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0A))),

          // ── Blurred artwork background ──
          if (hasArtwork)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Opacity(
                  opacity: 0.45,
                  child: CachedNetworkImage(
                    imageUrl: artworkUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // ── Gradient overlays for legibility ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25, 0.75, 1.0],
                  colors: [
                    Color(0xCC000000),
                    Color(0x33000000),
                    Color(0x55000000),
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top brand bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppleMusicTheme.primaryPink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ISAI',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Artwork
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.65),
                        blurRadius: 48,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: hasArtwork
                        ? CachedNetworkImage(
                            imageUrl: artworkUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),

                const SizedBox(height: 36),

                // Track name
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Artist
                Text(
                  artist,
                  style: const TextStyle(
                    color: AppleMusicTheme.primaryPink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Album (optional)
                if (album != null && album!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    album!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const Spacer(),

                // Bottom branding pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Text(
                    'Listening on Isai',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white12),
    );
  }
}
