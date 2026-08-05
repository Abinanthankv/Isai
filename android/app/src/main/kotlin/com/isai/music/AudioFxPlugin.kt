package com.isai.music

import android.media.audiofx.BassBoost
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge that drives Android's [android.media.audiofx] effects (Equalizer,
 * BassBoost, LoudnessEnhancer, DynamicsProcessing and PresetReverb) for the audio
 * session created by just_audio's ExoPlayer.
 *
 * Equalizer strategy:
 *  - When the device HAL supports [DynamicsProcessing] (API 28+, most modern phones),
 *    a 10-band graphic EQ at ISO octave frequencies (31 Hz – 16 kHz) is driven through
 *    the PreEQ stage, with the limiter riding on the same effect. This gives a precise,
 *    device-independent EQ.
 *  - Otherwise the native [Equalizer] effect is used and its hardware band count
 *    (typically 5) is reported so the UI can show the right number of sliders.
 *
 * The effects are attached to a session id obtained from
 * `AudioPlayer.androidAudioSessionIdStream` on the Dart side. All effects start in a
 * neutral (transparent) state, so simply creating them does not alter playback.
 *
 * Usage from Flutter:
 *   MethodChannel('com.isai.music/audiofx')
 *     .invokeMethod('applySession', {'sessionId': <id>})
 *     .invokeMethod('getParameters')
 *     .invokeMethod('setEqualizerBandGain', {'band': i, 'gainDb': x})
 *     ...
 */
class AudioFxPlugin(flutterEngine: FlutterEngine) {
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var dynamics: DynamicsProcessing? = null
    private var reverb: PresetReverb? = null
    private var sessionId: Int = -1
    private var dynamicsChannelCount: Int = 2

