import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'music_providers.dart';
import 'music_search_screen.dart';
import 'library_screen.dart';
import '../../../features/settings/presentation/settings_screen.dart';
import 'discovery_screen.dart';
import 'for_you_screen.dart';
import '../../player/presentation/mini_player.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:isai/core/updater/app_updater.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show GlassCard, LiquidRoundedSuperellipse, LiquidGlassSettings;
import 'package:permission_handler/permission_handler.dart';

class MusicHubScreen extends ConsumerStatefulWidget {
  const MusicHubScreen({super.key});

  @override
  ConsumerState<MusicHubScreen> createState() => _MusicHubScreenState();
}

class _MusicHubScreenState extends ConsumerState<MusicHubScreen> {
  int _tab = 0;
  final ValueNotifier<bool> _isNavExpanded = ValueNotifier<bool>(true);
  double _accumulatedDelta = 0.0;
  ScrollDirection _lastDirection = ScrollDirection.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(libraryProvider.notifier).loadLibrary();
      AppUpdater.checkForUpdate(context, silent: true);

      try {
        final status = await Permission.notification.status;
        if (status.isDenied) {
          await Permission.notification.request();
        }
      } catch (e) {
        print('[MusicHubScreen] Error requesting notification permission: $e');
      }
    });
  }

  @override
  void dispose() {
    _isNavExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 700;

    final pages = const [
      DiscoveryScreen(),
      ForYouScreen(),
      LibraryScreen(),
      MusicSearchScreen(),
      SettingsScreen(),
    ];

    final mainContent = Container(
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;

          if (notification is ScrollUpdateNotification) {
            if (notification.metrics.pixels <= 30.0) {
              if (!_isNavExpanded.value) {
                _isNavExpanded.value = true;
                _accumulatedDelta = 0.0;
              }
              return false;
            }

            final delta = notification.scrollDelta ?? 0.0;
            if (delta == 0.0) return false;

            final currentDirection =
                delta > 0 ? ScrollDirection.reverse : ScrollDirection.forward;

            if (_lastDirection != currentDirection) {
              _lastDirection = currentDirection;
              _accumulatedDelta = 0.0;
            }

            _accumulatedDelta += delta.abs();

            if (_accumulatedDelta >= 15.0) {
              if (currentDirection == ScrollDirection.reverse &&
                  _isNavExpanded.value) {
                _isNavExpanded.value = false;
                _accumulatedDelta = 0.0;
              } else if (currentDirection == ScrollDirection.forward &&
                  !_isNavExpanded.value) {
                _isNavExpanded.value = true;
                _accumulatedDelta = 0.0;
              }
            }
          }
          return false;
        },
        child: IndexedStack(
          index: _tab,
          children: pages,
        ),
      ),
    );

    if (isWide) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFEFEFF2),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _SideNavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) {
                    if (_tab != i) {
                      setState(() => _tab = i);
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: mainContent),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: MiniPlayer(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: mainContent,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: MiniPlayer(),
          ),
          _GlassNavigationBar(
            selectedIndex: _tab,
            isNavExpanded: _isNavExpanded,
            onDestinationSelected: (i) {
              if (_tab != i) {
                setState(() => _tab = i);
              }
              _isNavExpanded.value = true;
            },
          ),
        ],
      ),
    );
  }
}

class _SideNavigationBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _SideNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final useLiquid =
        settings.appThemeStyle == 'apple' && settings.appleUseLiquidGlass;
    final primaryColor = context.accentColor;

    final navItems = [
      (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
      (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'For You'),
      (Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
      (Icons.search_outlined, Icons.search_rounded, 'Search'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    ];

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Isai',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                  ),
                  Text(
                    'Music & Audio',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = selectedIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onDestinationSelected(index),
                    borderRadius: BorderRadius.circular(14),
                    hoverColor: primaryColor.withValues(alpha: 0.08),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? item.$2 : item.$1,
                            color: isSelected
                                ? primaryColor
                                : (isDark ? Colors.white70 : Colors.black54),
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            item.$3,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (useLiquid) {
      return Container(
        width: 230,
        margin: const EdgeInsets.all(12),
        child: GlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          useOwnLayer: true,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: LiquidGlassSettings(
            glassColor: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: settings.appleLiquidGlassOpacity),
            thickness: 20,
            blur: 12,
          ),
          child: content,
        ),
      );
    }

    return Container(
      width: 230,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161618).withValues(alpha: 0.95)
            : const Color(0xFFF7F7FA).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _GlassNavigationBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueNotifier<bool> isNavExpanded;
  final ValueChanged<int> onDestinationSelected;

  const _GlassNavigationBar({
    required this.selectedIndex,
    required this.isNavExpanded,
    required this.onDestinationSelected,
  });

  @override
  ConsumerState<_GlassNavigationBar> createState() =>
      _GlassNavigationBarState();
}

class _GlassNavigationBarState extends ConsumerState<_GlassNavigationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isNavExpanded.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    widget.isNavExpanded.addListener(_onExpandedChanged);
  }

  @override
  void didUpdateWidget(_GlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isNavExpanded != widget.isNavExpanded) {
      oldWidget.isNavExpanded.removeListener(_onExpandedChanged);
      widget.isNavExpanded.addListener(_onExpandedChanged);
    }
  }

  @override
  void dispose() {
    widget.isNavExpanded.removeListener(_onExpandedChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onExpandedChanged() {
    if (widget.isNavExpanded.value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final useLiquid =
        settings.appThemeStyle == 'apple' && settings.appleUseLiquidGlass;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final t = _animation.value;
          final height = lerpDouble(48.0, 66.0, t)!;
          final radius = lerpDouble(24.0, 32.0, t)!;
          final marginH = lerpDouble(52.0, 16.0, t)!;

          final row = Row(
            children: [
              _item(context, Icons.explore_outlined, Icons.explore_rounded,
                  'Discover', 0, t, isDark),
              _item(context, Icons.auto_awesome_outlined,
                  Icons.auto_awesome_rounded, 'For You', 1, t, isDark),
              _item(context, Icons.library_music_outlined,
                  Icons.library_music_rounded, 'Library', 2, t, isDark),
              _item(context, Icons.search_outlined, Icons.search_rounded,
                  'Search', 3, t, isDark),
              _item(context, Icons.settings_outlined, Icons.settings_rounded,
                  'Settings', 4, t, isDark),
            ],
          );

          Widget bar;
          if (useLiquid) {
            bar = SizedBox(
              height: height,
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                margin: EdgeInsets.zero,
                useOwnLayer: true,
                shape: LiquidRoundedSuperellipse(borderRadius: radius),
                settings: LiquidGlassSettings(
                  glassColor: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: settings.appleLiquidGlassOpacity),
                  thickness: 20,
                  blur: 10,
                ),
                child: row,
              ),
            );
          } else {
            bar = Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E22).withValues(alpha: 0.92)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: row,
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(marginH, 0, marginH, 14.0),
            child: bar,
          );
        },
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, IconData selectedIcon,
      String label, int index, double progress, bool isDark) {
    final isSelected = widget.selectedIndex == index;
    final primaryColor = context.accentColor;

    final textOpacity = ((progress - 0.25) / 0.75).clamp(0.0, 1.0);
    final textHeight = 14.0 * progress;

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onDestinationSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 34.0 : 28.0,
              height: isSelected ? 34.0 : 28.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.22)
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white60 : Colors.black54),
                  size: 20.0,
                ),
              ),
            ),
            if (textHeight > 0.5)
              SizedBox(
                height: textHeight,
                child: ClipRect(
                  child: Opacity(
                    opacity: textOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1.0),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 10.0,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? primaryColor
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

