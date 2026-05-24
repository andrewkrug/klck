package com.klck.metronome.model

/** Click timbre — mirrors Sources/Klck/Audio/AudioEngine.swift::ClickWaveform. */
enum class ClickWaveform(val raw: Int, val label: String) {
    SINE(0, "Sine"),
    TRIANGLE(1, "Wood"),
    SQUARE(2, "Beep"),
    NOISE(3, "Click");

    companion object {
        fun fromRaw(v: Int): ClickWaveform = entries.firstOrNull { it.raw == v } ?: SINE
    }
}
