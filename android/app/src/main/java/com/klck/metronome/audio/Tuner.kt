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

    /** Rolling RMS of the input stream (0..1). Surfaces in the UI so a user
     *  can tell whether the mic is producing audio at all, separate from
     *  whether the pitch detector can lock onto a fundamental. */
    private val _inputLevel = MutableStateFlow(0f)
    val inputLevel: StateFlow<Float> = _inputLevel.asStateFlow()

    private val sampleRate = 48_000
    // ----- Analysis window sizing (Nyquist + period-count rationale) -----
    //
    // Nyquist bounds the highest frequency we can represent: sampleRate/2 =
    // 24 kHz, far above our 1.5 kHz musical ceiling. So aliasing isn't the
    // concern — period count is. Autocorrelation needs ≥3 periods of the
    // lowest frequency we care about to be reliable; with fewer, the ACF
    // peak gets washed out by window-edge truncation and the detector starts
    // octave-jumping. So pick the window size by the LOWEST frequency you
    // want to track:
    //
    //   target low      period      window for 3 periods    update rate
    //   ───────────     ────────    ─────────────────────   ───────────
    //   82 Hz (low E)   ~585 smp    1755 → round to 2048    ~23 Hz
    //   65 Hz (low C)   ~738 smp    2215 → round to 4096    ~11 Hz
    //   50 Hz (cap)     ~960 smp    2880 → round to 4096    ~11 Hz
    //
    // 4096 covers everything down through bass low B (~62 Hz) with a real
    // 3-period margin and still updates 11×/sec — plenty for a tuner needle.
    // The previous 1024-sample window was only ~1.75 periods of low E, which
    // is exactly where octave-jump bugs live; that's what made it "jumpy".
    private val analysisFrames = 4096
    private var smoothed: Double = 0.0
    private var captureJob: Job? = null
    private var scope: CoroutineScope? = null

    companion object {
        private const val TAG = "KlckTuner"
        private val noteNames = arrayOf("C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B")
        // Try sources from most-faithful (no AGC / noise suppression — best
        // for pitch detection) down to most-compatible (works on emulators
        // and devices that don't expose UNPROCESSED).
        private val SOURCES = intArrayOf(
            MediaRecorder.AudioSource.UNPROCESSED,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.DEFAULT,
        )
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

        // Walk the source list until one initializes successfully. Tracks
        // which source actually opened so a downstream "no signal" can hint
        // whether we fell back to a less-accurate source.
        var recorder: AudioRecord? = null
        var lastInitError: String? = null
        var openedSource: Int = -1
        for (src in SOURCES) {
            val candidate = try {
                AudioRecord.Builder()
                    .setAudioSource(src)
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
                lastInitError = "${sourceName(src)}: ${e.message}"
                android.util.Log.w(TAG, "AudioRecord build failed (${sourceName(src)})", e)
                null
            }
            if (candidate != null && candidate.state == AudioRecord.STATE_INITIALIZED) {
                recorder = candidate; openedSource = src
                android.util.Log.i(TAG, "AudioRecord initialized with source=${sourceName(src)}")
                break
            } else {
                candidate?.release()
                lastInitError = lastInitError ?: "${sourceName(src)}: state != INITIALIZED"
            }
        }
        if (recorder == null) {
            _lastError.value = "Mic input unavailable. Tried ${SOURCES.size} sources. Last error: $lastInitError"
            return
        }

        try {
            recorder.startRecording()
        } catch (e: Throwable) {
            _lastError.value = "AudioRecord start: ${e.message}"
            recorder.release()
            return
        }
        if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            _lastError.value = "AudioRecord did not enter RECORDING state (source=${sourceName(openedSource)})"
            recorder.release()
            return
        }

        _isListening.value = true
        val s = CoroutineScope(Dispatchers.Default)
        scope = s
        captureJob = s.launch {
            val buf = FloatArray(analysisFrames)
            var consecutiveZeroReads = 0
            var silentChunks = 0
            var levelSmoothed = 0f
            try {
                while (isActive && _isListening.value) {
                    val read = recorder.read(buf, 0, analysisFrames, AudioRecord.READ_BLOCKING)
                    if (read <= 0) {
                        consecutiveZeroReads++
                        if (consecutiveZeroReads >= 20) {
                            android.util.Log.w(TAG, "AudioRecord.read returned $read for 20+ iterations (source=${sourceName(openedSource)}). Stopping.")
                            _lastError.value = "No audio frames from mic. " +
                                "If you're on an emulator, the mic input may not be wired up — " +
                                "open Extended Controls (... button) → Microphone → enable 'Virtual microphone uses host audio input'."
                            break
                        }
                        continue
                    }
                    consecutiveZeroReads = 0

                    // Compute level for the UI meter even when pitch
                    // detection bails out — a flat level bar tells the user
                    // their mic isn't producing audio, separate from "audio
                    // is there but pitch isn't locking".
                    var sumSq = 0f
                    for (i in 0 until read) sumSq += buf[i] * buf[i]
                    val rms = kotlin.math.sqrt(sumSq / read)
                    levelSmoothed = levelSmoothed * 0.7f + rms * 0.3f
                    _inputLevel.value = levelSmoothed.coerceIn(0f, 1f)

                    // Silence detection — after ~3 s of true silence on the
                    // emulator, surface the host-mic-config hint.
                    if (rms < 0.001f) {
                        silentChunks++
                        if (silentChunks == 140) {  // ~3 s at 1024 frames @ 48 kHz
                            _lastError.value = "Receiving audio but it's silent. " +
                                "On an Android emulator: open Extended Controls (... button) → " +
                                "Microphone → enable 'Virtual microphone uses host audio input' " +
                                "and grant the macOS mic permission to the emulator process."
                        }
                    } else {
                        silentChunks = 0
                        if (_lastError.value?.startsWith("Receiving audio") == true) {
                            _lastError.value = null
                        }
                    }

                    val freq = detectPitch(buf, read, sampleRate.toDouble())
                    publish(freq)
                }
            } finally {
                try { recorder.stop() } catch (_: Throwable) {}
                recorder.release()
            }
        }
    }

    private fun sourceName(src: Int): String = when (src) {
        MediaRecorder.AudioSource.UNPROCESSED       -> "UNPROCESSED"
        MediaRecorder.AudioSource.VOICE_RECOGNITION -> "VOICE_RECOGNITION"
        MediaRecorder.AudioSource.MIC               -> "MIC"
        MediaRecorder.AudioSource.DEFAULT           -> "DEFAULT"
        else                                         -> "src#$src"
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
        _inputLevel.value = 0f
        smoothed = 0.0
    }

    /**
     * Counts how many consecutive detections have arrived that look like a
     * legitimate pitch change (not an octave error). Used to ratify a real
     * jump after a few confirmations instead of trusting the first
     * suspicious frame.
     */
    private var octaveJumpRunLength = 0

    private fun publish(freq: Double?) {
        if (freq == null || freq <= 0) {
            _hasSignal.value = false
            return
        }
        _hasSignal.value = true

        // Octave-jump rejection. The classic autocorrelation failure mode is
        // reporting half or double the true fundamental (later/earlier ACF
        // peak picked over the right one). Detect that by checking whether
        // the new reading is close to smoothed/2 or smoothed*2 — if so,
        // snap it to the smoothed octave instead of accepting the jump.
        // Genuine octave changes still come through, but only after several
        // consecutive readings agree (octaveJumpRunLength gate), so a single
        // noisy frame can't flip the displayed note an octave.
        var corrected = freq
        if (smoothed > 0) {
            val ratio = freq / smoothed
            val nearHalf   = ratio in 0.45..0.55
            val nearDouble = ratio in 1.85..2.15
            if (nearHalf || nearDouble) {
                octaveJumpRunLength++
                if (octaveJumpRunLength < 3) {
                    corrected = if (nearHalf) freq * 2.0 else freq / 2.0
                } else {
                    // Three frames in a row agreeing on the new octave —
                    // legitimate. Accept it and reset the gate.
                    octaveJumpRunLength = 0
                }
            } else {
                octaveJumpRunLength = 0
            }
        }

        // Heavier smoothing now that the underlying detection is more
        // reliable (3 periods of low E per window). 0.25/0.75 means the
        // displayed value lags one frame ~0.75x, giving the needle the
        // calm feel of a hardware tuner without losing responsiveness.
        smoothed = if (smoothed == 0.0) corrected else smoothed * 0.75 + corrected * 0.25
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
        // Need at least 2 periods of the lowest target frequency (50 Hz at
        // 48 kHz ≈ 1920 samples). Anything smaller and ACF is dominated by
        // the lag-0 envelope.
        if (n < 1920) return null

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
