package com.klck.metronome.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * A fully recallable metronome configuration. Mirrors
 * Sources/Klck/Model/Preset.swift.
 *
 * JSON shape is compatible with the Swift Codable encoding so a preset
 * exported on iOS could in principle be loaded here (and vice-versa).
 */
@Serializable
data class Preset(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val bpm: Double,
    val beatsPerCycle: Int,
    val accents: List<Int>,                       // 0=muted, 1=normal, 2=accent
    val layers: List<SubLayer> = emptyList(),
    val masterVolume: Double,
    val swing: Double = 0.0,
    val accentWaveform: ClickWaveform = ClickWaveform.SINE,
    val beatWaveform: ClickWaveform = ClickWaveform.SINE,
    // Fields the Android port adds (not in the Swift Codable surface yet —
    // they decode as defaults if missing).
    val subdivisionGrid: List<Boolean> = emptyList(),
    val tripletGrid: List<Boolean> = emptyList(),
    val subdivisionWaveform: ClickWaveform = ClickWaveform.TRIANGLE,
    val tripletWaveform: ClickWaveform = ClickWaveform.TRIANGLE,
    val subdivisionLevel: Double = 0.7,
    val tripletLevel: Double = 0.7,
)
