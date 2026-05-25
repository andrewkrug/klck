package com.klck.metronome.audio

/**
 * Simple tap-tempo helper. Records the timestamps of recent taps and
 * returns the rolling average BPM derived from the inter-tap intervals.
 *
 * - Window of 4 taps (3 intervals) — short enough to respond to a fresh
 *   tempo, long enough to smooth out one twitchy tap.
 * - Stale taps older than 2 s are discarded on the next tap (treating
 *   them as the start of a new tempo measurement, not a continuation).
 */
class TapTempo(private val maxSamples: Int = 4, private val staleAfterMs: Long = 2_000) {

    private val timestamps = ArrayDeque<Long>()

    /** Records a tap and returns the new BPM estimate, or null if there
     *  aren't enough taps yet (need at least 2). */
    fun tap(nowMs: Long = System.currentTimeMillis()): Double? {
        // Drop stale taps (pretend the user is starting fresh).
        val last = timestamps.lastOrNull()
        if (last != null && nowMs - last > staleAfterMs) {
            timestamps.clear()
        }
        timestamps.addLast(nowMs)
        while (timestamps.size > maxSamples) timestamps.removeFirst()

        if (timestamps.size < 2) return null
        val first = timestamps.first()
        val intervals = timestamps.size - 1
        val avgMs = (nowMs - first).toDouble() / intervals
        if (avgMs <= 0) return null
        return (60_000.0 / avgMs).coerceIn(30.0, 300.0)
    }

    fun reset() { timestamps.clear() }
}
