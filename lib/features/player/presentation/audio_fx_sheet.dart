import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/apple_music_components.dart';
import '../data/audio_fx_service.dart';

/// A full-screen audio effects panel that controls Android's `android.media.audiofx`
/// effects (Equalizer, BassBoost, LoudnessEnhancer, DynamicsProcessing, PresetReverb).
///
/// See [AudioFxService] for the Dart<->native bridge and persisted state.
class AudioFxSheet extends StatefulWidget {
  const AudioFxSheet({super.key});

  @override
  State<AudioFxSheet> createState() => _AudioFxSheetState();
}

class _AudioFxSheetState extends State<AudioFxSheet> {
  final AudioFxService _service = AudioFxService();
  Future<AudioFxDeviceParameters>? _paramsFuture;
  List<int>? _bandCountFor; // band count used when building sliders
  List<CustomEqPreset> _customPresets = [];

  @override
  void initState() {
    super.initState();
    _paramsFuture = _service.ensureParameters();
    _loadCustomPresets();
  }

  Future<void> _loadCustomPresets() async {
    final presets = await _service.loadCustomPresets();
    if (mounted) setState(() => _customPresets = presets);
  }

  @override
  void dispose() {
    _bandCountFor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<AudioFxState>(
        stream: _service.stream,
        initialData: _service.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _service.state;
          if (_bandCountFor == null || _bandCountFor!.isEmpty) {
            _bandCountFor = [state.eqGains.length];
          }
          final eqBands = _bandCountFor!.first;
          return CustomScrollView(
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: AppleMusicGradientText(
                    text: 'Sound Effects',
                    fontSize: 20,
                    colors: [theme.colorScheme.primary, AppleMusicTheme.primaryPurple],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel('MASTER'),
                      _Card(
                        child: _Row(
                          title: 'Audio Effects',
                          subtitle: 'Apply EQ, bass, loudness, reverb & dynamics',
                          trailing: Switch.adaptive(
                            value: state.enabled,
                            activeTrackColor: theme.colorScheme.primary,
                            onChanged: _service.setEnabled,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (state.enabled && !_hasSession) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Start playing a song to adjust effects.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildEqualizer(state, eqBands),
                      _buildBass(state),
                      _buildLoudness(state),
                      _buildReverb(state),
                      _buildDynamics(state),

                      if (_unsupportedMessage(state) != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _unsupportedMessage(state)!,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.orangeAccent),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEqualizer(AudioFxState state, int bandCount) {
    return FutureBuilder<AudioFxDeviceParameters>(
      future: _paramsFuture,
      builder: (context, snap) {
        final params = snap.data ?? AudioFxDeviceParameters(
          supported: {},
          bandCount: bandCount,
          minDecibels: -12,
          maxDecibels: 12,
          centerFrequencies: <double>[],
          bandGains: <double>[],
        );
        final gains = state.enabled && state.eqGains.length == params.bandCount
            ? state.eqGains
            : List.filled(params.bandCount, 0.0, growable: false);
        if (params.bandCount <= 0) {
          return _EmptySection(label: 'EQUALIZER', message: 'No equalizer available on this device.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel('EQUALIZER'),
            _Card(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < AudioFxService.eqPresets.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(AudioFxService.eqPresets[i].$1),
                              selected: state.enabled && state.eqPresetIndex == i,
                              onSelected: (_) => _service.applyPreset(i),
                              showCheckmark: false,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: const Text('Custom'),
                            selected: state.enabled && _isCustomActive(state),
                            onSelected: (_) => _service.markCustom(),
                            showCheckmark: false,
                            avatar: const Icon(Icons.tune, size: 16),
                          ),
                        ),
                        for (final preset in _customPresets)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onLongPress: () => _confirmDeletePreset(preset.name),
                              child: ChoiceChip(
                                label: Text(preset.name),
                                selected: state.enabled &&
                                    state.eqPresetIndex == -1 &&
                                    _isPresetActive(state, preset),
                                onSelected: (_) => _service.applyCustomPreset(preset.name),
                                showCheckmark: false,
                                avatar: const Icon(Icons.bookmark_outlined, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        params.eq10
                            ? '10-band Precision EQ · 31 Hz – 16 kHz'
                            : 'Device EQ (${params.bandCount}-band)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      TextButton.icon(
                        onPressed: state.enabled ? _saveCurrentAsPreset : null,
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save as Preset'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Vertical sliders per band.
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        for (var band = 0; band < params.bandCount; band++)
                          Expanded(
                            child: _BandSlider(
                              gainDb: band < gains.length ? gains[band] : 0.0,
                              min: params.minDecibels,
                              max: params.maxDecibels,
                              frequencyHz: band < params.centerFrequencies.length
                                  ? params.centerFrequencies[band]
                                  : null,
                              enabled: state.enabled,
                              onChanged: (v) => _service.setBandGain(band, v),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildBass(AudioFxState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('BASS'),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderLabel(title: 'Bass Boost', value: '${(state.bassStrength * 100).round()}%'),
              Slider(
                value: state.bassStrength,
                onChanged: state.enabled ? _service.setBassStrength : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLoudness(AudioFxState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('VOLUME'),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderLabel(
                title: 'Volume Boost',
                value: state.loudnessGain == 0 ? 'Off' : '+${state.loudnessGain.round()} dB',
              ),
              Slider(
                value: state.loudnessGain.clamp(0, 20),
                min: 0,
                max: 20,
                divisions: 40,
                onChanged: state.enabled ? (v) => _service.setLoudnessGain(v) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReverb(AudioFxState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('REVERB'),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, index) in AudioFxService.reverbPresets)
                ChoiceChip(
                  label: Text(name),
                  selected: state.enabled && state.reverbPreset == index,
                  onSelected: (_) => _service.setReverbPreset(index),
                  showCheckmark: false,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDynamics(AudioFxState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('DYNAMICS'),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(
                title: 'Limiter',
                subtitle: 'Prevent clipping on loud tracks',
                trailing: Switch.adaptive(
                  value: state.dynamicsEnabled,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  onChanged: state.enabled ? _service.setDynamicsEnabled : null,
                ),
              ),
              _SliderLabel(
                title: 'Limiter Threshold',
                value: '${state.dynamicsThreshold.round()} dB',
              ),
              Slider(
                value: state.dynamicsThreshold.clamp(-30, -1),
                min: -30,
                max: -1,
                divisions: 29,
                onChanged: (state.enabled && state.dynamicsEnabled) ? _service.setDynamicsThreshold : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  bool get _hasSession => _service.hasSession;

  bool _isPresetActive(AudioFxState state, CustomEqPreset preset) {
    final resampled = AudioFxService.resampleGains(preset.gains, state.eqGains.length);
    return AudioFxService.gainsClose(resampled, state.eqGains);
  }

  bool _isAnyPresetActive(AudioFxState state) {
    return _customPresets.any((p) => _isPresetActive(state, p));
  }

  bool _isCustomActive(AudioFxState state) {
    return state.eqPresetIndex == -1 && !_isAnyPresetActive(state);
  }

  Future<void> _saveCurrentAsPreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Preset name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _service.saveCustomPreset(name);
    await _loadCustomPresets();
  }

  Future<void> _confirmDeletePreset(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteCustomPreset(name);
      await _loadCustomPresets();
    }
  }

  String? _unsupportedMessage(AudioFxState state) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 'Sound effects are not yet supported on this platform.';
    }
    final supported = _service.deviceParameters?.supported;
    if (supported == null || supported.isEmpty) return null;
    final missing = <String>[];
    if (supported['bassBoost'] != true) missing.add('Bass');
    if (supported['loudness'] != true) missing.add('Volume');
    if (supported['reverb'] != true) missing.add('Reverb');
    if (supported['dynamics'] != true) missing.add('Dynamics');
    if (missing.isEmpty) return null;
    return 'Not available on this device: ${missing.join(', ')}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(8)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle case final sub?)
                  Text(sub, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.gainDb,
    required this.min,
    required this.max,
    required this.frequencyHz,
    required this.enabled,
    required this.onChanged,
  });
  final double gainDb;
  final double min;
  final double max;
  final double? frequencyHz;
  final bool enabled;
  final ValueChanged<double> onChanged;

  String _freqLabel() {
    if (frequencyHz == null) return '';
    final hz = frequencyHz!;
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
    return '${hz.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: gainDb.clamp(min, max),
              min: min,
              max: max,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _freqLabel(),
          style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.label, required this.message});
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        _Card(
          padding: const EdgeInsets.all(16),
          child: Text(message, style: TextStyle(color: Colors.grey[400])),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}