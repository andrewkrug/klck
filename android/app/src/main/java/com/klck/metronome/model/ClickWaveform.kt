package com.klck.metronome.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/** Click timbre — mirrors Sources/Klck/Audio/AudioEngine.swift::ClickWaveform. */
@Serializable(with = ClickWaveformSerializer::class)
enum class ClickWaveform(val raw: Int, val label: String) {
    SINE(0, "Sine"),
    TRIANGLE(1, "Wood"),
    SQUARE(2, "Beep"),
    NOISE(3, "Click");

    companion object {
        fun fromRaw(v: Int): ClickWaveform = entries.firstOrNull { it.raw == v } ?: SINE
    }
}

/** Stores [ClickWaveform] as its raw Int so the JSON matches the Swift
 *  Codable encoding (rawValue: Int). */
object ClickWaveformSerializer : KSerializer<ClickWaveform> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ClickWaveform", PrimitiveKind.INT)
    override fun serialize(encoder: Encoder, value: ClickWaveform) =
        encoder.encodeInt(value.raw)
    override fun deserialize(decoder: Decoder): ClickWaveform =
        ClickWaveform.fromRaw(decoder.decodeInt())
}
