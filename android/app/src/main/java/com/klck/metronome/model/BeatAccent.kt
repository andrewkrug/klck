package com.klck.metronome.model

/** Per-beat state. Mirrors Sources/Klck/Model/MetronomeModel.swift::BeatAccent. */
enum class BeatAccent(val raw: Int) {
    MUTED(0),
    NORMAL(1),
    ACCENT(2);

    fun next(): BeatAccent = when (this) {
        ACCENT -> NORMAL
        NORMAL -> MUTED
        MUTED  -> ACCENT
    }

    companion object {
        fun fromRaw(v: Int): BeatAccent = entries.firstOrNull { it.raw == v } ?: NORMAL
    }
}
