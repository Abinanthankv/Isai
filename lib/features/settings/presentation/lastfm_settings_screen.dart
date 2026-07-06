import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/di/injection.dart';
import '../../settings/data/lastfm_repository.dart';
import '../../music/presentation/lastfm_provider.dart';

class LastfmSettingsScreen extends ConsumerStatefulWidget {
  const LastfmSettingsScreen({super.key});

  @override
  ConsumerState<LastfmSettingsScreen> createState() => _LastfmSettingsScreenState();
}

class _LastfmSettingsScreenState extends ConsumerState<LastfmSettingsScreen> {
  late final LastfmRepository _repo;
  bool _scrobbleEnabled = true;
  double _scrobblePercentage = 50;
  double _minScrobbleMinutes = 0;

  @override
  void initState() {
    super.initState();
    _repo = getIt<LastfmRepository>();
    _scrobbleEnabled = _repo.scrobbleEnabled;
    _scrobblePercentage = _repo.scrobblePercentage.toDouble();
    _minScrobbleMinutes = _repo.minScrobbleMinutes.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastfm = ref.watch(lastfmProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Last.fm Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // ─── Account Section ──────────────────────────────────────
          _buildSectionHeader(context, 'Account'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lastfm.username ?? 'Connected',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scrobbling via Last.fm',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Connected',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600, color: Colors.green,),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disconnect Last.fm?'),
                          content: const Text('Your existing scrobbles will remain on Last.fm.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        ref.read(lastfmProvider.notifier).disconnect();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Disconnect Last.fm',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Scrobble Settings Section ────────────────────────────
          _buildSectionHeader(context, 'Scrobbling'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              children: [
                // Scrobble toggle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.cloud_upload_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Enable scrobbling',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,),
                      ),
                    ),
                    Switch(
                      value: _scrobbleEnabled,
                      onChanged: (val) {
                        setState(() => _scrobbleEnabled = val);
                        _repo.setScrobbleEnabled(val);
                      },
                    ),
                  ],
                ),
                if (!_scrobbleEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 44),
                    child: Text(
                      'Scrobbling is paused. No plays will be sent to Last.fm.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black45,),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrobble threshold
          _ScrobbleSliderCard(
            title: 'Scrobble threshold',
            subtitle: 'Percentage of a track that must play before scrobbling',
            icon: Icons.tune_rounded,
            value: _scrobblePercentage,
            min: 25,
            max: 100,
            divisions: 15,
            displaySuffix: '%',
            onChanged: (val) {
              setState(() => _scrobblePercentage = val);
            },
            onChangeEnd: (val) => _repo.setScrobblePercentage(val.round()),
          ),
          const SizedBox(height: 16),

          // Min track duration
          _ScrobbleSliderCard(
            title: 'Minimum track length',
            subtitle: 'Tracks shorter than this won\'t be scrobbled',
            icon: Icons.timer_outlined,
            value: _minScrobbleMinutes,
            min: 0,
            max: 10,
            divisions: 10,
            displaySuffix: _minScrobbleMinutes == 0 ? ' (no min)' : ' min',
            onChanged: (val) {
              setState(() => _minScrobbleMinutes = val);
            },
            onChangeEnd: (val) => _repo.setMinScrobbleMinutes(val.round()),
          ),
          const SizedBox(height: 28),

          // ─── Info Section ─────────────────────────────────────────
          _buildSectionHeader(context, 'How scrobbling works'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(context, isDark, Icons.info_outline, 
                  'A scrobble is sent when you\'ve listened to at least the configured percentage of a track.'),
                const SizedBox(height: 12),
                _infoRow(context, isDark, Icons.shield_outlined,
                  'Tracks shorter than the minimum length are skipped automatically.'),
                const SizedBox(height: 12),
                _infoRow(context, isDark, Icons.sync_rounded,
                  'Now Playing updates as soon as a new track starts.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _infoRow(BuildContext context, bool isDark, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrobbleSliderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displaySuffix;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _ScrobbleSliderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displaySuffix,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black45,),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${value.round()}$displaySuffix',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
                    color: primary,),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primary,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: primary,
              overlayColor: primary.withOpacity(0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
