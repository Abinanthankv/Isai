import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PodcastArtworkImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final double? memCacheWidth;

  const PodcastArtworkImage({
    super.key,
    this.imageUrl,
    this.width = 220,
    this.height = 220,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return _placeholder(context);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth?.toInt(),
      placeholder: (_, __) => _placeholder(context),
      errorWidget: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.podcasts, size: 40),
    );
  }
}
