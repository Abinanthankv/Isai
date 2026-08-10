import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of the current audio effects configuration.
@immutable
class AudioFxState {
  const AudioFxState({
    this.enabled = false,
    this.eqPresetIndex = 0,
    this.eqGains = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.bassStrength = 0,
    this.loudnessGain = 0,
    this.reverbPreset = 0,
    this.dynamicsEnabled = false,
    this.dynamicsThreshold = -10,
  });

  final bool enabled;

  /// Index into [AudioFxService.eqPresets]. -1 means the gains are custom.
  final int eqPresetIndex;

  /// Per-band gain in dB (native Equalizer band order).
  final List<double> eqGains;

  /// Bass boost strength, 0..1 (native 0..1000).
  final double bassStrength;

  /// LoudnessEnhancer target gain in dB.
  final double loudnessGain;

  /// PresetReverb preset index (0 = none, see REVERB_* constants).
  final int reverbPreset;

  /// Whether the DynamicsProcessing limiter is engaged.
  final bool dynamicsEnabled;

  /// Dynamics limiter threshold in dB (negative, e.g. -10).
  final double dynamicsThreshold;

  AudioFxState copyWith({
    bool? enabled,
    int? eqPresetIndex,
    List<double>? eqGains,
    double? bassStrength,
    double? loudnessGain,
    int? reverbPreset,
    bool? dynamicsEnabled,
    double? dynamicsThreshold,
  }) {
    return AudioFxState(
      enabled: enabled ?? this.enabled,
      eqPresetIndex: eqPresetIndex ?? this.eqPresetIndex,
      eqGains: eqGains ?? this.eqGains,
      bassStrength: bassStrength ?? this.bassStrength,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      reverbPreset: reverbPreset ?? this.reverbPreset,
      dynamicsEnabled: dynamicsEnabled ?? this.dynamicsEnabled,
      dynamicsThreshold: dynamicsThreshold ?? this.dynamicsThreshold,
    );
  }
}

/// Device capabilities + equalizer band layout reported by the native plugin.
class AudioFxDeviceParameters {
  const AudioFxDeviceParameters({
    required this.supported,
    required this.bandCount,
    required this.minDecibels,
    required this.maxDecibels,
    required this.centerFrequencies,
    required this.bandGains,
    this.eq10 = false,
  });

  final Map<String, bool> supported;
  final int bandCount;
  final double minDecibels;
  final double maxDecibels;
  final List<double> centerFrequencies;
  final List<double> bandGains;

  /// True when the 10-band DynamicsProcessing Precision EQ is active.
  final bool eq10;

  factory AudioFxDeviceParameters.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AudioFxDeviceParameters(
        supported: {},
        bandCount: 0,
        minDecibels: -15,
        maxDecibels: 15,
        centerFrequencies: [],
        bandGains: [],
      );
    }
    final supported = <String, bool>{};
    final rawSupported = map['supported'];
    if (rawSupported is Map) {
      rawSupported.forEach((k, v) => supported[k.toString()] = v == true);
    }
    final eq = map['equalizer'];
    final bandCount = eq is Map ? (eq['bandCount'] as num?)?.toInt() ?? 0 : 0;
    final minDb = eq is Map ? (eq['minDecibels'] as num?)?.toDouble() ?? -15.0 : -15.0;
    final maxDb = eq is Map ? (eq['maxDecibels'] as num?)?.toDouble() ?? 15.0 : 15.0;
    final freqs = <double>[];
    final gains = <double>[];
    if (eq is Map && eq['bands'] is List) {
      for (final b in eq['bands'] as List) {
        if (b is Map) {
          freqs.add((b['centerFrequency'] as num?)?.toDouble() ?? 0);
          gains.add((b['gainDb'] as num?)?.toDouble() ?? 0);
        }
      }
    }
    return AudioFxDeviceParameters(
      supported: supported,
      bandCount: bandCount,
      minDecibels: minDb,
      maxDecibels: maxDb,
      centerFrequencies: freqs,
      bandGains: gains,
      eq10: supported['eq10'] == true,
    );
  }
}

/// A user-created equalizer preset saved locally. Gains are stored against the
/// standard 10-band layout (see [AudioFxService.eqFrequencies]) so they can be
/// resampled onto any device's band count when applied.
@immutable
class CustomEqPreset {
  const CustomEqPreset({
    required this.name,
    required this.gains,
    this.bassStrength = 0,
    this.loudnessGain = 0,
    this.reverbPreset = 0,
    this.dynamicsEnabled = false,
    this.dynamicsThreshold = -10,
  });

  final String name;

