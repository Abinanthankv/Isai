import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum AudioOutputType {
  bluetooth,
  usbDac,
  wiredHeadphones,
  speaker,
  unknown,
}

class AudioOutputInfo {
  final String deviceName;
  final AudioOutputType outputType;
  final String codecName;
  final String transmissionDetails;
  final bool isBitPerfect;
  final List<int> supportedSampleRates;
  final bool permissionGranted;
  final String route;
  final String transport;
  final String directStatus;
  final int systemSampleRate;
  final int systemBufferFrames;
  final String systemHal;
  final String bluetoothProfile;
  final String audioTrackFormat;

  const AudioOutputInfo({
    required this.deviceName,
    required this.outputType,
    required this.codecName,
    required this.transmissionDetails,
    this.isBitPerfect = false,
    this.supportedSampleRates = const [],
    this.permissionGranted = true,
    this.route = 'SPEAKER',
    this.transport = 'AudioTrack',
    this.directStatus = 'Not Supported (Mixed Path)',
    this.systemSampleRate = 48000,
    this.systemBufferFrames = 960,
    this.systemHal = 'AudioFlinger Mixer 48000 Hz, HAL PCM24 packed',
    this.bluetoothProfile = 'N/A',
    this.audioTrackFormat = 'PCM16 / 48000 Hz',
  });

  factory AudioOutputInfo.speaker() {
    return const AudioOutputInfo(
      deviceName: 'Phone Speaker',
      outputType: AudioOutputType.speaker,
      codecName: 'Internal AudioFlinger',
      transmissionDetails: '16-bit / 48 kHz System Output',
      isBitPerfect: false,
      route: 'SPEAKER',
      transport: 'AudioTrack',
      directStatus: 'Not Supported (Mixed Path)',
      systemSampleRate: 48000,
      systemBufferFrames: 960,
      systemHal: 'AudioFlinger Mixer 48000 Hz, HAL PCM24 packed',
      bluetoothProfile: 'N/A',
      audioTrackFormat: 'PCM16 / 48000 Hz',
    );
  }

  factory AudioOutputInfo.wired({bool isUsb = false, bool isBitPerfect = false, List<int>? sampleRates}) {
    if (isUsb) {
      final ratesStr = (sampleRates != null && sampleRates.isNotEmpty)
          ? '${(sampleRates.last / 1000).toStringAsFixed(1)} kHz Max'
          : '24-bit / 192 kHz';
      return AudioOutputInfo(
        deviceName: 'External USB DAC',
        outputType: AudioOutputType.usbDac,
        codecName: isBitPerfect ? 'USB Direct PCM (Bit-Perfect)' : 'AudioFlinger PCM',
        transmissionDetails: isBitPerfect
            ? 'Bit-Perfect Direct • $ratesStr'
            : 'Resampled System Output • $ratesStr',
        isBitPerfect: isBitPerfect,
        supportedSampleRates: sampleRates ?? [44100, 48000, 96000, 192000],
        route: 'USB',
        transport: isBitPerfect ? 'Direct USB' : 'AudioTrack',
        directStatus: isBitPerfect ? 'Supported (Bit-Perfect Direct)' : 'Not Supported (Mixed Path)',
        systemSampleRate: 48000,
        systemBufferFrames: 960,
        systemHal: isBitPerfect ? 'Direct Hardware Pass-Through' : 'AudioFlinger Mixer 48000 Hz, HAL PCM24 packed',
        bluetoothProfile: 'N/A',
        audioTrackFormat: isBitPerfect ? 'FLOAT32 / 192000 Hz' : 'PCM16 / 48000 Hz',
      );
    }

    return const AudioOutputInfo(
      deviceName: 'Wired Headphones',
      outputType: AudioOutputType.wiredHeadphones,
      codecName: '3.5mm Analog Output',
      transmissionDetails: '24-bit / 48 kHz DAC Output',
      isBitPerfect: false,
      route: 'WIRED',
      transport: 'AudioTrack',
      directStatus: 'Not Supported (Mixed Path)',
      systemSampleRate: 48000,
      systemBufferFrames: 960,
      systemHal: 'AudioFlinger Mixer 48000 Hz, HAL PCM24 packed',
      bluetoothProfile: 'N/A',
      audioTrackFormat: 'PCM16 / 48000 Hz',
    );
  }

