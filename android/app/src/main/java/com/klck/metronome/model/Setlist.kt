package com.klck.metronome.model

import kotlinx.serialization.Serializable
import java.util.UUID

/** One stop in a setlist. Mirrors Sources/Klck/Model/Setlist.swift::SetlistItem. */
@Serializable
data class SetlistItem(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    @Serializable(with = UuidSerializer::class)
    val presetID: UUID,
    val advanceAfterBars: Int = 0,   // 0 = manual advance
)

/** An ordered chain of presets. Mirrors Sources/Klck/Model/Setlist.swift::Setlist. */
@Serializable
data class Setlist(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val items: List<SetlistItem> = emptyList(),
)
