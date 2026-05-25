package com.klck.metronome.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import com.klck.metronome.model.BeatAccent
import com.klck.metronome.model.ClickWaveform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sin

/**
 * Sample-accurate metronome audio engine — Android port of
 * Sources/Klck/Audio/AudioEngine.swift.
 *
 * Architecture:
 *   - One AudioTrack in MODE_STREAM at 48 kHz / mono / Float PCM.
 *   - A render coroutine (Dispatchers.Default) computes the next chunk
 *     of samples in a tight loop, blocking on AudioTrack.write to pace
 *     itself with the playback clock.
 *   - Inside the chunk loop we keep an absolute sampleClock and three
 *     parallel schedulers (main beat / 16th grid / triplet grid) that
 *     trigger voices when `now >= nextX`. Voices are a 24-slot pool of
 *     phase-driven oscillators with exponential envelopes — same model
 *     as the Swift engine, just translated.
 *   - Public state lives in @Volatile EngineParams. The UI thread
 *     mutates it freely; the audio thread reads a copy at the top of
 *     each render block (cheap, no allocation thanks to value-type
 *     semantics around primitive fields).
 *   - `transportEpoch` is bumped from the UI to force a scheduler
 *     reset (e.g. when toggling click-on-offbeats while running).
 */
class MetronomeEngine {

    // ---------- Public parameter surface (UI thread writes, audio thread reads) ----------

    @Volatile var bpm: Double = 120.0
    @Volatile var beatsPerCycle: Int = 4
    @Volatile var accents: List<BeatAccent> = List(4) {
        if (it == 0) BeatAccent.ACCENT else BeatAccent.NORMAL
    }
    @Volatile var masterVolume: Double = 0.9

    @Volatile var swing: Double = 0.0           // 0..0.6
    @Volatile var clickOnOffbeats: Boolean = false

    // Per-role waveforms.
    @Volatile var accentWaveform: ClickWaveform = ClickWaveform.SINE
    @Volatile var beatWaveform:   ClickWaveform = ClickWaveform.SINE
    @Volatile var subdivisionWaveform: ClickWaveform = ClickWaveform.TRIANGLE
    @Volatile var tripletWaveform:     ClickWaveform = ClickWaveform.TRIANGLE

    // Subdivision step-sequencer grids. Index 0 of each beat is the main
    // beat's slot and is silent here.
    @Volatile var subdivisionGrid: List<Boolean> = List(16) { false }
    @Volatile var tripletGrid:     List<Boolean> = List(12) { false }
    @Volatile var subdivisionLevel: Double = 0.7
    @Volatile var tripletLevel:     Double = 0.7

    // Quiet count: play N bars, then mute M bars, repeat.
    @Volatile var quietEnabled: Boolean = false
    @Volatile var quietPlayBars: Int = 4
    @Volatile var quietMuteBars: Int = 4

    // Whether the metronome click is scheduled. The engine may still run
    // (for the reference tone) when this is false.
    @Volatile var metronomeOn: Boolean = true

    // Reference tone generator.
    @Volatile var toneEnabled: Boolean = false
    @Volatile var toneFrequency: Double = 440.0
    @Volatile var toneVolume: Double = 0.3

    /** Bump to force a scheduler reset on the next render block. */
    @Volatile var transportEpoch: Int = 0

    // ---------- Read-only metrics (audio thread writes, UI thread reads) ----------

    @Volatile var isRunning: Boolean = false
        private set
    @Volatile var currentBeatIndex: Int = -1
        private set
    @Volatile var currentMeasure: Int = 0
        private set
    @Volatile var beatTick: Long = 0
        private set

    // ---------- Internals ----------

    private val sampleRate = 48_000
    private val chunkFrames = 1024
    private var track: AudioTrack? = null
    private var renderScope: CoroutineScope? = null
    private var renderJob: Job? = null

    // Audio-thread-only scheduler state.
    private var sampleClock: Long = 0
    private var mainBeatCounter: Int = 0
    private var nextMainFrame: Double = 0.0
    private var nextSubFrame: Double = 0.0
    private var subdivisionCounter: Int = 0
    private var nextTripletFrame: Double = 0.0
    private var tripletCounter: Int = 0
    private var lastEpoch: Int = -1
    private var tonePhase: Float = 0f
    private var rng: Long = 0x9E3779B9L

    // 24-voice pool, allocated up front (audio thread never allocates).
    private class Voice {
        var active = false
        var phase: Float = 0f          // 0..2π
        var phaseInc: Float = 0f
        var env: Float = 0f
        var decay: Float = 0f
        var waveform: Int = 0
    }
    private val voices = Array(24) { Voice() }