    companion object {
        private const val METHOD_CHANNEL = "com.isai.music/audiofx"
        // ISO 1/1-octave graphic EQ centers (Hz): the audiophile-standard 10-band layout.
        private val ISO_EQ_FREQS = floatArrayOf(
            31f, 62f, 125f, 250f, 500f, 1000f, 2000f, 4000f, 8000f, 16000f
        )
        // PresetReverb presets exposed to Dart (index order matches the constants below).
        private val REVERB_PRESETS = shortArrayOf(
            PresetReverb.PRESET_NONE,
            PresetReverb.PRESET_SMALLROOM,
            PresetReverb.PRESET_MEDIUMROOM,
            PresetReverb.PRESET_LARGEROOM,
            PresetReverb.PRESET_PLATE,
            PresetReverb.PRESET_MEDIUMHALL,
            PresetReverb.PRESET_LARGEHALL
        )
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "applySession" -> {
                            val id = call.argument<Int>("sessionId") ?: 0
                            applySession(id)
                            result.success(null)
                        }
                        "release" -> {
                            release()
                            result.success(null)
                        }
                        "getParameters" -> result.success(getParameters())
                        "setEqualizerBandGain" -> {
                            val band = call.argument<Int>("band") ?: 0
                            val gainDb = (call.argument<Double>("gainDb") ?: 0.0)
                            setEqualizerBandGain(band, gainDb)
                            result.success(null)
                        }
                        "setEqualizerEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            setEqualizerEnabled(enabled)
                            result.success(null)
                        }
                        "setLimiterEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            setLimiterEnabled(enabled)
                            result.success(null)
                        }
                        "setLimiterThreshold" -> {
                            val thresholdDb = call.argument<Double>("thresholdDb") ?: 0.0
                            setLimiterThreshold(thresholdDb)
                            result.success(null)
                        }
                        "setBassStrength" -> {
                            val strength = call.argument<Int>("strength") ?: 0
                            setBassStrength(strength)
                            result.success(null)
                        }
                        "setLoudnessTargetGain" -> {
                            val gainDb = call.argument<Double>("gainDb") ?: 0.0
                            setLoudnessTargetGain(gainDb)
                            result.success(null)
                        }
                        "setReverbPreset" -> {
                            val preset = call.argument<Int>("preset") ?: 0
                            setReverbPreset(preset)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("AUDIOFX_ERROR", e.message, null)
                }
            }
    }

    /** True when the 10-band DynamicsProcessing EQ is in use. */
    private val hasDynamicsEq: Boolean
        get() = dynamics != null

    /** Attach all effects to [id] (just_audio's audio session). Neutral by default. */
    private fun applySession(id: Int) {
        if (id == sessionId && (equalizer != null || dynamics != null)) return
        release()
        sessionId = id

        // Each effect is created independently so an unsupported effect on some
        // device never prevents the others from working.
        try {
            equalizer = Equalizer(0, id).apply { enabled = true }
        } catch (_: Exception) {
            equalizer = null
        }
        try {
            bassBoost = BassBoost(0, id).apply { enabled = true }
        } catch (_: Exception) {
            bassBoost = null
        }
        try {
            loudnessEnhancer = LoudnessEnhancer(id).apply { enabled = true }
        } catch (_: Exception) {
            loudnessEnhancer = null
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                dynamics = buildDynamics()
            }
        } catch (_: Exception) {
            dynamics = null
        }
        try {
            reverb = PresetReverb(0, id).apply {
                setPreset(PresetReverb.PRESET_NONE)
                enabled = true
            }
        } catch (_: Exception) {
            reverb = null
        }
    }

    /**
     * Apply gain (dB) to EQ band [band].
     * 10-band mode: writes to every channel's PreEQ stage.
     * Fallback mode: native [Equalizer].
     */
    private fun setEqualizerBandGain(band: Int, gainDb: Double) {
        val d = dynamics
        if (d != null && band in 0 until ISO_EQ_FREQS.size) {
            val bandCfg = DynamicsProcessing.EqBand(true, ISO_EQ_FREQS[band], gainDb.toFloat())
            for (ch in 0 until dynamicsChannelCount) {
                d.setPreEqBandByChannelIndex(ch, band, bandCfg)
            }
            return
        }
        val eq = equalizer ?: return
        val min = eq.bandLevelRange[0].toDouble()
        val max = eq.bandLevelRange[1].toDouble()
        val gainMb = (gainDb * 100.0).coerceIn(min, max)
        eq.setBandLevel(band.toShort(), gainMb.toInt().toShort())
    }

    /** Toggle the equalizer stage (PreEQ in 10-band mode, native Equalizer otherwise). */
    private fun setEqualizerEnabled(enabled: Boolean) {
        val d = dynamics
        if (d != null) {
            for (ch in 0 until dynamicsChannelCount) {
                d.getPreEqByChannelIndex(ch).setEnabled(enabled)
            }
            return
        }
        try {
            equalizer?.enabled = enabled
        } catch (_: Exception) {
            // Ignore
        }
    }

    /** Toggle the limiter stage (only available with DynamicsProcessing). */
    private fun setLimiterEnabled(enabled: Boolean) {
        val d = dynamics ?: return
        for (ch in 0 until dynamicsChannelCount) {
            d.getLimiterByChannelIndex(ch).setEnabled(enabled)
        }
    }

    /** Live update of the limiter threshold in dB. */
    private fun setLimiterThreshold(thresholdDb: Double) {
        val d = dynamics ?: return
        for (ch in 0 until dynamicsChannelCount) {
            d.getLimiterByChannelIndex(ch).setThreshold(thresholdDb.toFloat())
        }
    }

    private fun setBassStrength(strength: Int) {
        bassBoost?.setStrength(strength.coerceIn(0, 1000).toShort())
    }

    private fun setLoudnessTargetGain(gainDb: Double) {
        // LoudnessEnhancer takes gain in millibels.
        loudnessEnhancer?.setTargetGain((gainDb * 100.0).toInt())
    }

    /**
     * Build the 10-band Precision EQ + limiter engine.
     * Music playback is stereo in virtually all cases, so the config uses 2 channels;
     * if a device's HAL rejects the topology the caller falls back to the native
     * [Equalizer].
     */
    private fun buildDynamics(): DynamicsProcessing {
        dynamicsChannelCount = 2
        val preEq = DynamicsProcessing.Eq(true, true, ISO_EQ_FREQS.size)
        for (i in ISO_EQ_FREQS.indices) {
            preEq.setBand(i, DynamicsProcessing.EqBand(true, ISO_EQ_FREQS[i], 0f))
        }
        val limiter = DynamicsProcessing.Limiter(
            true,  // enable
            false, // linkGroup
            5,     // attackTime (ms)
            50f,   // releaseTime (ms)
            10f,   // ratio
            -10f,  // threshold (dB)
            0f,    // postGain (dB)
            0f     // stage
        )
        val config = DynamicsProcessing.Config.Builder(
            DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
            dynamicsChannelCount,
            true,  // preEqInUse
            ISO_EQ_FREQS.size, // preEqBandCount
            false, // mbcInUse
            0,     // mbcBandCount
            false, // postEqInUse
            0,     // postEqBandCount
            true   // limiterInUse
        ).setPreEqAllChannelsTo(preEq).setLimiterAllChannelsTo(limiter).build()
        return DynamicsProcessing(0, sessionId, config).apply { enabled = true }
    }

    private fun setReverbPreset(preset: Int) {
        val reverbFx = reverb ?: return
        val index = preset.coerceIn(0, REVERB_PRESETS.size - 1)
        reverbFx.setPreset(REVERB_PRESETS[index])
    }

    /** Device capabilities + equalizer band layout, consumed by the Flutter sheet. */
    private fun getParameters(): Map<String, Any> {
        val eq10 = hasDynamicsEq
        val supported = mapOf(
            "equalizer" to (eq10 || equalizer != null),
            "eq10" to eq10,
            "bassBoost" to (bassBoost != null),
            "loudness" to (loudnessEnhancer != null),
            "dynamics" to (dynamics != null),
            "reverb" to (reverb != null)
        )

        val eqParams = HashMap<String, Any>()
        if (eq10) {
            val bands = mutableListOf<Map<String, Any>>()
            for (freq in ISO_EQ_FREQS) {
                bands.add(mapOf("index" to bands.size, "centerFrequency" to freq.toDouble(), "gainDb" to 0.0))
            }
            eqParams["bandCount"] = ISO_EQ_FREQS.size
            eqParams["minDecibels"] = -12.0
            eqParams["maxDecibels"] = 12.0
            eqParams["bands"] = bands
        } else {
            equalizer?.let { eq ->
                val bands = mutableListOf<Map<String, Any>>()
                for (i in 0 until eq.numberOfBands) {
                    val range = eq.getBandFreqRange(i.toShort())
                    bands.add(
                        mapOf(
                            "index" to i,
                            "centerFrequency" to eq.getCenterFreq(i.toShort()).toDouble(),
                            "lowerFrequency" to range[0].toDouble(),
                            "upperFrequency" to range[1].toDouble(),
                            "gainDb" to (eq.getBandLevel(i.toShort()) / 100.0)
                        )
                    )
                }
                val levelRange = eq.bandLevelRange
                eqParams["bandCount"] = eq.numberOfBands
                eqParams["minDecibels"] = levelRange[0] / 100.0
                eqParams["maxDecibels"] = levelRange[1] / 100.0
                eqParams["bands"] = bands
            }
        }

        return mapOf("supported" to supported, "equalizer" to eqParams)
    }

    fun dispose() {
        release()
    }

    private fun release() {
        listOf(equalizer, bassBoost, loudnessEnhancer, dynamics, reverb).forEach { effect ->
            try {
                effect?.enabled = false
                effect?.release()
            } catch (_: Exception) {
                // Ignore cleanup errors
            }
        }
        equalizer = null
        bassBoost = null
        loudnessEnhancer = null
        dynamics = null
        reverb = null
        dynamicsChannelCount = 2
        sessionId = -1
    }
}
