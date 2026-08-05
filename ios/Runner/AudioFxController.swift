import Flutter
import UIKit

/// iOS stub for the `com.isai.music/audiofx` channel.
///
/// Real-time audio effects (Equalizer, BassBoost, Reverb, ...) are not wired up on
/// iOS yet. just_audio's Darwin backend (AVPlayer) does not expose the `AVPlayerItem`
/// or its `AVAudioMix`, which is what would be required to attach an
/// `AVAudioUnitEQ`/`MTAudioProcessingTap` for post-processing. Until playback moves to
/// an `AVAudioEngine`-based backend (e.g. AudioKit), effects are intentionally
/// reported as unsupported so the UI disables them on iOS.
class AudioFxController: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isai.music/audiofx",
      binaryMessenger: registrar.messenger()
    )
    let instance = AudioFxController()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getParameters":
      result([
        "supported": [
          "equalizer": false,
          "bassBoost": false,
          "loudness": false,
          "dynamics": false,
          "reverb": false,
        ],
        "equalizer": ["bandCount": 0],
      ])
    case "applySession", "release",
         "setEqualizerBandGain", "setBassStrength", "setLoudnessTargetGain",
         "setDynamicsLimiterThreshold", "setDynamicsEnabled", "setReverbPreset":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}