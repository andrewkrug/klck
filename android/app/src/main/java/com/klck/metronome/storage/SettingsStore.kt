package com.klck.metronome.storage

import android.content.Context
import com.klck.metronome.model.Preset
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Persists the last-used metronome state as a synthetic [Preset] so that
 * reopening the app picks up exactly where the user left it. Stored as a
 * single JSON file alongside presets.json.
 *
 * We piggy-back on the Preset shape (rather than inventing a parallel
 * struct) because every field a Preset captures is also app state we want
 * to restore — name is just "Last session" in this case.
 */
class SettingsStore(context: Context) {

    private val dir: File = File(context.filesDir, "Klck").apply { mkdirs() }
    private val file = File(dir, "settings.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun load(): Preset? {
        if (!file.exists()) return null
        return try { json.decodeFromString<Preset>(file.readText()) }
        catch (_: Throwable) { null }
    }

    fun save(state: Preset) {
        file.writeText(json.encodeToString(state.copy(name = "Last session")))
    }
}