  /// 10-point gain profile in dB aligned to [AudioFxService.eqFrequencies].
  final List<double> gains;
  final double bassStrength;
  final double loudnessGain;
  final int reverbPreset;
  final bool dynamicsEnabled;
  final double dynamicsThreshold;

  Map<String, dynamic> toJson() => {
        'name': name,
        'gains': gains,
        'bass': bassStrength,
        'loudness': loudnessGain,
        'reverb': reverbPreset,
        'dynamics': dynamicsEnabled,
        'dynamics_threshold': dynamicsThreshold,
      };

  factory CustomEqPreset.fromJson(Map<String, dynamic> json) => CustomEqPreset(
        name: json['name'] as String? ?? 'Preset',
        gains: (json['gains'] as List<dynamic>? ?? [])
            .map((e) => (e as num?)?.toDouble() ?? 0)
            .toList(),
        bassStrength: (json['bass'] as num?)?.toDouble() ?? 0,
        loudnessGain: (json['loudness'] as num?)?.toDouble() ?? 0,
        reverbPreset: (json['reverb'] as num?)?.toInt() ?? 0,
        dynamicsEnabled: json['dynamics'] == true,
        dynamicsThreshold: (json['dynamics_threshold'] as num?)?.toDouble() ?? -10,
      );
}

/// Dart-side bridge to the native Android audiofx plugin.
///
/// Owns the persisted effect settings (SharedPreferences), streams state to the
/// UI, and pushes changes to the native effects attached to just_audio's audio
/// session. `applySession` is called automatically by [MyAudioHandler] whenever
/// the session id changes so persisted settings survive track changes.
class AudioFxService {
  static const _channel = MethodChannel('com.isai.music/audiofx');

