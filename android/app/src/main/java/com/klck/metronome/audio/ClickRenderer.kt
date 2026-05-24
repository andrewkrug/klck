package com.klck.metronome.audio

import com.klck.metronome.model.ClickWaveform
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sign
import kotlin.math.sin
import kotlin.random.Random

/**
 * Pre-renders a short click envelope into a Float PCM buffer. Mirrors the
 * one-shot click synthesis in Sources/Klck/Audio/AudioEngine.swift —
 * exponentially-decaying tone with a sharp transient, ~30 ms long.
 *
 * The engine treats the returned buffer as a "voice" to mix into the output
 * stream at a specific sample-frame position.
 */
object ClickRenderer {

    /** Tone-frequency defaults that match the Swift engine's per-role pitch. */
    const val ACCENT_HZ: Float = 1_800f
    const val BEAT_HZ:   Float = 1_400f

    /** Pre-rendered click length in seconds. */
    private const val DURATION_SEC: Float = 0.030f

    /** Exponential-decay time constant (larger = longer tail). */
    private const val DECAY: Float = 60f

    private val rng = Random(42)

    /**
     * Synthesize a click envelope. Sample rate is the destination engine's
     * rate (typically 48 kHz).
     */
    fun render(sampleRate: Int, frequency: Float, waveform: ClickWaveform, amplitude: Float): FloatArray {
        val n = (sampleRate * DURATION_SEC).toInt()
        val out = FloatArray(n)
        val twoPiF = (2.0 * PI * frequency).toFloat() / sampleRate
        var phase = 0f
        for (i in 0 until n) {
            val t = i.toFloat() / sampleRate
            val env = exp(-DECAY * t)
            val raw = when (waveform) {
                ClickWaveform.SINE     -> sin(phase.toDouble()).toFloat()
                ClickWaveform.TRIANGLE -> triangle(phase)
                ClickWaveform.SQUARE   -> sign(sin(phase.toDouble())).toFloat()
                ClickWaveform.NOISE    -> (rng.nextFloat() * 2f - 1f)
            }
            out[i] = raw * env * amplitude
            phase += twoPiF
            if (phase > 2 * PI) phase -= (2 * PI).toFloat()
        }
        return out
    }

    private fun triangle(phase: Float): Float {
        // Phase in [0, 2π) → triangle in [-1, 1].
        val p = (phase / (2 * PI.toFloat())) % 1f
        return if (p < 0.5f) 4f * p - 1f else 3f - 4f * p
    }
}