  factory AudioOutputInfo.bluetooth({
    String? deviceName,
    String? codec,
    String? details,
    bool permissionGranted = true,
  }) {
    final name = deviceName ?? 'Bluetooth Device';
    final activeCodec = codec ?? 'LDAC / aptX HD / AAC';
    final transmDetails = details ?? 'High Quality (Up to 990 kbps • 24-bit/96kHz)';

    return AudioOutputInfo(
      deviceName: name,
      outputType: AudioOutputType.bluetooth,
      codecName: activeCodec,
      transmissionDetails: transmDetails,
      isBitPerfect: false,
      permissionGranted: permissionGranted,
      route: 'BLUETOOTH',
      transport: 'AudioTrack',
      directStatus: 'Not Supported (Mixed Path)',
      systemSampleRate: 48000,
      systemBufferFrames: 960,
      systemHal: 'AudioFlinger Mixer 48000 Hz, HAL PCM24 packed',
      bluetoothProfile: 'A2DP',
      audioTrackFormat: 'PCM16 / 48000 Hz',
    );
  }
}

class AudioDeviceService {
  static const MethodChannel _channel = MethodChannel('com.isai.music/audio_device');

  /// Proactively request Bluetooth Connect permission and inspect current audio output hardware
  static Future<AudioOutputInfo> getCurrentOutputInfo({bool isBitPerfectSettingEnabled = true}) async {
    bool hasPermission = true;

    // Proactively request Bluetooth Connect permission on Android 12+
    try {
      final status = await Permission.bluetoothConnect.status;
      if (!status.isGranted) {
        final req = await Permission.bluetoothConnect.request();
        hasPermission = req.isGranted;
      }
    } catch (_) {
      // Non-mobile platforms or fallback
    }

    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getCurrentOutputInfo', {
        'bitPerfectEnabled': isBitPerfectSettingEnabled,
      });

      if (result != null) {
        final typeStr = result['outputType'] as String? ?? 'speaker';
        final name = result['deviceName'] as String? ?? 'Audio Output';
        final codec = result['codec'] as String? ?? 'PCM';
        final details = result['details'] as String? ?? '';
        final isBitPerfect = result['isBitPerfect'] as bool? ?? false;
        final ratesRaw = result['sampleRates'] as List<dynamic>?;
        final sampleRates = ratesRaw?.map((e) => (e as num).toInt()).toList() ?? [];

        final route = result['route'] as String? ?? (typeStr == 'bluetooth' ? 'BLUETOOTH' : (typeStr == 'usb_dac' ? 'USB' : (typeStr == 'wired' ? 'WIRED' : 'SPEAKER')));
        final transport = result['transport'] as String? ?? (isBitPerfect ? 'Direct USB' : 'AudioTrack');
        final directStatus = result['directStatus'] as String? ?? (isBitPerfect ? 'Supported (Bit-Perfect Direct)' : 'Not Supported (Mixed Path)');
        final sysSampleRate = (result['systemSampleRate'] as num?)?.toInt() ?? 48000;
        final sysFrames = (result['systemBufferFrames'] as num?)?.toInt() ?? 960;
        final sysHal = result['systemHal'] as String? ?? 'AudioFlinger Mixer $sysSampleRate Hz, HAL PCM24 packed';
        final btProfile = result['bluetoothProfile'] as String? ?? (typeStr == 'bluetooth' ? 'A2DP' : 'N/A');
        final trackFormat = result['audioTrackFormat'] as String? ?? 'PCM16 / $sysSampleRate Hz';

        AudioOutputType type = AudioOutputType.speaker;
        if (typeStr == 'bluetooth') {
          type = AudioOutputType.bluetooth;
        } else if (typeStr == 'usb_dac') {
          type = AudioOutputType.usbDac;
        } else if (typeStr == 'wired') {
          type = AudioOutputType.wiredHeadphones;
        }

        return AudioOutputInfo(
          deviceName: name,
          outputType: type,
          codecName: codec,
          transmissionDetails: details,
          isBitPerfect: isBitPerfect,
          supportedSampleRates: sampleRates,
          permissionGranted: hasPermission,
          route: route,
          transport: transport,
          directStatus: directStatus,
          systemSampleRate: sysSampleRate,
          systemBufferFrames: sysFrames,
          systemHal: sysHal,
          bluetoothProfile: btProfile,
          audioTrackFormat: trackFormat,
        );
      }
    } catch (e) {
      print('[AudioDeviceService] Native channel fallback: $e');
    }

    // Fallback heuristic if native plugin channel is not registered
    if (isBitPerfectSettingEnabled) {
      return AudioOutputInfo.bluetooth(permissionGranted: hasPermission);
    }
    return AudioOutputInfo.speaker();
  }
}
