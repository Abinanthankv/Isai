package com.isai.music

import android.media.audiofx.Visualizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge that uses Android's [android.media.audiofx.Visualizer] to capture
 * real-time FFT (frequency) data from the audio output and stream it to Flutter
 * via an [EventChannel].
 *
 * Usage from Flutter:
 *   MethodChannel('com.isai.music/visualizer').invokeMethod('start', audioSessionId)
 *   EventChannel('com.isai.music/visualizer_fft').receiveBroadcastStream()
 */
class AudioVisualizerPlugin(flutterEngine: FlutterEngine) {
    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val METHOD_CHANNEL = "com.isai.music/visualizer"
        private const val EVENT_CHANNEL = "com.isai.music/visualizer_fft"
        // Capture size must be a power of 2 between 128 and 1024
        private const val CAPTURE_SIZE = 256
    }

    init {
        // Method channel for start/stop control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sessionId = call.arguments as? Int ?: 0
                        startVisualizer(sessionId)
                        result.success(true)
                    }
                    "stop" -> {
                        stopVisualizer()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for streaming FFT data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun startVisualizer(audioSessionId: Int) {
        stopVisualizer() // Clean up any existing instance

        try {
            visualizer = Visualizer(audioSessionId).apply {
                captureSize = CAPTURE_SIZE
                setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(
                            vis: Visualizer?,
                            waveform: ByteArray?,
                            samplingRate: Int
                        ) {
                            // We only use FFT data, not raw waveform
                        }

                        override fun onFftDataCapture(
                            vis: Visualizer?,
                            fft: ByteArray?,
                            samplingRate: Int
                        ) {
                            if (fft != null && eventSink != null) {
                                // Convert signed bytes to a list of magnitudes (0–255)
                                // FFT data: [real0, imag0, real1, imag1, ...]
                                // We compute magnitude = sqrt(real^2 + imag^2) for each bin
                                val magnitudes = mutableListOf<Int>()
                                // Skip DC component (index 0,1)
                                var i = 2
                                while (i < fft.size - 1) {
                                    val real = fft[i].toInt()
                                    val imag = fft[i + 1].toInt()
                                    val magnitude = Math.sqrt((real * real + imag * imag).toDouble()).toInt()
                                        .coerceIn(0, 255)
                                    magnitudes.add(magnitude)
                                    i += 2
                                }
                                eventSink?.success(magnitudes)
                            }
                        }
                    },
                    Visualizer.getMaxCaptureRate() / 2, // ~10 fps capture rate
                    false, // waveform capture disabled
                    true   // FFT capture enabled
                )
                enabled = true
            }
        } catch (e: Exception) {
            eventSink?.error("VISUALIZER_ERROR", "Failed to start visualizer: ${e.message}", null)
        }
    }

    private fun stopVisualizer() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Exception) {
            // Ignore cleanup errors
        }
        visualizer = null
    }

    fun dispose() {
        stopVisualizer()
        eventSink = null
    }
}
