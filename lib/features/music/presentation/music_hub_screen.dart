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

    final pages = const [
      DiscoveryScreen(),
      ForYouScreen(),
      LibraryScreen(),
      MusicSearchScreen(),
      SettingsScreen(),
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
      ),
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

