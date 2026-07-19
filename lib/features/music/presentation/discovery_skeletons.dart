import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class _ShimmerSection extends StatelessWidget {
  final double height;
  final Widget child;

  const _ShimmerSection({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.15),
        highlightColor: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.25),
        child: child,
      ),
    );
  }
}

Widget trendingSongsSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 330,
    child: Column(
      children: [
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (_) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget newReleasesSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 240,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(width: 40, height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 10),
              Container(width: 140, height: 22, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget lastfmArtistsSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 90,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

Widget lastfmTracksSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 200,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget genreBrowseSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 170,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(width: 160, height: 22, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 120,
                height: 130,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget appleMusicPlaylistsSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 300,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(width: 180, height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget jioSaavnPlaylistsSkeleton(BuildContext context) {
  return _ShimmerSection(
    height: 185,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 130, height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 8),
            Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    ),
  );
}
