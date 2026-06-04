import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'music_providers.dart';
import 'music_search_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import '../../../features/settings/presentation/settings_screen.dart';
import 'discovery_screen.dart';
import 'for_you_screen.dart';
import '../../player/presentation/mini_player.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../features/player/presentation/player_providers.dart';
import 'package:isai/main.dart';
import 'package:isai/core/updater/app_updater.dart';


class MusicHubScreen extends ConsumerStatefulWidget {
  const MusicHubScreen({super.key});

  @override
  ConsumerState<MusicHubScreen> createState() => _MusicHubScreenState();
}

class _MusicHubScreenState extends ConsumerState<MusicHubScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).loadLibrary();
      AppUpdater.checkForUpdate(context, silent: true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final library = ref.watch(libraryProvider);

    final pages = [
      const DiscoveryScreen(),
      const ForYouScreen(),
      const LibraryScreen(),
      const MusicSearchScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0a0a0a),
                    Color(0xFF000000),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFf5f5f7),
                    Color(0xFFefeff1),
                  ],
                ),
        ),
        child: pages[_tab],

      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(
            builder: (context, ref, child) {
              final isPlayerOpen = ref.watch(isPlayerOpenProvider);
              return Visibility(
                visible: !isPlayerOpen,
                maintainState: true,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: MiniPlayer(),
                ),
              );
            },
          ),
          _GlassNavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
          ),
        ],
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _GlassNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore,
                  label: 'Discover',
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_outlined,
                  selectedIcon: Icons.auto_awesome,
                  label: 'For You',
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                _NavItem(
                  icon: Icons.library_music_outlined,
                  selectedIcon: Icons.library_music,
                  label: 'Library',
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                _NavItem(
                  icon: Icons.search,
                  selectedIcon: Icons.search,
                  label: 'Search',
                  isSelected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppleMusicTheme.primaryPink.withOpacity(0.2),
                    AppleMusicTheme.primaryPurple.withOpacity(0.2),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? AppleMusicTheme.primaryPink
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black45),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppleMusicTheme.primaryPink
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
