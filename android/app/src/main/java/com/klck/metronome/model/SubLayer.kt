package com.klck.metronome.model

import kotlinx.serialization.Serializable
import java.util.UUID

/** A user-facing subdivision layer. Mirrors Sources/Klck/Model/SubLayer.swift. */
@Serializable
data class SubLayer(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val pulsesPerBeat: Int,
    val volume: Double,           // 0..1
    val enabled: Boolean,
    val frequency: Double,        // click pitch in Hz
    val waveform: ClickWaveform = ClickWaveform.SINE,
) {
    companion object {
        val defaults: List<SubLayer> = listOf(
            SubLayer(name = "Eighths",    pulsesPerBeat = 2, volume = 0.50, enabled = false, frequency = 1_400.0, waveform = ClickWaveform.SINE),
            SubLayer(name = "Triplets",   pulsesPerBeat = 3, volume = 0.50, enabled = false, frequency = 1_600.0, waveform = ClickWaveform.SINE),
            SubLayer(name = "Sixteenths", pulsesPerBeat = 4, volume = 0.45, enabled = false, frequency = 1_800.0, waveform = ClickWaveform.TRIANGLE),
            SubLayer(name = "Quarters",   pulsesPerBeat = 1, volume = 0.50, enabled = false, frequency = 1_200.0, waveform = ClickWaveform.SINE),
        )
    }
}
