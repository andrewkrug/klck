package com.klck.metronome.storage

import android.content.Context
import com.klck.metronome.model.Preset
import com.klck.metronome.model.Setlist
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Reads / writes Preset and Setlist lists as JSON files inside the app's
 * private files dir. Mirrors the Swift side, which writes presets.json /
 * setlists.json under `~/Library/Application Support/Klck/`.
 *
 * Operations are synchronous (these are small files — a typical user
 * preset list is a few KB). The callers are expected to invoke from
 * background coroutines if they care about jank.
 */
class PresetStore(context: Context) {

    private val dir: File = File(context.filesDir, "Klck").apply { mkdirs() }
    private val presetsFile = File(dir, "presets.json")
    private val setlistsFile = File(dir, "setlists.json")

    // Lenient JSON so missing fields fall back to defaults — this lets us
    // evolve the Preset schema without breaking older saved files.
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = false
    }

    // ----- Presets -----

    fun loadPresets(): List<Preset> {
        if (!presetsFile.exists()) return emptyList()
        return try {
            json.decodeFromString(presetsFile.readText())
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun savePresets(presets: List<Preset>) {
        presetsFile.writeText(json.encodeToString(presets))
    }

    // ----- Setlists -----

    fun loadSetlists(): List<Setlist> {
        if (!setlistsFile.exists()) return emptyList()
        return try {
            json.decodeFromString(setlistsFile.readText())
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun saveSetlists(setlists: List<Setlist>) {
        setlistsFile.writeText(json.encodeToString(setlists))
    }
}
