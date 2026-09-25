package com.isai.music

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AudioDevicePlugin(private val context: Context, flutterEngine: FlutterEngine) {

    companion object {
        private const val METHOD_CHANNEL = "com.isai.music/audio_device"
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentOutputInfo" -> {
                        val bitPerfectRequested = call.argument<Boolean>("bitPerfectEnabled") ?: true
                        val info = getAudioOutputInfo(bitPerfectRequested)
                        result.success(info)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getAudioOutputInfo(bitPerfectRequested: Boolean): Map<String, Any?> {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return fallbackInfo("Phone Speaker", "speaker", "Internal AudioFlinger", "16-bit / 48 kHz System Output", false, emptyList())

        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        // 1. Check for Connected Bluetooth Devices
        val btDevice = devices.firstOrNull { 
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || 
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && it.type == AudioDeviceInfo.TYPE_HEARING_AID) ||
            (Build.VERSION.SDK_INT >= 31 && it.type == 26)
        }

        if (btDevice != null) {
            val name = getConnectedBluetoothName(btDevice)

            // Determine active Bluetooth codec based on sample rates and encodings
            val sampleRates = btDevice.sampleRates
            val maxRate = sampleRates.maxOrNull() ?: 44100
            
            var codecName = "AAC (High Quality)"
            var details = "256 kbps • 16-bit / 44.1 kHz"

            if (maxRate >= 96000) {
                codecName = "LDAC (Quality Priority)"
                details = "990 kbps • 24-bit / 96 kHz High-Res"
            } else if (maxRate >= 48000) {
                codecName = "aptX HD / AAC"
                details = "576 kbps • 24-bit / 48 kHz"
            } else {
                codecName = "AAC / SBC"
                details = "256–328 kbps • 16-bit / 44.1 kHz"
            }

            return mapOf(
                "deviceName" to name,
                "outputType" to "bluetooth",
                "codec" to codecName,
                "details" to details,
                "isBitPerfect" to false,
                "sampleRates" to sampleRates.toList()
            )
        }

        // 2. Check for Connected USB DAC / USB Audio
        val usbDevice = devices.firstOrNull { 
            it.type == AudioDeviceInfo.TYPE_USB_DEVICE || 
            it.type == AudioDeviceInfo.TYPE_USB_HEADSET || 
            it.type == AudioDeviceInfo.TYPE_USB_ACCESSORY 
        }

        if (usbDevice != null) {
            val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pName = usbDevice.productName?.toString()
                if (!pName.isNull_or_blank()) pName else "External USB DAC"
            } else "External USB DAC"

            val sampleRates = usbDevice.sampleRates.toList()
            val maxRate = sampleRates.maxOrNull() ?: 192000
            val maxKhzStr = "${maxRate / 1000} kHz"

            val isBitPerfect = bitPerfectRequested && Build.VERSION.SDK_INT >= 34

            return mapOf(
                "deviceName" to name,
                "outputType" to "usb_dac",
                "codec" to if (isBitPerfect) "USB Direct PCM (Bit-Perfect)" else "AudioFlinger PCM",
                "details" to if (isBitPerfect) "Bit-Perfect Direct • Up to 24-bit / $maxKhzStr" else "Resampled System Output • Up to 24-bit / $maxKhzStr",
                "isBitPerfect" to isBitPerfect,
                "sampleRates" to sampleRates
            )
        }

        // 3. Check for 3.5mm Wired Headphones
        val wiredDevice = devices.firstOrNull { 
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES || 
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET 
        }

        if (wiredDevice != null) {
            val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pName = wiredDevice.productName?.toString()
                if (!pName.isNull_or_blank()) pName else "Wired Headphones"
            } else "Wired Headphones"

            return mapOf(
                "deviceName" to name,
                "outputType" to "wired",
                "codec" to "3.5mm Analog Output",
                "details" to "24-bit / 48 kHz DAC Output",
                "isBitPerfect" to false,
                "sampleRates" to wiredDevice.sampleRates.toList()
            )
        }

        // 4. Fallback to Phone Speaker
        return fallbackInfo("Phone Speaker", "speaker", "Internal AudioFlinger", "16-bit / 48 kHz System Output", false, emptyList())
    }

    private fun fallbackInfo(
        name: String,
        type: String,
        codec: String,
        details: String,
        isBitPerfect: Boolean,
        rates: List<Int>
    ): Map<String, Any?> {
        return mapOf(
            "deviceName" to name,
            "outputType" to type,
            "codec" to codec,
            "details" to details,
            "isBitPerfect" to isBitPerfect,
            "sampleRates" to rates
        )
    }

    private fun getConnectedBluetoothName(btDevice: AudioDeviceInfo): String {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pName = btDevice.productName?.toString()
                if (!pName.isNull_or_blank() && pName != "Bluetooth Device") {
                    return pName!!
                }
            }
        } catch (_: Exception) {}

        try {
            val adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (adapter != null && adapter.isEnabled) {
                @Suppress("MissingPermission")
                val bonded = adapter.bondedDevices
                val active = bonded?.firstOrNull { !it.name.isNull_or_blank() }
                if (active != null && !active.name.isNull_or_blank()) {
                    return active.name!!
                }
            }
        } catch (_: Exception) {}

        return "Bluetooth Headset / Audio"
    }

    private fun String?.isNull_or_blank(): Boolean {
        return this == null || this.trim().isEmpty()
    }
}