    fun start() {
        if (isRunning) return
        sampleClock = 0
        mainBeatCounter = 0
        nextMainFrame = 0.0
        nextSubFrame = 0.0
        subdivisionCounter = 0
        nextTripletFrame = 0.0
        tripletCounter = 0
        currentBeatIndex = -1
        currentMeasure = 0
        beatTick = 0
        lastEpoch = -1
        tonePhase = 0f
        for (v in voices) v.active = false

        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT
        )
        val bufSize = maxOf(minBuf, chunkFrames * 4 * Float.SIZE_BYTES)

        val t = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .build()
            )
            .setBufferSizeInBytes(bufSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
        track = t
        t.play()

        isRunning = true
        renderScope = CoroutineScope(Dispatchers.Default)
        renderJob = renderScope!!.launch { renderLoop(t) }
    }

    fun stop() {
        if (!isRunning) return
        isRunning = false
        renderJob?.cancel()
        renderScope?.cancel()
        try { track?.pause(); track?.flush(); track?.stop(); track?.release() } catch (_: Throwable) {}
        track = null
        currentBeatIndex = -1
    }

    fun toggle() { if (isRunning) stop() else start() }

    /** Returns true if any output source needs to be running. */
    fun needsOutput(): Boolean = metronomeOn || toneEnabled

    /** Convenience for the model: keep AudioTrack alive iff something needs it. */
    fun syncTransport() {
        if (needsOutput()) start() else stop()
    }

    private suspend fun renderLoop(t: AudioTrack) {
        val out = FloatArray(chunkFrames)
        while (renderScope?.isActive == true && isRunning) {
            // Snapshot per-block — readers see a consistent set of values.
            val pBpm = bpm
            val pBeats = beatsPerCycle.coerceAtLeast(1)
            val pAccents = accents
            val pMasterVol = masterVolume.toFloat()
            val pSwing = swing
            val pSubGrid = subdivisionGrid
            val pTripGrid = tripletGrid
            val pSubLevel = subdivisionLevel.toFloat()
            val pTripLevel = tripletLevel.toFloat()
            val pSubWave = subdivisionWaveform
            val pTripWave = tripletWaveform
            val pAccentWave = accentWaveform
            val pBeatWave = beatWaveform
            val pQuietOn = quietEnabled
            val pQuietPlay = quietPlayBars
            val pQuietMute = quietMuteBars
            val pMetOn = metronomeOn
            val pToneOn = toneEnabled
            val pToneFreq = toneFrequency.toFloat()
            val pToneVol = toneVolume.toFloat()
            val pEpoch = transportEpoch
            val pOffbeat = clickOnOffbeats

            val framesPerBeat = (sampleRate * 60.0 / pBpm.coerceAtLeast(1.0))
            val quietCycle = (pQuietPlay + pQuietMute).coerceAtLeast(1)

            // Lock-free transport (re)start.
            if (pEpoch != lastEpoch) {
                lastEpoch = pEpoch
                val offset = if (pOffbeat) framesPerBeat / 2 else 0.0
                mainBeatCounter = 0
                nextMainFrame = sampleClock + offset
                nextSubFrame = sampleClock + offset
                subdivisionCounter = 0
                nextTripletFrame = sampleClock + offset
                tripletCounter = 0
                for (v in voices) v.active = false
                currentMeasure = 0
            }

            // Render one chunk frame-by-frame.
            for (frame in 0 until chunkFrames) {
                val now = (sampleClock + frame).toDouble()

                val measure = mainBeatCounter / pBeats
                val muted = pQuietOn && (measure % quietCycle) >= pQuietPlay

                // --- Main beat scheduler ---
                if (pMetOn && now >= nextMainFrame) {
                    val idx = mainBeatCounter % pBeats
                    val state = pAccents.getOrElse(idx) { BeatAccent.NORMAL }
                    if (!muted) {
                        when (state) {
                            BeatAccent.ACCENT -> trigger(
                                frequency = 2_000f, amplitude = 1.0f,
                                lengthSec = 0.055f, waveform = pAccentWave.raw
                            )
                            BeatAccent.NORMAL -> trigger(
                                frequency = 1_000f, amplitude = 0.6f,
                                lengthSec = 0.045f, waveform = pBeatWave.raw
                            )
                            BeatAccent.MUTED -> {} // no-op
                        }
                    }
                    currentBeatIndex = idx
                    currentMeasure = measure
                    beatTick++
                    mainBeatCounter++
                    nextMainFrame += framesPerBeat
                }

                // --- 16th-note subdivision grid (4 cells per beat) ---
                val subFrames = framesPerBeat / 4.0
                if (pMetOn && now >= nextSubFrame) {
                    val subBeat = (subdivisionCounter / 4) % pBeats
                    val subPos = subdivisionCounter % 4
                    val gridIdx = subBeat * 4 + subPos
                    if (subPos != 0 &&
                        gridIdx < pSubGrid.size &&
                        pSubGrid[gridIdx] &&
                        !muted
                    ) {
                        val freq = if (subPos == 2) 1_300f else 1_600f
                        val baseAmp = if (subPos == 2) 0.45f else 0.35f
                        val amp = baseAmp * pSubLevel
                        if (amp > 0.001f) {
                            trigger(freq, amp, 0.025f, pSubWave.raw)
                        }
                    }
                    // Subdivision swing: alternate the inter-cell interval.
                    val parity = subdivisionCounter % 2
                    val interval = if (parity == 0)
                        subFrames * (1.0 + pSwing)
                    else
                        subFrames * (1.0 - pSwing)
                    subdivisionCounter++
                    nextSubFrame += interval
                }

                // --- Triplet grid (3 cells per beat) ---
                val tripFrames = framesPerBeat / 3.0
                if (pMetOn && now >= nextTripletFrame) {
                    val tBeat = (tripletCounter / 3) % pBeats
                    val tPos = tripletCounter % 3
                    val gIdx = tBeat * 3 + tPos
                    if (tPos != 0 &&
                        gIdx < pTripGrid.size &&
                        pTripGrid[gIdx] &&
                        !muted
                    ) {
                        val amp = 0.4f * pTripLevel
                        if (amp > 0.001f) {
                            trigger(1_500f, amp, 0.025f, pTripWave.raw)
                        }
                    }
                    tripletCounter++
                    nextTripletFrame += tripFrames
                }

                // --- Mix active voices ---
                var sample = 0f
                for (v in voices) {
                    if (!v.active) continue
                    sample += oscillator(v) * v.env
                    v.phase += v.phaseInc
                    if (v.phase > TWO_PI) v.phase -= TWO_PI
                    v.env *= v.decay
                    if (v.env < 0.0005f) v.active = false
                }
                sample *= pMasterVol

                // --- Reference tone ---
                if (pToneOn) {
                    val toneInc = (TWO_PI * pToneFreq.coerceAtLeast(1f) / sampleRate)
                    sample += sin(tonePhase.toDouble()).toFloat() * pToneVol
                    tonePhase += toneInc
                    if (tonePhase > TWO_PI) tonePhase -= TWO_PI
                }

                if (sample > 1f) sample = 1f else if (sample < -1f) sample = -1f
                out[frame] = sample
            }

            val written = t.write(out, 0, chunkFrames, AudioTrack.WRITE_BLOCKING)
            if (written <= 0) break
            sampleClock += chunkFrames.toLong()
        }
    }

    private fun oscillator(v: Voice): Float = when (v.waveform) {
        1 -> { // triangle ("wood")
            val t = v.phase / TWO_PI
            4f * abs(t - 0.5f) - 1f
        }
        2 -> if (v.phase < PI.toFloat()) 0.7f else -0.7f  // square ("beep")
        3 -> {  // filtered noise ("click")
            rng = rng * 1_664_525L + 1_013_904_223L
            ((rng ushr 8).toFloat() / (1 shl 24).toFloat()) * 2f - 1f
        }
        else -> sin(v.phase.toDouble()).toFloat()        // sine
    }

    private fun trigger(frequency: Float, amplitude: Float, lengthSec: Float, waveform: Int) {
        // Find a free voice; if none, steal the quietest.
        var slot = -1
        for (i in voices.indices) {
            if (!voices[i].active) { slot = i; break }
        }
        if (slot == -1) {
            var minEnv = Float.MAX_VALUE
            for (i in voices.indices) {
                if (voices[i].env < minEnv) { minEnv = voices[i].env; slot = i }
            }
        }
        if (slot < 0) return

        val sr = sampleRate.toFloat()
        val totalSamples = maxOf(lengthSec * sr, 1f)
        val v = voices[slot]
        v.active = true
        v.phase = 0f
        v.phaseInc = (TWO_PI * frequency) / sr
        v.env = amplitude
        v.waveform = waveform
        v.decay = (0.0005f / maxOf(amplitude, 0.0005f)).pow(1f / totalSamples)
    }

    companion object {
        private const val TWO_PI = (2.0 * PI).toFloat()
    }
}
