package com.klck.metronome.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.log2
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Chromatic instrument tuner. Android port of Sources/Klck/Audio/Tuner.swift.
 *
 * - AudioRecord at 48 kHz / mono / float PCM with a 1024-sample analysis
 *   window (~21 ms @ 48 kHz, ~47 detection frames per second).
 * - Pitch detection via autocorrelation + parabolic interpolation. Picks
 *   the *first* significant ACF peak (not the global max) to avoid the
 *   classic octave-down bug; requires the ACF to dip past `dipThreshold`
 *   first so the lag-0 envelope can't be mistaken for the fundamental.
 * - Light frequency smoothing on the UI side (0.4/0.6 mix) — same time
 *   constant as iOS so the needle feels identical.
 *
 * Threading: the capture + analysis loop runs on Dispatchers.Default; the
 * UI just observes the published StateFlows.
 */
class Tuner {

    private val _isListening = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = _isListening.asStateFlow()

    private val _hasSignal = MutableStateFlow(false)
    val hasSignal: StateFlow<Boolean> = _hasSignal.asStateFlow()

    private val _frequency = MutableStateFlow(0.0)
    val frequency: StateFlow<Double> = _frequency.asStateFlow()

    private val _noteName = MutableStateFlow("—")
    val noteName: StateFlow<String> = _noteName.asStateFlow()

    private val _cents = MutableStateFlow(0.0)
    val cents: StateFlow<Double> = _cents.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val sampleRate = 48_000
    private val analysisFrames = 1024
    private var smoothed: Double = 0.0
    private var captureJob: Job? = null
    private var scope: CoroutineScope? = null

    companion object {
        private val noteNames = arrayOf("C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B")
    }

    fun toggle() { if (_isListening.value) stop() else start() }

    /** Caller must have already obtained RECORD_AUDIO permission. */
    @SuppressLint("MissingPermission")
    fun start() {
        if (_isListening.value) return
        _lastError.value = null
        smoothed = 0.0

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_FLOAT
        )
        val bufSize = maxOf(minBuf, analysisFrames * Float.SIZE_BYTES * 4)

        val recorder = try {
            AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.UNPROCESSED)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .build()
                )
                .setBufferSizeInBytes(bufSize)
                .build()
        } catch (e: Throwable) {
            _lastError.value = "AudioRecord init: ${e.message}"
            return
        }

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            _lastError.value = "AudioRecord not initialized"
            recorder.release()
            return
        }

        try {
            recorder.startRecording()
        } catch (e: Throwable) {
            _lastError.value = "AudioRecord start: ${e.message}"
            recorder.release()
            return
        }

        _isListening.value = true
        val s = CoroutineScope(Dispatchers.Default)
        scope = s
        captureJob = s.launch {
            val buf = FloatArray(analysisFrames)
            try {
                while (isActive && _isListening.value) {
                    val read = recorder.read(buf, 0, analysisFrames, AudioRecord.READ_BLOCKING)
                    if (read <= 0) break
                    val freq = detectPitch(buf, read, sampleRate.toDouble())
                    publish(freq)
                }
            } finally {
                try { recorder.stop() } catch (_: Throwable) {}
                recorder.release()
            }
        }
    }

    fun stop() {
        if (!_isListening.value) return
        _isListening.value = false
        captureJob?.cancel()
        scope?.cancel()
        captureJob = null
        scope = null
        _hasSignal.value = false
        _noteName.value = "—"
        _frequency.value = 0.0
        _cents.value = 0.0
        smoothed = 0.0
    }

    private fun publish(freq: Double?) {
        if (freq == null || freq <= 0) {
            _hasSignal.value = false
            return
        }
        _hasSignal.value = true
        smoothed = if (smoothed == 0.0) freq else smoothed * 0.4 + freq * 0.6
        _frequency.value = smoothed

        val midi = 69 + 12 * log2(smoothed / 440.0)
        val nearest = midi.roundToInt()
        val n = ((nearest % 12) + 12) % 12
        _noteName.value = "${noteNames[n]}${(nearest / 12) - 1}"
        _cents.value = (midi - nearest) * 100.0
    }

    // ---------- Pitch detection (autocorrelation + parabolic interpolation) ----------

    /**
     * Returns the estimated fundamental frequency, or null if no reliable
     * pitch is detected (signal too quiet, no significant ACF peak).
     */
    private fun detectPitch(samples: FloatArray, n: Int, sampleRate: Double): Double? {
        if (n < 1024) return null

        var mean = 0f
        for (i in 0 until n) mean += samples[i]
        mean /= n.toFloat()

        var energy = 0f
        val buf = FloatArray(n)
        for (i in 0 until n) {
            val v = samples[i] - mean
            buf[i] = v
            energy += v * v
        }
        val rms = sqrt(energy / n)
        if (rms <= 0.01f) return null   // too quiet

        val minFreq = 50.0
        val maxFreq = 1_500.0
        val minLag = maxOf((sampleRate / maxFreq).toInt(), 2)
        val maxLag = minOf((sampleRate / minFreq).toInt(), n - 1)
        if (maxLag <= minLag) return null

        // Peak/dip thresholds — see Swift source for the rationale on
        // dipping past the lag-0 envelope before trusting peaks.
        val peakThreshold = energy * 0.4f
        val dipThreshold = peakThreshold * 0.2f

        var firstPeakLag = -1
        var prev = 0f
        var rising = false
        var dipped = false

        var lag = minLag
        while (lag <= maxLag) {
            var sum = 0f
            for (i in 0 until (n - lag)) sum += buf[i] * buf[i + lag]

            if (!dipped) {
                if (sum < dipThreshold) dipped = true
                prev = sum
                lag++
                continue
            }

            if (sum > prev) {
                rising = true
            } else if (rising) {
                if (prev >= peakThreshold) {
                    firstPeakLag = lag - 1
                    break
                }
                rising = false
            }
            prev = sum
            lag++
        }
        if (firstPeakLag <= 0) return null

        // Parabolic interpolation around the peak.
        var refined = firstPeakLag.toDouble()
        if (firstPeakLag > minLag && firstPeakLag < maxLag) {
            val y0 = acf(buf, firstPeakLag - 1, n)
            val y1 = acf(buf, firstPeakLag, n)
            val y2 = acf(buf, firstPeakLag + 1, n)
            val denom = (y0 - 2f * y1 + y2)
            if (abs(denom) > 1e-9f) {
                refined = firstPeakLag + ((y0 - y2) / (2f * denom)).toDouble()
            }
        }
        if (refined <= 0) return null
        return sampleRate / refined
    }

    private fun acf(buf: FloatArray, lag: Int, n: Int): Float {
        if (lag < 0 || lag >= n) return 0f
        var sum = 0f
        for (i in 0 until (n - lag)) sum += buf[i] * buf[i + lag]
        return sum
    }
}
