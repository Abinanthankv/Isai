import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/utils/app_haptics.dart';
import '../../music/presentation/music_providers.dart';

class HapticsSettingsScreen extends ConsumerWidget {
  const HapticsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AppleMusicGradientText(
                text: 'Haptic Feedback',
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
                  const AppleMusicSectionHeader(title: 'Global Haptics'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(
                            'Enable Haptic Feedback',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            'Vibrate on button taps, swipes, and list drag reordering',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          value: settings.hapticsEnabled,
                          activeTrackColor: Theme.of(context).colorScheme.primary,
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            ref.read(settingsProvider.notifier).setHapticsEnabled(val);
                            if (val) {
                              AppHaptics.trigger(ref, type: HapticFeedbackType.medium);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  if (settings.hapticsEnabled) ...[
                    const SizedBox(height: 24),
                    const AppleMusicSectionHeader(title: 'Feedback Intensity'),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Tactile Vibrancy',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildIntensityChip(
                                context,
                                ref,
                                label: 'Light',
                                value: 'light',
                                current: settings.hapticIntensity,
                                feedbackType: HapticFeedbackType.light,
                              ),
                              const SizedBox(width: 8),
                              _buildIntensityChip(
                                context,
                                ref,
                                label: 'Medium',
                                value: 'medium',
                                current: settings.hapticIntensity,
                                feedbackType: HapticFeedbackType.medium,
                              ),
                              const SizedBox(width: 8),
                              _buildIntensityChip(
                                context,
                                ref,
                                label: 'Heavy',
                                value: 'heavy',
                                current: settings.hapticIntensity,
                                feedbackType: HapticFeedbackType.heavy,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String value,
    required String current,
    required HapticFeedbackType feedbackType,
  }) {
    final selected = current == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(settingsProvider.notifier).setHapticIntensity(value);
          AppHaptics.trigger(ref, type: feedbackType);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? Colors.white24 : Colors.black12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black.withOpacity(0.8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
