import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import 'music_providers.dart';

class DiscoverSectionInfo {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const DiscoverSectionInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

/// Registry of the configurable sections on the Discover screen.
const List<DiscoverSectionInfo> kDiscoverSectionInfo = [
  DiscoverSectionInfo(
    id: 'genre_pills',
    title: 'Quick Genre Pills',
    subtitle: 'Popular genre shortcut chips',
    icon: Icons.local_fire_department_outlined,
  ),
  DiscoverSectionInfo(
    id: 'trending',
    title: 'Trending Now',
    subtitle: 'Top trending songs carousel',
    icon: Icons.trending_up_rounded,
  ),
  DiscoverSectionInfo(
    id: 'vibe_swipe',
    title: 'Vibe Swipe',
    subtitle: 'Swipe to discover new music',
    icon: Icons.swipe_rounded,
  ),
  DiscoverSectionInfo(
    id: 'new_releases',
    title: 'Fresh Releases',
    subtitle: 'Latest albums & singles',
    icon: Icons.fiber_new_rounded,
  ),
  DiscoverSectionInfo(
    id: 'global_trends',
    title: 'Global Trends',
    subtitle: 'Trending artists & top tracks worldwide',
    icon: Icons.public_rounded,
  ),
  DiscoverSectionInfo(
    id: 'genres',
    title: 'Explore Genres',
    subtitle: 'Browse music by genre',
    icon: Icons.category_rounded,
  ),
  DiscoverSectionInfo(
    id: 'jiosaavn',
    title: 'JioSaavn Featured',
    subtitle: 'Featured playlists from JioSaavn',
    icon: Icons.library_music_rounded,
  ),
  DiscoverSectionInfo(
    id: 'apple_music',
    title: 'Curated For You',
    subtitle: 'Language, moods & featured hits',
    icon: Icons.auto_awesome_rounded,
  ),
];

class DiscoverCustomizationScreen extends ConsumerWidget {
  const DiscoverCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabled = settings.disabledDiscoverSections.toSet();

    final order = settings.discoverSectionOrder
        .map((id) => kDiscoverSectionInfo.where((s) => s.id == id))
        .expand((e) => e)
        .toList();
    // Include any known sections missing from a stored order (e.g. after an update).
    for (final info in kDiscoverSectionInfo) {
      if (!order.any((s) => s.id == info.id)) order.add(info);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AppleMusicGradientText(
                text: 'Customize Discover',
                fontSize: 20,
                colors: isDark
                    ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                    : [const Color(0xFF667eea), const Color(0xFF764ba2)],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reorder and toggle sections. Disabled sections are hidden and won\'t fetch any data in the background.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),

                  AppleMusicSectionHeader(title: 'Discover Sections'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = order.removeAt(oldIndex);
                        order.insert(newIndex, item);
                        ref
                            .read(settingsProvider.notifier)
                            .setDiscoverSectionOrder(order.map((s) => s.id).toList());
                      },
                      itemBuilder: (context, index) {
                        final info = order[index];
                        final enabled = !disabled.contains(info.id);
                        return Column(
                          key: ValueKey('discover-${info.id}'),
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  info.icon,
                                  color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              title: Text(
                                info.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                              subtitle: Text(
                                info.subtitle,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch.adaptive(
                                    value: enabled,
                                    activeTrackColor: theme.colorScheme.primary,
                                    onChanged: (val) =>
                                        ref.read(settingsProvider.notifier).setDiscoverSectionEnabled(info.id, val),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.drag_handle_rounded,
                                    color: isDark ? Colors.white30 : Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                            if (index != order.length - 1)
                              Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.primary),
                      title: Text('Reset to defaults',
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      onTap: () {
                        final notifier = ref.read(settingsProvider.notifier);
                        for (final info in kDiscoverSectionInfo) {
                          notifier.setDiscoverSectionEnabled(info.id, true);
                        }
                        notifier.setDiscoverSectionOrder(kDefaultDiscoverSectionOrder);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
