package com.klck.metronome.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import com.klck.metronome.model.BeatAccent
import com.klck.metronome.model.ClickWaveform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.min

/**
 * Sample-accurate metronome engine using AudioTrack in streaming mode.
 *
 * Architecture mirrors the Swift AVAudioSourceNode pattern in
 * Sources/Klck/Audio/AudioEngine.swift: a render loop computes the next
 * chunk of float PCM, placing one-shot click envelopes at exact sample-frame
 * positions derived from BPM. AudioTrack drains the buffer continuously.
 *
 * MVP scope: beats + accents + master volume + per-role waveform. Subdivision
 * grid, swing, quiet count, tempo trainer, and tuner ship in follow-ups.
 */
class MetronomeEngine {

    // ----- Public state (consumers update these freely; the render loop
    // re-reads them at chunk boundaries). -----

    @Volatile var bpm: Double = 120.0
    @Volatile var beatsPerCycle: Int = 4
    @Volatile var accents: List<BeatAccent> = List(4) {
        if (it == 0) BeatAccent.ACCENT else BeatAccent.NORMAL
    }
    @Volatile var masterVolume: Double = 0.9
    @Volatile var accentWaveform: ClickWaveform = ClickWaveform.SINE
    @Volatile var beatWaveform:   ClickWaveform = ClickWaveform.SINE

    @Volatile var isRunning: Boolean = false
        private set

    /** Index of the most recently scheduled beat (0-based). UI uses this to
     *  light up beat LEDs. */
    @Volatile var currentBeatIndex: Int = -1
        private set

    // ----- Internals -----

    private val sampleRate = 48_000
    private val channels = AudioFormat.CHANNEL_OUT_MONO
    private val encoding = AudioFormat.ENCODING_PCM_FLOAT
    private val chunkFrames = 1024     // ~21 ms @ 48 kHz; balance of latency vs. underrun risk

    private var track: AudioTrack? = null
    private var renderScope: CoroutineScope? = null
    private var renderJob: Job? = null

    // Position in absolute output sample frames since transport start.
    private var framesSinceStart: Long = 0
    // Index of the next beat to schedule (monotonically increasing).
    private var nextBeatIndex: Long = 0

    // Active one-shot click voices: (start frame, buffer, position).
    private data class Voice(val startFrame: Long, val data: FloatArray, var pos: Int)
    private val voices = mutableListOf<Voice>()

    fun start() {
        if (isRunning) return
        framesSinceStart = 0
        nextBeatIndex = 0
        voices.clear()
        currentBeatIndex = -1

        val minBuf = AudioTrack.getMinBufferSize(sampleRate, channels, encoding)
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
                    .setChannelMask(channels)
                    .setEncoding(encoding)
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

    private suspend fun renderLoop(t: AudioTrack) {
        val out = FloatArray(chunkFrames)
        while (renderScope?.isActive == true && isRunning) {
            // Compute the chunk's start/end frame window.
            val chunkStart = framesSinceStart
            val chunkEnd = chunkStart + chunkFrames

            // Schedule any beats that fall inside this chunk.
            val framesPerBeat = (60.0 / bpm * sampleRate).toLong().coerceAtLeast(1)
            while (true) {
                val beatFrame = nextBeatIndex * framesPerBeat
                if (beatFrame >= chunkEnd) break
                val beatInCycle = (nextBeatIndex % beatsPerCycle.toLong()).toInt()
                val accent = accents.getOrElse(beatInCycle) { BeatAccent.NORMAL }
                if (accent != BeatAccent.MUTED) {
                    val isAccent = accent == BeatAccent.ACCENT
                    val freq = if (isAccent) ClickRenderer.ACCENT_HZ else ClickRenderer.BEAT_HZ
                    val wave = if (isAccent) accentWaveform else beatWaveform
                    val amp  = (if (isAccent) 1.0 else 0.75) * masterVolume
                    val buf  = ClickRenderer.render(sampleRate, freq, wave, amp.toFloat())
                    voices.add(Voice(startFrame = beatFrame, data = buf, pos = 0))
                }
                currentBeatIndex = beatInCycle
                nextBeatIndex++
            }

            // Mix all active voices into the output buffer.
            java.util.Arrays.fill(out, 0f)
            val it = voices.iterator()
            while (it.hasNext()) {
                val v = it.next()
                val voiceStartInChunk = (v.startFrame - chunkStart).toInt()
                var destIdx = maxOf(voiceStartInChunk, 0)
                var srcIdx = v.pos + (if (voiceStartInChunk < 0) -voiceStartInChunk else 0)
                while (destIdx < chunkFrames && srcIdx < v.data.size) {
                    out[destIdx] += v.data[srcIdx]
                    destIdx++; srcIdx++
                }
                v.pos = srcIdx
                if (srcIdx >= v.data.size) it.remove()
            }

            // Write (blocks until AudioTrack has room — paces the loop).
            val written = t.write(out, 0, chunkFrames, AudioTrack.WRITE_BLOCKING)
            if (written <= 0) {
                // Track was closed; bail.
                break
            }
            framesSinceStart += chunkFrames
        }
    }

    fun toggle() { if (isRunning) stop() else start() }
}
