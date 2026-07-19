import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'player_visuals.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../main.dart';
import 'music_providers.dart';

class PlayerCustomizationScreen extends ConsumerWidget {
  const PlayerCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                text: 'Customize Player',
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
                children: [
                  // --- Live Preview ---
                  _PlayerPreview(settings: settings),
                  
                  const SizedBox(height: 32),
                  
                  // --- Artwork Shape ---
                  AppleMusicSectionHeader(title: 'Artwork Shape'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ShapeOption(
                              label: 'Circle',
                              isSelected: settings.playerArtworkShape == 'circle',
                              icon: Icons.circle,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkShape('circle'),
                            ),
                            _ShapeOption(
                              label: 'Rounded',
                              isSelected: settings.playerArtworkShape == 'rounded',
                              icon: Icons.rounded_corner,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkShape('rounded'),
                            ),
                            _ShapeOption(
                              label: 'Square',
                              isSelected: settings.playerArtworkShape == 'square',
                              icon: Icons.square,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkShape('square'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.photo_size_select_large, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                             Text(
                              'Artwork Size',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7),),
                            ),
                            const Spacer(),
                            Text(
                              '${settings.playerArtworkSize.round()} px',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.playerArtworkSize,
                          min: 150,
                          max: 320,
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerArtworkSize(val),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // --- Glow Settings ---
                  AppleMusicSectionHeader(title: 'Visual Effects'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                         _CustomizationSwitchTile(
                           icon: Icons.auto_awesome,
                           title: 'Artwork Glow',
                           subtitle: 'Enhance artwork with a dynamic shadow',
                           value: settings.playerShowGlow,
                           onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerShowGlow(val),
                         ),
                         const Divider(height: 1, indent: 16),
                         _CustomizationSwitchTile(
                           icon: Icons.video_library_rounded,
                           title: 'Spotify Canvas',
                           subtitle: 'Show looping background video if available',
                           value: settings.playerSpotifyCanvasEnabled,
                           onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerSpotifyCanvasEnabled(val),
                         ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // --- Background Style ---
                  AppleMusicSectionHeader(title: 'Background Style'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _BackgroundOption(
                          title: 'Blurred Artwork',
                          subtitle: 'Dynamic colors from the current track',
                          isSelected: settings.playerBackgroundType == 'blurred',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerBackgroundType('blurred'),
                        ),
                        const Divider(height: 1, indent: 16),
                        _BackgroundOption(
                          title: 'AMOLED Black',
                          subtitle: 'Perfect for OLED screens',
                          isSelected: settings.playerBackgroundType == 'amoled',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerBackgroundType('amoled'),
                        ),
                        const Divider(height: 1, indent: 16),
                        _BackgroundOption(
                          title: 'Gradient Mesh',
                          subtitle: 'A subtle, colorful mesh texture',
                          isSelected: settings.playerBackgroundType == 'gradient',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerBackgroundType('gradient'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Like Icon ---
                  AppleMusicSectionHeader(title: 'Like Button Style'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _IconStyleOption(
                          icon: Icons.favorite,
                          label: 'Heart',
                          isSelected: settings.playerLikeIcon == 'heart',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerLikeIcon('heart'),
                        ),
                        _IconStyleOption(
                          icon: Icons.thumb_up,
                          label: 'Thumbs Up',
                          isSelected: settings.playerLikeIcon == 'thumb',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerLikeIcon('thumb'),
                        ),
                        _IconStyleOption(
                          icon: Icons.card_giftcard,
                          label: 'Gift',
                          isSelected: settings.playerLikeIcon == 'gift',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerLikeIcon('gift'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SeekBar Style ---
                  AppleMusicSectionHeader(title: 'SeekBar Style'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SeekBarStyleOption(
                          title: 'Default',
                          subtitle: 'Clean and minimal line',
                          isSelected: settings.playerSeekBarStyle == 'default',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('default'),
                          preview: Container(height: 2, width: 40, color: Theme.of(context).colorScheme.primary),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Rainbow',
                          subtitle: 'Vibrant color spectrum',
                          isSelected: settings.playerSeekBarStyle == 'rainbow',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('rainbow'),
                          preview: Container(
                            height: 4, 
                            width: 40, 
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.red, Colors.blue, Colors.green]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Wavy',
                          subtitle: 'Playful sine-wave motion',
                          isSelected: settings.playerSeekBarStyle == 'wavy',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('wavy'),
                          preview: Icon(Icons.waves, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Gradient',
                          subtitle: 'Two-tone theme gradient',
                          isSelected: settings.playerSeekBarStyle == 'gradient',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('gradient'),
                          preview: Container(
                            height: 3,
                            width: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Capsule',
                          subtitle: 'iOS system volume style',
                          isSelected: settings.playerSeekBarStyle == 'capsule',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('capsule'),
                          preview: Container(
                            height: 8,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Neon Glow',
                          subtitle: 'Futuristic glowing drop-shadow',
                          isSelected: settings.playerSeekBarStyle == 'neon',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('neon'),
                          preview: Icon(Icons.blur_on, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Dashed',
                          subtitle: 'Retro audio segmented progress',
                          isSelected: settings.playerSeekBarStyle == 'dashed',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('dashed'),
                          preview: Icon(Icons.linear_scale, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        const Divider(height: 1, indent: 16),
                        _SeekBarStyleOption(
                          title: 'Dotted',
                          subtitle: 'Elegant minimalist dotted track',
                          isSelected: settings.playerSeekBarStyle == 'dotted',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerSeekBarStyle('dotted'),
                          preview: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Artwork Animation ---
                  AppleMusicSectionHeader(title: 'Artwork Animation'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AnimationOption(
                          label: 'Zoom',
                          isSelected: settings.playerArtworkAnimation == 'zoom',
                          icon: Icons.zoom_in,
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkAnimation('zoom'),
                        ),
                        _AnimationOption(
                          label: 'Fade',
                          isSelected: settings.playerArtworkAnimation == 'fade',
                          icon: Icons.blur_on,
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkAnimation('fade'),
                        ),
                        _AnimationOption(
                          label: 'Slide',
                          isSelected: settings.playerArtworkAnimation == 'keyboard_double_arrow_right_rounded',
                          icon: Icons.keyboard_double_arrow_right_rounded,
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerArtworkAnimation('slide'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Lyrics Styling ---
                  AppleMusicSectionHeader(title: 'Lyrics Styling'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_size, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Text('Font Size', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                            const Spacer(),
                            Text('${settings.playerLyricsFontSize.round()}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: settings.playerLyricsFontSize,
                          min: 14,
                          max: 32,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerLyricsFontSize(val),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.text_fields, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Text('Font Style', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _FontStyleOption(
                              isSelected: settings.playerLyricsFontWeight == 'normal',
                              label: 'Normal',
                              weight: FontWeight.w400,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsFontWeight('normal'),
                            ),
                            _FontStyleOption(
                              isSelected: settings.playerLyricsFontWeight == 'bold',
                              label: 'Bold',
                              weight: FontWeight.bold,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsFontWeight('bold'),
                            ),
                            _FontStyleOption(
                              isSelected: settings.playerLyricsFontWeight == 'italic',
                              label: 'Italic',
                              weight: FontWeight.w400,
                              italic: true,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsFontWeight('italic'),
                            ),
                            _FontStyleOption(
                              isSelected: settings.playerLyricsFontWeight == 'boldItalic',
                              label: 'Bold Italic',
                              weight: FontWeight.bold,
                              italic: true,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsFontWeight('boldItalic'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _AlignmentOption(
                              isSelected: settings.playerLyricsAlignment == 'left',
                              icon: Icons.format_align_left_rounded,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsAlignment('left'),
                            ),
                            _AlignmentOption(
                              isSelected: settings.playerLyricsAlignment == 'center',
                              icon: Icons.format_align_center_rounded,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsAlignment('center'),
                            ),
                            _AlignmentOption(
                              isSelected: settings.playerLyricsAlignment == 'right',
                              icon: Icons.format_align_right_rounded,
                              onTap: () => ref.read(settingsProvider.notifier).setPlayerLyricsAlignment('right'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _CustomizationSwitchTile(
                          icon: Icons.lyrics,
                          title: 'Current Line Preview',
                          subtitle: 'Show current lyrics line above the song title',
                          value: settings.playerShowCurrentLyrics,
                          onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerShowCurrentLyrics(val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Next Up ---
                  AppleMusicSectionHeader(title: 'Next Up'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _CustomizationSwitchTile(
                          icon: Icons.queue_music_rounded,
                          title: 'Show Next Up',
                          subtitle: 'Preview upcoming tracks in the player',
                          value: settings.playerShowNextUp,
                          onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerShowNextUp(val),
                        ),
                        if (settings.playerShowNextUp) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.format_list_numbered_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Text('Count', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: settings.playerNextUpCount > 0
                                          ? () => ref.read(settingsProvider.notifier).setPlayerNextUpCount(settings.playerNextUpCount - 1)
                                          : null,
                                    ),
                                    Text(
                                      '${settings.playerNextUpCount}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: settings.playerNextUpCount < 10
                                          ? () => ref.read(settingsProvider.notifier).setPlayerNextUpCount(settings.playerNextUpCount + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.visibility_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Text('Style', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _NextUpStyleOption(
                                isSelected: settings.playerNextUpStyle == 'art_and_name',
                                label: 'Art + Name',
                                icon: Icons.album_rounded,
                                onTap: () => ref.read(settingsProvider.notifier).setPlayerNextUpStyle('art_and_name'),
                              ),
                              _NextUpStyleOption(
                                isSelected: settings.playerNextUpStyle == 'art_only',
                                label: 'Art Only',
                                icon: Icons.image_rounded,
                                onTap: () => ref.read(settingsProvider.notifier).setPlayerNextUpStyle('art_only'),
                              ),
                              _NextUpStyleOption(
                                isSelected: settings.playerNextUpStyle == 'name_only',
                                label: 'Name Only',
                                icon: Icons.text_fields_rounded,
                                onTap: () => ref.read(settingsProvider.notifier).setPlayerNextUpStyle('name_only'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Control Layout ---
                  AppleMusicSectionHeader(title: 'Interface Layout'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _LayoutOption(
                          title: 'Standard',
                          subtitle: 'Full controls and bottom bar',
                          isSelected: settings.playerControlLayout == 'standard',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerControlLayout('standard'),
                        ),
                        const Divider(height: 1, indent: 16),
                        _LayoutOption(
                          title: 'Minimalist',
                          subtitle: 'Clean, artwork-focused view',
                          isSelected: settings.playerControlLayout == 'minimalist',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerControlLayout('minimalist'),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // --- Minimalist Icons Toggles ---
                  if (settings.playerControlLayout == 'minimalist') ...[
                    AppleMusicSectionHeader(title: 'Minimalist Layout Icons'),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _CustomizationSwitchTile(
                            icon: Icons.alt_route_rounded,
                            title: 'Show Source Button',
                            subtitle: 'Toggle stream source selection button',
                            value: settings.playerMinimalistShowSource,
                            onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerMinimalistShowSource(val),
                          ),
                          const Divider(height: 1, indent: 16),
                          _CustomizationSwitchTile(
                            icon: CupertinoIcons.quote_bubble_fill,
                            title: 'Show Lyrics Button',
                            subtitle: 'Toggle fullscreen lyrics screen overlay button',
                            value: settings.playerMinimalistShowLyrics,
                            onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerMinimalistShowLyrics(val),
                          ),
                          const Divider(height: 1, indent: 16),
                          _CustomizationSwitchTile(
                            icon: Icons.bedtime_outlined,
                            title: 'Show Sleep Timer Button',
                            subtitle: 'Toggle sleep timer setup overlay button',
                            value: settings.playerMinimalistShowSleep,
                            onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerMinimalistShowSleep(val),
                          ),
                          const Divider(height: 1, indent: 16),
                          _CustomizationSwitchTile(
                            icon: Icons.list_rounded,
                            title: 'Show Up Next Queue Button',
                            subtitle: 'Toggle playlist queue view button',
                            value: settings.playerMinimalistShowQueue,
                            onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerMinimalistShowQueue(val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- Button Style ---
                  AppleMusicSectionHeader(title: 'Button Theme Style'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _LayoutOption(
                          title: 'Follow App Theme',
                          subtitle: 'Buttons style matches selected overall app theme',
                          isSelected: settings.playerButtonStyle == 'theme',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerButtonStyle('theme'),
                        ),
                        const Divider(height: 1, indent: 16),
                        _LayoutOption(
                          title: 'Apple Music Style',
                          subtitle: 'Simple raw icons play controls (double arrow next/prev)',
                          isSelected: settings.playerButtonStyle == 'apple',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerButtonStyle('apple'),
                        ),
                        const Divider(height: 1, indent: 16),
                        _LayoutOption(
                          title: 'Material 3 Style',
                          subtitle: 'Capsule play/pause and rounded square control backgrounds',
                          isSelected: settings.playerButtonStyle == 'm3',
                          onTap: () => ref.read(settingsProvider.notifier).setPlayerButtonStyle('m3'),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // --- Mini Player Settings ---
                  AppleMusicSectionHeader(title: 'Mini Player Gestures'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _CustomizationSwitchTile(
                          icon: Icons.swipe_left_rounded,
                          title: 'Swipe Gestures',
                          subtitle: 'Swipe left/right to change tracks',
                          value: settings.miniPlayerSwipeEnabled,
                          onChanged: (val) => ref.read(settingsProvider.notifier).setMiniPlayerSwipeEnabled(val),
                        ),
                        if (settings.miniPlayerSwipeEnabled) ...[
                          const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Swipe Sensitivity',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7),),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${settings.miniPlayerSwipeSensitivity.round()} px',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: settings.miniPlayerSwipeSensitivity,
                                  min: 15,
                                  max: 100,
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  inactiveColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                  onChanged: (val) => ref.read(settingsProvider.notifier).setMiniPlayerSwipeSensitivity(val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPreview extends StatelessWidget {
  final SettingsState settings;

  const _PlayerPreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        final displayArtwork = mediaItem?.artUri?.toString() ?? '';
        final displayTitle = mediaItem?.title ?? 'Not Playing';
        final displayArtist = mediaItem?.artist ?? 'Select a track to preview';
        final hasArtwork = displayArtwork.isNotEmpty;

        return Container(
          height: 480,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: settings.playerBackgroundType == 'amoled' 
                ? Colors.black 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.onSurface.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (settings.playerBackgroundType == 'gradient')
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            AppleMusicTheme.primaryPurple.withValues(alpha: 0.2),
                            Colors.blue.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                Positioned(
                  top: 40,
                  child: _buildArtworkPreview(hasArtwork, displayArtwork),
                ),
                
                Positioned(
                  bottom: 120,
                  child: Column(
                    children: [
                      Text(
                        displayTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        displayArtist,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7),),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 60,
                  left: 20,
                  right: 20,
                  child: _buildMockSeekBar(context),
                ),

                Positioned(
                  bottom: 10,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Icon(Icons.shuffle, color: theme.colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                      Icon(
                        (settings.playerButtonStyle == 'theme' ? settings.appThemeStyle == 'material3' : settings.playerButtonStyle == 'm3')
                            ? Icons.skip_previous_rounded
                            : Icons.fast_rewind_rounded,
                        color: theme.colorScheme.onSurface,
                        size: 32,
                      ),
                      Icon(
                        (settings.playerButtonStyle == 'theme' ? settings.appThemeStyle == 'material3' : settings.playerButtonStyle == 'm3')
                            ? Icons.play_circle_fill_rounded
                            : Icons.play_arrow_rounded,
                        color: theme.colorScheme.onSurface,
                        size: 48,
                      ),
                      Icon(
                        (settings.playerButtonStyle == 'theme' ? settings.appThemeStyle == 'material3' : settings.playerButtonStyle == 'm3')
                            ? Icons.skip_next_rounded
                            : Icons.fast_forward_rounded,
                        color: theme.colorScheme.onSurface,
                        size: 32,
                      ),
                      Icon(
                        settings.playerLikeIcon == 'heart' ? Icons.favorite : 
                        (settings.playerLikeIcon == 'thumb' ? Icons.thumb_up : Icons.card_giftcard),
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildArtworkPreview(bool hasArtwork, String artworkUrl) {
    final artworkSize = settings.playerArtworkSize * 0.85; // Less scaling, more fidelity
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: artworkSize,
        maxHeight: artworkSize,
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dynamic Visual Glow (Halo)
            if (settings.playerShowGlow && hasArtwork)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.15,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Opacity(
                      opacity: 0.7,
                      child: Image.network(
                        artworkUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: settings.playerArtworkShape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: settings.playerArtworkShape == 'circle' 
                      ? null 
                      : BorderRadius.circular(settings.playerArtworkShape == 'rounded' ? 24 : 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: settings.playerArtworkShape == 'circle' 
                      ? BorderRadius.circular(artworkSize / 2) 
                      : BorderRadius.circular(settings.playerArtworkShape == 'rounded' ? 24 : 4),
                  child: hasArtwork
                      ? Image.network(
                          artworkUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _previewPlaceholder(artworkSize),
                        )
                      : _previewPlaceholder(artworkSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockSeekBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: settings.playerSeekBarStyle == 'capsule'
                ? SliderComponentShape.noThumb
                : const RoundSliderThumbShape(enabledThumbRadius: 4),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            trackShape: settings.playerSeekBarStyle == 'rainbow' 
                ? RainbowSliderTrackShape() 
                : (settings.playerSeekBarStyle == 'wavy' 
                    ? WavySliderTrackShape() 
                    : (settings.playerSeekBarStyle == 'gradient'
                        ? GradientSliderTrackShape()
                        : (settings.playerSeekBarStyle == 'capsule'
                            ? CapsuleSliderTrackShape()
                            : (settings.playerSeekBarStyle == 'neon'
                                ? NeonSliderTrackShape()
                                : (settings.playerSeekBarStyle == 'dashed'
                                    ? DashedSliderTrackShape()
                                    : (settings.playerSeekBarStyle == 'dotted'
                                        ? DottedSliderTrackShape()
                                        : const RoundedRectSliderTrackShape())))))),
          ),
          child: Slider(value: 0.4, onChanged: (_) {}),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1:50', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
            Text('4:20', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
          ],
        ),
      ],
    );
  }

  Widget _previewPlaceholder(double size) {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: Icon(
        Icons.music_note,
        size: size * 0.4,
        color: Colors.white54,
      ),
    );
  }
}

class _ShapeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _ShapeOption({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 32,
              color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _BackgroundOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6),),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
    );
  }
}

class _IconStyleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconStyleOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
            ),
            child: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _SeekBarStyleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget preview;

  const _SeekBarStyleOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: preview),
      ),
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
    );
  }
}

class _CustomizationSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomizationSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5),),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _AnimationOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _AnimationOption({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
            ),
            child: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _AlignmentOption extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _AlignmentOption({
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
        ),
        child: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _FontStyleOption extends StatelessWidget {
  final bool isSelected;
  final String label;
  final FontWeight weight;
  final bool italic;
  final VoidCallback onTap;

  const _FontStyleOption({
    required this.isSelected,
    required this.label,
    required this.weight,
    this.italic = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: weight,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
    );
  }
}

class _NextUpStyleOption extends StatelessWidget {
  final bool isSelected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NextUpStyleOption({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
            ),
            child: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
