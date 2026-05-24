package com.klck.metronome.model

import java.util.UUID

/** One stop in a setlist. Mirrors Sources/Klck/Model/Setlist.swift::SetlistItem. */
data class SetlistItem(
    val id: UUID = UUID.randomUUID(),
    val presetID: UUID,
    val advanceAfterBars: Int = 0,   // 0 = manual
)

/** An ordered chain of presets. Mirrors Sources/Klck/Model/Setlist.swift::Setlist. */
data class Setlist(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val items: List<SetlistItem> = emptyList(),
)
