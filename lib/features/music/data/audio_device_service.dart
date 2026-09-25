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

  const AudioOutputInfo({
    required this.deviceName,
    required this.outputType,
    required this.codecName,
    required this.transmissionDetails,
    this.isBitPerfect = false,
    this.supportedSampleRates = const [],
    this.permissionGranted = true,
  });

  factory AudioOutputInfo.speaker() {
    return const AudioOutputInfo(
      deviceName: 'Phone Speaker',
      outputType: AudioOutputType.speaker,
      codecName: 'Internal AudioFlinger',
      transmissionDetails: '16-bit / 48 kHz System Output',
      isBitPerfect: false,
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
      );
    }

    return const AudioOutputInfo(
      deviceName: 'Wired Headphones',
      outputType: AudioOutputType.wiredHeadphones,
      codecName: '3.5mm Analog Output',
      transmissionDetails: '24-bit / 48 kHz DAC Output',
      isBitPerfect: false,
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