  /// ISO 1/1-octave graphic EQ centers (Hz): the audiophile-standard 10-band layout.
  static const List<double> eqFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// App-level equalizer presets as 10-point gain profiles (dB) aligned to
  /// [eqFrequencies]. Profiles are resampled onto the device's band count.
  static const List<(String, List<double>)> eqPresets = [
    ('Flat', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    ('Rock', [5, 4, 3, 1, -1, 0, 2, 4, 4, 3]),
    ('Pop', [-1, 1, 2, 4, 3, 0, -1, -1, 2, 3]),
    ('Jazz', [3, 2, 1, 2, -1, -1, 0, 2, 3, 4]),
    ('Classical', [4, 3, 2, 1, -1, -1, 0, 1, 2, 3]),
    ('Dance', [6, 5, 3, 1, 0, 1, 2, 4, 5, 6]),
    ('Bass Boost', [8, 7, 5, 3, 1, 0, 0, 0, 0, 0]),
    ('Treble Boost', [0, 0, 0, 0, 0, 0, 1, 3, 5, 7]),
    ('Vocal', [-1, -1, 0, 1, 3, 4, 3, 1, 0, -1]),
  ];

  static const List<(String, int)> reverbPresets = [
    ('None', 0),
    ('Small Room', 1),
    ('Medium Room', 2),
    ('Large Room', 3),
    ('Plate', 4),
    ('Medium Hall', 5),
    ('Large Hall', 6),
  ];

  static final AudioFxService _instance = AudioFxService._internal();
  factory AudioFxService() => _instance;
  AudioFxService._internal();

  AudioFxState _current = const AudioFxState();
  int _sessionId = -1;
  AudioFxDeviceParameters? _deviceParams;
  bool _prefsLoaded = false;
  final _stateController = StreamController<AudioFxState>.broadcast();

  Stream<AudioFxState> get stream => _stateController.stream;
  AudioFxState get state => _current;
  AudioFxDeviceParameters? get deviceParameters => _deviceParams;
  bool get hasSession => _sessionId > 0;

  /// Attach effects to a (new) audio session and re-apply persisted settings.
  Future<void> applySession(int sessionId) async {
    if (sessionId <= 0) return;
    _sessionId = sessionId;
    await _ensurePrefsLoaded();
    try {
      await _channel.invokeMethod('applySession', {'sessionId': sessionId});
    } on PlatformException catch (e) {
      debugPrint('[AudioFxService] applySession failed: $e');
      return;
    }
    await _pushAll();
    await _refreshDeviceParameters();
  }

  /// Fetch device capabilities once and cache them.
  Future<AudioFxDeviceParameters> ensureParameters() async {
    await _ensurePrefsLoaded();
    if (_deviceParams != null) return _deviceParams!;
    await _refreshDeviceParameters();
    return _deviceParams ?? const AudioFxDeviceParameters(
      supported: {},
      bandCount: 0,
      minDecibels: -15,
      maxDecibels: 15,
      centerFrequencies: [],
      bandGains: [],
    );
  }

  Future<void> _refreshDeviceParameters() async {
    if (_sessionId <= 0) return;
    try {
      final raw = await _channel.invokeMethod('getParameters');
      if (raw is Map) {
        _deviceParams = AudioFxDeviceParameters.fromMap(raw);
        // Align the stored gains with the device band count.
        if (_deviceParams!.bandCount > 0 && _current.eqGains.length != _deviceParams!.bandCount) {
          _current = _current.copyWith(eqGains: resampleGains(_current.eqGains, _deviceParams!.bandCount));
        }
        await _pushAll();
      }
    } on PlatformException catch (e) {
      debugPrint('[AudioFxService] getParameters failed: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(enabled: enabled);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> applyPreset(int index) async {
    await _ensurePrefsLoaded();
    final bands = await _bandCount();
    final gains = index >= 0 && index < eqPresets.length
        ? resampleGains(eqPresets[index].$2, bands)
        : _current.eqGains;
    _current = _current.copyWith(eqPresetIndex: index, eqGains: gains);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> setBandGain(int band, double gainDb) async {
    await _ensurePrefsLoaded();
    final gains = List<double>.from(_current.eqGains);
    if (band < 0 || band >= gains.length) return;
    gains[band] = gainDb;
    _current = _current.copyWith(eqPresetIndex: -1, eqGains: gains);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  /// Tag the current EQ state as custom without changing the gains. Used when
  /// the user taps the "Custom" pill.
  Future<void> markCustom() async {
    await _ensurePrefsLoaded();
    if (_current.eqPresetIndex != -1) {
      _current = _current.copyWith(eqPresetIndex: -1);
      await _persist();
      _stateController.add(_current);
    }
  }

  Future<void> setBassStrength(double strength) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(eqPresetIndex: -1, bassStrength: strength.clamp(0, 1));
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> setLoudnessGain(double gainDb) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(eqPresetIndex: -1, loudnessGain: gainDb);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> setReverbPreset(int preset) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(eqPresetIndex: -1, reverbPreset: preset);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> setDynamicsEnabled(bool enabled) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(eqPresetIndex: -1, dynamicsEnabled: enabled);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> setDynamicsThreshold(double thresholdDb) async {
    await _ensurePrefsLoaded();
    _current = _current.copyWith(eqPresetIndex: -1, dynamicsThreshold: thresholdDb);
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  // ─── Custom Presets ────────────────────────────────────────────────────────

  Future<List<CustomEqPreset>> loadCustomPresets() async {
    await _ensurePrefsLoaded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_k('custom_presets'));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CustomEqPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AudioFxService] failed to load custom presets: $e');
      return [];
    }
  }

  /// Persist the current effect state (normalized to the 10-band layout) as a
  /// named preset. Overwrites an existing preset with the same name.
  Future<bool> saveCustomPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await _ensurePrefsLoaded();
    final standardGains = resampleGains(_current.eqGains, eqFrequencies.length);
    final presets = await loadCustomPresets();
    final preset = CustomEqPreset(
      name: trimmed,
      gains: standardGains,
      bassStrength: _current.bassStrength,
      loudnessGain: _current.loudnessGain,
      reverbPreset: _current.reverbPreset,
      dynamicsEnabled: _current.dynamicsEnabled,
      dynamicsThreshold: _current.dynamicsThreshold,
    );
    final existing = presets.indexWhere((p) => p.name == trimmed);
    if (existing >= 0) {
      presets[existing] = preset;
    } else {
      presets.add(preset);
    }
    await _saveCustomPresets(presets);
    return true;
  }

  /// Apply a saved preset, restoring its full effect profile.
  Future<void> applyCustomPreset(String name) async {
    final presets = await loadCustomPresets();
    final preset = presets.where((p) => p.name == name).firstOrNull;
    if (preset == null) return;
    final bands = await _bandCount();
    _current = _current.copyWith(
      eqPresetIndex: -1,
      eqGains: resampleGains(preset.gains, bands),
      bassStrength: preset.bassStrength,
      loudnessGain: preset.loudnessGain,
      reverbPreset: preset.reverbPreset,
      dynamicsEnabled: preset.dynamicsEnabled,
      dynamicsThreshold: preset.dynamicsThreshold,
    );
    await _persist();
    _stateController.add(_current);
    await _pushAll();
  }

  Future<void> deleteCustomPreset(String name) async {
    final presets = await loadCustomPresets();
    presets.removeWhere((p) => p.name == name);
    await _saveCustomPresets(presets);
  }

  Future<void> _saveCustomPresets(List<CustomEqPreset> presets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _k('custom_presets'),
        jsonEncode(presets.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[AudioFxService] failed to save custom presets: $e');
    }
  }

  Future<int> _bandCount() async {
    final params = await ensureParameters();
    return params.bandCount > 0 ? params.bandCount : _current.eqGains.length;
  }

  /// Resample a gain profile onto [count] bands by linear position.
  static List<double> resampleGains(List<double> profile, int count) {
    if (count <= 0) return List.of(profile);
    if (count == profile.length) return List.of(profile);
    if (count == 1) return [profile.length > 2 ? profile[2] : profile.first];
    final out = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final pos = i / (count - 1) * (profile.length - 1);
      final low = pos.floor();
      final high = (low + 1).clamp(0, profile.length - 1);
      final frac = pos - low;
      out[i] = profile[low] + (profile[high] - profile[low]) * frac;
    }
    return out;
  }

  /// Whether two gain profiles are effectively identical within [epsilon] dB.
  /// Used to detect that a "Custom" state matches a saved preset.
  static bool gainsClose(List<double> a, List<double> b, {double epsilon = 0.05}) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > epsilon) return false;
    }
    return true;
  }

  Future<void> _pushAll() async {
    if (_sessionId <= 0) return;
    final s = _current;
    try {
      if (s.enabled) {
        await _channel.invokeMethod('setEqualizerEnabled', {'enabled': true});
        if (s.eqGains.isNotEmpty) {
          for (var i = 0; i < s.eqGains.length; i++) {
            await _channel.invokeMethod('setEqualizerBandGain', {'band': i, 'gainDb': s.eqGains[i]});
          }
        }
        await _channel.invokeMethod('setBassStrength', {'strength': (s.bassStrength * 1000).round()});
        await _channel.invokeMethod('setLoudnessTargetGain', {'gainDb': s.loudnessGain});
        await _channel.invokeMethod('setReverbPreset', {'preset': s.reverbPreset});
        await _channel.invokeMethod('setLimiterEnabled', {'enabled': s.dynamicsEnabled});
        if (s.dynamicsEnabled) {
          await _channel.invokeMethod('setLimiterThreshold', {'thresholdDb': s.dynamicsThreshold});
        }
      } else {
        // Neutralize everything so the effects are transparent.
        await _channel.invokeMethod('setEqualizerEnabled', {'enabled': false});
        for (var i = 0; i < s.eqGains.length; i++) {
          await _channel.invokeMethod('setEqualizerBandGain', {'band': i, 'gainDb': 0.0});
        }
        await _channel.invokeMethod('setBassStrength', {'strength': 0});
        await _channel.invokeMethod('setLoudnessTargetGain', {'gainDb': 0.0});
        await _channel.invokeMethod('setReverbPreset', {'preset': 0});
        await _channel.invokeMethod('setLimiterEnabled', {'enabled': false});
      }
    } on PlatformException catch (e) {
      debugPrint('[AudioFxService] push failed: $e');
    }
  }

  Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_k('enabled')) ?? false;
      final preset = prefs.getInt(_k('eq_preset')) ?? 0;
      final gainsRaw = prefs.getString(_k('eq_gains'));
      final gains = gainsRaw == null
          ? eqPresets.first.$2
          : gainsRaw.split(',').map((e) => double.tryParse(e) ?? 0).toList();
      final count = (await ensureParameters()).bandCount;
      _current = AudioFxState(
        enabled: enabled,
        eqPresetIndex: preset,
        eqGains: gains.length == count || count == 0 ? gains : resampleGains(gains, count),
        bassStrength: prefs.getDouble(_k('bass')) ?? 0,
        loudnessGain: prefs.getDouble(_k('loudness')) ?? 0,
        reverbPreset: prefs.getInt(_k('reverb')) ?? 0,
        dynamicsEnabled: prefs.getBool(_k('dynamics')) ?? false,
        dynamicsThreshold: prefs.getDouble(_k('dynamics_threshold')) ?? -10,
      );
    } catch (e) {
      debugPrint('[AudioFxService] failed to load prefs: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_k('enabled'), _current.enabled);
      await prefs.setInt(_k('eq_preset'), _current.eqPresetIndex);
      await prefs.setString(_k('eq_gains'), _current.eqGains.join(','));
      await prefs.setDouble(_k('bass'), _current.bassStrength);
      await prefs.setDouble(_k('loudness'), _current.loudnessGain);
      await prefs.setInt(_k('reverb'), _current.reverbPreset);
      await prefs.setBool(_k('dynamics'), _current.dynamicsEnabled);
      await prefs.setDouble(_k('dynamics_threshold'), _current.dynamicsThreshold);
    } catch (e) {
      debugPrint('[AudioFxService] failed to persist: $e');
    }
  }

  String _k(String key) => 'audiofx_$key';

  void dispose() {
    _stateController.close();
  }
}
