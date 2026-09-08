package com.openhearables.open_hearables

import android.content.Context
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SystemEqualizerPlugin(private val context: Context) : MethodCallHandler {

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var isInitialized = false

    companion object {
        const val CHANNEL_NAME = "com.openhearables.app/equalizer"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                try {
                    initAudioEffects()
                    result.success(getEqualizerData())
                } catch (e: Exception) {
                    result.error("INIT_FAILED", e.localizedMessage, null)
                }
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                try {
                    equalizer?.enabled = enabled
                    bassBoost?.enabled = enabled
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_ENABLED_FAILED", e.localizedMessage, null)
                }
            }
            "setBandLevel" -> {
                val band = call.argument<Int>("band")
                val level = call.argument<Int>("level")
                if (band != null && level != null && equalizer != null) {
                    try {
                        equalizer?.setBandLevel(band.toShort(), level.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SET_BAND_FAILED", e.localizedMessage, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing band or level", null)
                }
            }
            "setBassBoost" -> {
                val strength = call.argument<Int>("strength") ?: 0
                try {
                    bassBoost?.setStrength(strength.coerceIn(0, 1000).toShort())
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_BASS_FAILED", e.localizedMessage, null)
                }
            }
            "release" -> {
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun initAudioEffects() {
        if (isInitialized) return

        // Audio Session 0 applies to global system audio output mix
        try {
            equalizer = Equalizer(0, 0).apply {
                enabled = true
            }
        } catch (e: Exception) {
            // Fallback for devices restricting session 0
            equalizer = null
        }

        try {
            bassBoost = BassBoost(0, 0).apply {
                enabled = true
            }
        } catch (e: Exception) {
            bassBoost = null
        }

        isInitialized = true
    }

    private fun getEqualizerData(): Map<String, Any?> {
        val eq = equalizer ?: return mapOf(
            "supported" to false,
            "numberOfBands" to 0,
            "minLevel" to -1500,
            "maxLevel" to 1500,
            "bands" to emptyList<Map<String, Any>>()
        )

        val numBands = eq.numberOfBands.toInt()
        val range = eq.bandLevelRange
        val minLevel = range[0].toInt()
        val maxLevel = range[1].toInt()

        val bandsList = mutableListOf<Map<String, Any>>()
        for (i in 0 until numBands) {
            val centerFreq = eq.getCenterFreq(i.toShort())
            val currentLevel = eq.getBandLevel(i.toShort()).toInt()
            bandsList.add(
                mapOf(
                    "index" to i,
                    "centerFreq" to centerFreq,
                    "level" to currentLevel
                )
            )
        }

        return mapOf(
            "supported" to true,
            "numberOfBands" to numBands,
            "minLevel" to minLevel,
            "maxLevel" to maxLevel,
            "bands" to bandsList,
            "bassBoostSupported" to (bassBoost?.strengthSupported ?: false)
        )
    }

    fun release() {
        try {
            equalizer?.release()
            bassBoost?.release()
        } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        isInitialized = false
    }
}
