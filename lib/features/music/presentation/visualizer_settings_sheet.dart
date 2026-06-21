import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'music_providers.dart';
import 'visualizer_layer.dart';

/// A full-screen settings page for the audio visualizer, matching the
/// premium design language of the existing PlayerCustomizationScreen.
///
/// Provides controls for:
///  - Master enable/disable toggle
///  - Per-location toggles (Now Playing / Mini Player)
///  - Style selection (Wave, Bar, Line)
///  - Points and Sensitivity sliders
///  - Color mode selection (Dynamic, Album Art, Vibrant, Custom)
///  - Alpha, Height, Amplitude, Base Lift sliders
///  - Bar-specific settings (spacing, corner radius)
class VisualizerSettingsSheet extends ConsumerWidget {
  const VisualizerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AppleMusicGradientText(
                text: 'Visualizer',
                fontSize: 20,
                colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── VISUALIZER TOGGLES ──────────────────────────────
                  const _SectionLabel('VISUALIZER'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ToggleTile(
                          title: 'Enabled',
                          value: settings.visualizerEnabled,
                          onChanged: (v) async {
                            if (v) {
                              // Ask for RECORD_AUDIO permission before enabling
                              final granted = await requestVisualizerPermission(context);
                              if (granted) {
                                ref.read(settingsProvider.notifier).setVisualizerEnabled(true);
                              } else {
                                // Still allow enabling with procedural fallback
                                ref.read(settingsProvider.notifier).setVisualizerEnabled(true);
                              }
                            } else {
                              ref.read(settingsProvider.notifier).setVisualizerEnabled(false);
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 16, color: Colors.white12),
                        _ToggleTile(
                          title: 'Now Playing Screen',
                          value: settings.visualizerShowNowPlaying,
                          onChanged: settings.visualizerEnabled
                              ? (v) => ref.read(settingsProvider.notifier).setVisualizerShowNowPlaying(v)
                              : null,
                        ),
                        const Divider(height: 1, indent: 16, color: Colors.white12),
                        _ToggleTile(
                          title: 'Mini Player',
                          value: settings.visualizerShowMiniPlayer,
                          onChanged: settings.visualizerEnabled
                              ? (v) => ref.read(settingsProvider.notifier).setVisualizerShowMiniPlayer(v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 6, bottom: 16),
                    child: Text(
                      'Master toggle disables all visualizers. Individual toggles control each location.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
                    ),
                  ),

                  // ── STYLE ──────────────────────────────────────────
                  const _SectionLabel('STYLE'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segmented control for style
                        _SegmentedSelector(
                          options: const ['Wave', 'Bar', 'Line', 'Mirrored'],
                          selectedIndex: ['wave', 'bar', 'line', 'mirrored'].indexOf(settings.visualizerStyle).clamp(0, 3),
                          onSelect: (i) => ref.read(settingsProvider.notifier).setVisualizerStyle(['wave', 'bar', 'line', 'mirrored'][i]),
                        ),

                        const SizedBox(height: 20),

                        // Number of points
                        _SliderRow(
                          label: 'Number of points',
                          value: settings.visualizerPoints.toDouble(),
                          min: 4,
                          max: 64,
                          displayValue: settings.visualizerPoints.toString(),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerPoints(v.round()),
                        ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Points control how many data points the ${settings.visualizerStyle} is built from. '
                            'Fewer points = bigger, rounder ocean swells. More points = detailed, ripply surface. '
                            '8–12 is a good starting point.',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── BAR-SPECIFIC SETTINGS ──────────────────────────
                  if (settings.visualizerStyle == 'bar') ...[
                    const _SectionLabel('BAR'),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SliderRow(
                            label: 'Bar spacing',
                            value: settings.visualizerBarSpacing,
                            min: 0,
                            max: 12,
                            displayValue: settings.visualizerBarSpacing.toStringAsFixed(0),
                            onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerBarSpacing(v),
                          ),

                          const SizedBox(height: 16),

                          _SliderRow(
                            label: 'Corner radius',
                            value: settings.visualizerCornerRadius,
                            min: 0,
                            max: 15,
                            displayValue: settings.visualizerCornerRadius.toStringAsFixed(0),
                            onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerCornerRadius(v),
                          ),

                          const SizedBox(height: 8),

                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Spacing controls the gap between bars. Corner radius '
                              'shapes bar tops — at 0 they\'re sharp rectangles, at 15 '
                              'they\'re rounded pills.',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── COLOR ──────────────────────────────────────────
                  const _SectionLabel('COLOR'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SegmentedSelector(
                          options: const ['Dynamic', 'Album Art', 'Vibrant', 'Custom'],
                          selectedIndex: ['dynamic', 'albumArt', 'vibrant', 'custom']
                              .indexOf(settings.visualizerColorMode)
                              .clamp(0, 3),
                          onSelect: (i) => ref.read(settingsProvider.notifier).setVisualizerColorMode(
                            ['dynamic', 'albumArt', 'vibrant', 'custom'][i],
                          ),
                        ),

                        const SizedBox(height: 20),

                        _SliderRow(
                          label: 'Alpha',
                          value: settings.visualizerAlpha,
                          min: 0.05,
                          max: 1.0,
                          displayValue: settings.visualizerAlpha.toStringAsFixed(2),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerAlpha(v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── LAYOUT & AMPLITUDE ─────────────────────────────
                  const _SectionLabel('LAYOUT & AMPLITUDE'),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SliderRow(
                          label: 'Screen height %',
                          value: settings.visualizerHeightPct,
                          min: 0.1,
                          max: 1.0,
                          displayValue: '${(settings.visualizerHeightPct * 100).round()}%',
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerHeightPct(v),
                        ),

                        const SizedBox(height: 16),

                        _SliderRow(
                          label: 'Amplitude',
                          value: settings.visualizerAmplitude,
                          min: 0.01,
                          max: 1.0,
                          displayValue: settings.visualizerAmplitude.toStringAsFixed(2),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerAmplitude(v),
                        ),

                        const SizedBox(height: 16),

                        _SliderRow(
                          label: 'Base lift (from bottom)',
                          value: settings.visualizerBaseLift,
                          min: 0,
                          max: 300,
                          displayValue: '${settings.visualizerBaseLift.round()} pt',
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerBaseLift(v),
                        ),

                        const SizedBox(height: 16),

                        _SliderRow(
                          label: 'Sensitivity',
                          value: settings.visualizerSensitivity,
                          min: 0.01,
                          max: 1.0,
                          displayValue: settings.visualizerSensitivity.toStringAsFixed(1),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setVisualizerSensitivity(v),
                        ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Each style remembers its own point count and sensitivity '
                            'independently. Switching styles never overwrites another '
                            'style\'s values.',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
                          ),
                        ),
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

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.2,),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool)? onChanged;

  const _ToggleTile({
    required this.title,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: onChanged != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged != null 
                ? (v) {
                    HapticFeedback.lightImpact();
                    onChanged!(v);
                  } 
                : null,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SegmentedSelector extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _SegmentedSelector({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(options.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.onSurface.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  options[i],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5),),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            thumbColor: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
            overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (v) {
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ],
    );
  }
}
