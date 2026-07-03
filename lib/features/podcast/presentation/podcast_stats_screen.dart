import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isai/main.dart';
import 'podcast_providers.dart';
import 'podcast_artwork.dart';

class PodcastStatsScreen extends ConsumerWidget {
  const PodcastStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(podcastStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Podcast Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OverviewCards(stats: stats),
          const SizedBox(height: 24),
          if (stats.topPodcasts.isNotEmpty) ...[
            Text('Top Podcasts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _TopPodcastsList(podcasts: stats.topPodcasts),
            const SizedBox(height: 24),
          ],
          if (stats.genreBreakdown.isNotEmpty) ...[
            Text('Genres', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _GenreBreakdownList(genres: stats.genreBreakdown),
            const SizedBox(height: 24),
          ],
          if (stats.recentActivity.isNotEmpty) ...[
            Text('Recent Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...stats.recentActivity.map((item) => _RecentActivityTile(item: item)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final PodcastStatsData stats;

  const _OverviewCards({required this.stats});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _StatCard(
        label: 'Total Listening',
        value: _formatDuration(stats.totalListeningTime),
        icon: Icons.access_time_rounded,
        color: theme.colorScheme.primary,
      ),
      _StatCard(
        label: 'Completed',
        value: '${stats.completedEpisodes}',
        icon: Icons.check_circle_rounded,
        color: Colors.greenAccent,
      ),
      _StatCard(
        label: 'In Progress',
        value: '${stats.inProgressEpisodes}',
        icon: Icons.play_circle_rounded,
        color: theme.colorScheme.tertiary,
      ),
      _StatCard(
        label: 'Started',
        value: '${stats.startedEpisodes}',
        icon: Icons.fiber_manual_record_rounded,
        color: theme.colorScheme.secondary,
      ),
      _StatCard(
        label: 'Followed',
        value: '${stats.followedPodcasts}',
        icon: Icons.favorite_rounded,
        color: Colors.redAccent,
      ),
      _StatCard(
        label: 'Shows Played',
        value: '${stats.uniquePodcastsPlayed}',
        icon: Icons.podcasts_rounded,
        color: Colors.orangeAccent,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((c) => SizedBox(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        child: c,
      )).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPodcastsList extends StatelessWidget {
  final List<({String title, int count})> podcasts;

  const _TopPodcastsList({required this.podcasts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(podcasts.length, (i) {
          final p = podcasts[i];
          final isLast = i == podcasts.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: isLast ? 12 : 0,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text(
                  '${p.count} ep',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _GenreBreakdownList extends StatelessWidget {
  final List<({String genre, int count})> genres;

  const _GenreBreakdownList({required this.genres});

  static const Map<String, IconData> _genreIcons = {
    'Comedy': Icons.theater_comedy_rounded,
    'Technology': Icons.computer_rounded,
    'Science': Icons.science_rounded,
    'News': Icons.newspaper_rounded,
    'Music': Icons.music_note_rounded,
    'History': Icons.history_rounded,
    'True Crime': Icons.local_police_rounded,
    'Business': Icons.business_rounded,
    'Health': Icons.favorite_rounded,
    'Education': Icons.school_rounded,
    'Sports': Icons.sports_rounded,
    'TV & Film': Icons.tv_rounded,
    'Religion': Icons.church_rounded,
    'Society': Icons.people_rounded,
    'Arts': Icons.palette_rounded,
    'Fiction': Icons.auto_stories_rounded,
    'Kids & Family': Icons.family_restroom_rounded,
    'Leisure': Icons.self_improvement_rounded,
    'Government': Icons.account_balance_rounded,
    'How To': Icons.tips_and_updates_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = genres.fold(0, (int sum, g) => sum + g.count);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(genres.length, (i) {
          final g = genres[i];
          final fraction = total > 0 ? g.count / total : 0.0;
          final isLast = i == genres.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                Icon(_genreIcons[g.genre] ?? Icons.category_rounded,
                  size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.genre,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('${g.count} ep',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  final ContinueListeningData item;

  const _RecentActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.duration.inMilliseconds > 0
        ? (item.position.inMilliseconds / item.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final dateStr = item.lastPlayedAt != null
        ? '${item.lastPlayedAt!.month}/${item.lastPlayedAt!.day}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PodcastArtworkImage(
              imageUrl: item.episodeArtwork ?? item.podcastArtwork,
              width: 48,
              height: 48,
            ),
          ),
          title: Text(
            item.episodeTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                item.podcastTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(dateStr, style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
