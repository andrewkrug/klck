package com.klck.metronome.model

import java.util.UUID

/** A fully recallable metronome configuration. Mirrors Sources/Klck/Model/Preset.swift. */
data class Preset(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val bpm: Double,
    val beatsPerCycle: Int,
    val accents: List<Int>,
    val layers: List<SubLayer>,
    val masterVolume: Double,
    val swing: Double = 0.0,
    val accentWaveform: ClickWaveform = ClickWaveform.SINE,
    val beatWaveform: ClickWaveform = ClickWaveform.SINE,
)
