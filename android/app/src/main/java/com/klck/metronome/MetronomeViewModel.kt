package com.klck.metronome

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.klck.metronome.audio.MetronomeEngine
import com.klck.metronome.audio.PracticeDriver
import com.klck.metronome.audio.TapTempo
import com.klck.metronome.audio.Tuner
import com.klck.metronome.model.BeatAccent
import com.klck.metronome.model.ClickWaveform
import com.klck.metronome.model.Preset
import com.klck.metronome.model.Setlist
import com.klck.metronome.model.SubLayer
import com.klck.metronome.storage.PresetStore
import com.klck.metronome.storage.SettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Bridges the audio-thread-friendly [MetronomeEngine] (volatile state) into
 * Compose-friendly [StateFlow]s. UI reads StateFlows; ViewModel methods
 * write through to the engine and re-publish to the flow.
 *
 * Also owns the [PracticeDriver] (tempo trainer + practice timer), the
 * [TapTempo] helper, and the on-disk persistence stores.
 */
class MetronomeViewModel(app: Application) : AndroidViewModel(app) {

    private val engine = MetronomeEngine()
    private val tapTempo = TapTempo()
    private val driver = PracticeDriver(
        engine = engine,
        scope = viewModelScope,
        onSetBpm = { setBpm(it) },
        onStop = { stopTransport() },
    )
    private val presetStore = PresetStore(app)
    private val settingsStore = SettingsStore(app)
    val tuner = Tuner()

    // ----- Core -----
    private val _bpm = MutableStateFlow(engine.bpm)
    val bpm: StateFlow<Double> = _bpm.asStateFlow()

    private val _beatsPerCycle = MutableStateFlow(engine.beatsPerCycle)
    val beatsPerCycle: StateFlow<Int> = _beatsPerCycle.asStateFlow()

    private val _accents = MutableStateFlow(engine.accents)
    val accents: StateFlow<List<BeatAccent>> = _accents.asStateFlow()

    private val _masterVolume = MutableStateFlow(engine.masterVolume)
    val masterVolume: StateFlow<Double> = _masterVolume.asStateFlow()

    // ----- Feel -----
    private val _swing = MutableStateFlow(engine.swing)
    val swing: StateFlow<Double> = _swing.asStateFlow()

    private val _clickOnOffbeats = MutableStateFlow(engine.clickOnOffbeats)
    val clickOnOffbeats: StateFlow<Boolean> = _clickOnOffbeats.asStateFlow()

    // ----- Subdivisions -----
    private val _subdivisionGrid = MutableStateFlow(engine.subdivisionGrid)
    val subdivisionGrid: StateFlow<List<Boolean>> = _subdivisionGrid.asStateFlow()

    private val _tripletGrid = MutableStateFlow(engine.tripletGrid)
    val tripletGrid: StateFlow<List<Boolean>> = _tripletGrid.asStateFlow()

    private val _subdivisionLevel = MutableStateFlow(engine.subdivisionLevel)
    val subdivisionLevel: StateFlow<Double> = _subdivisionLevel.asStateFlow()

    private val _tripletLevel = MutableStateFlow(engine.tripletLevel)
    val tripletLevel: StateFlow<Double> = _tripletLevel.asStateFlow()

    // ----- Sounds -----
    private val _accentWaveform = MutableStateFlow(engine.accentWaveform)
    val accentWaveform: StateFlow<ClickWaveform> = _accentWaveform.asStateFlow()

    private val _beatWaveform = MutableStateFlow(engine.beatWaveform)
    val beatWaveform: StateFlow<ClickWaveform> = _beatWaveform.asStateFlow()

    private val _subdivisionWaveform = MutableStateFlow(engine.subdivisionWaveform)
    val subdivisionWaveform: StateFlow<ClickWaveform> = _subdivisionWaveform.asStateFlow()

    private val _tripletWaveform = MutableStateFlow(engine.tripletWaveform)
    val tripletWaveform: StateFlow<ClickWaveform> = _tripletWaveform.asStateFlow()

    // ----- Practice -----
    private val _quietEnabled = MutableStateFlow(engine.quietEnabled)
    val quietEnabled: StateFlow<Boolean> = _quietEnabled.asStateFlow()

    private val _quietPlayBars = MutableStateFlow(engine.quietPlayBars)
    val quietPlayBars: StateFlow<Int> = _quietPlayBars.asStateFlow()

    private val _quietMuteBars = MutableStateFlow(engine.quietMuteBars)
    val quietMuteBars: StateFlow<Int> = _quietMuteBars.asStateFlow()

    val trainerEnabled = driver.trainerEnabled
    val timerEnabled = driver.timerEnabled
    val timerRemainingSec = driver.timerRemainingSec

    // ----- Visual -----
    private val _flashEnabled = MutableStateFlow(false)
    val flashEnabled: StateFlow<Boolean> = _flashEnabled.asStateFlow()

    // ----- Reference tone -----
    private val _toneEnabled = MutableStateFlow(engine.toneEnabled)
    val toneEnabled: StateFlow<Boolean> = _toneEnabled.asStateFlow()

    private val _toneFrequency = MutableStateFlow(engine.toneFrequency)
    val toneFrequency: StateFlow<Double> = _toneFrequency.asStateFlow()

    private val _toneVolume = MutableStateFlow(engine.toneVolume)
    val toneVolume: StateFlow<Double> = _toneVolume.asStateFlow()

    // ----- Transport / metrics -----
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    private val _activeBeat = MutableStateFlow(-1)
    val activeBeat: StateFlow<Int> = _activeBeat.asStateFlow()

    private val _measureIndex = MutableStateFlow(0)
    val measureIndex: StateFlow<Int> = _measureIndex.asStateFlow()

    private val _beatPulse = MutableStateFlow(0L)
    val beatPulse: StateFlow<Long> = _beatPulse.asStateFlow()

    // ----- Storage-backed -----
    private val _presets = MutableStateFlow<List<Preset>>(emptyList())
    val presets: StateFlow<List<Preset>> = _presets.asStateFlow()

    private val _setlists = MutableStateFlow<List<Setlist>>(emptyList())
    val setlists: StateFlow<List<Setlist>> = _setlists.asStateFlow()

    init {
        // Background metrics poll.
        viewModelScope.launch {
            var lastTick = -1L
            while (true) {
                val running = engine.isRunning && engine.metronomeOn
                _isRunning.value = running
                _activeBeat.value = if (running) engine.currentBeatIndex else -1
                _measureIndex.value = engine.currentMeasure
                val tick = engine.beatTick
                if (tick != lastTick) {
                    lastTick = tick
                    _beatPulse.value = tick
                }
                delay(16)
            }
        }
        // Load persistence off-thread.
        viewModelScope.launch {
            val (loadedPresets, loadedSetlists, lastSession) = withContext(Dispatchers.IO) {
                Triple(
                    presetStore.loadPresets(),
                    presetStore.loadSetlists(),
                    settingsStore.load(),
                )
            }
            _presets.value = loadedPresets
            _setlists.value = loadedSetlists
            lastSession?.let { applyPresetToState(it) }
        }
    }

    // ----- Mutations -----

    fun setBpm(v: Double) {
        val c = v.coerceIn(30.0, 300.0)
        _bpm.value = c; engine.bpm = c; persistSettingsDebounced()
    }

    fun setBeatsPerCycle(n: Int) {
        val c = n.coerceIn(1, 16)
        _beatsPerCycle.value = c
        val cur = _accents.value
        val resized = (0 until c).map { i ->
            cur.getOrElse(i) { if (i == 0) BeatAccent.ACCENT else BeatAccent.NORMAL }
        }
        _accents.value = resized
        val sub = MutableList(c * 4) { i -> _subdivisionGrid.value.getOrElse(i) { false } }
        val trip = MutableList(c * 3) { i -> _tripletGrid.value.getOrElse(i) { false } }
        _subdivisionGrid.value = sub
        _tripletGrid.value = trip
        engine.beatsPerCycle = c
        engine.accents = resized
        engine.subdivisionGrid = sub
        engine.tripletGrid = trip
        persistSettingsDebounced()
    }

    fun cycleAccent(beatIndex: Int) {
        val cur = _accents.value.toMutableList()
        if (beatIndex !in cur.indices) return
        cur[beatIndex] = cur[beatIndex].next()
        _accents.value = cur; engine.accents = cur; persistSettingsDebounced()
    }

    fun toggleSubdivision(cellIndex: Int) {
        val cur = _subdivisionGrid.value.toMutableList()
        if (cellIndex !in cur.indices) return
        cur[cellIndex] = !cur[cellIndex]
        _subdivisionGrid.value = cur; engine.subdivisionGrid = cur; persistSettingsDebounced()
    }

    fun toggleTriplet(cellIndex: Int) {
        val cur = _tripletGrid.value.toMutableList()
        if (cellIndex !in cur.indices) return
        cur[cellIndex] = !cur[cellIndex]
        _tripletGrid.value = cur; engine.tripletGrid = cur; persistSettingsDebounced()
    }

    fun setSubdivisionLevel(v: Double) {
        val c = v.coerceIn(0.0, 1.0); _subdivisionLevel.value = c; engine.subdivisionLevel = c; persistSettingsDebounced()
    }
    fun setTripletLevel(v: Double) {
        val c = v.coerceIn(0.0, 1.0); _tripletLevel.value = c; engine.tripletLevel = c; persistSettingsDebounced()
    }
    fun setMasterVolume(v: Double) {
        val c = v.coerceIn(0.0, 1.0); _masterVolume.value = c; engine.masterVolume = c; persistSettingsDebounced()
    }
    fun setSwing(v: Double) {
        val c = v.coerceIn(0.0, 0.6); _swing.value = c; engine.swing = c; persistSettingsDebounced()
    }
    fun setClickOnOffbeats(on: Boolean) {
        _clickOnOffbeats.value = on; engine.clickOnOffbeats = on
        if (engine.isRunning) engine.transportEpoch = engine.transportEpoch + 1
        persistSettingsDebounced()
    }

    fun setAccentWaveform(w: ClickWaveform)        { _accentWaveform.value = w; engine.accentWaveform = w; persistSettingsDebounced() }
    fun setBeatWaveform(w: ClickWaveform)          { _beatWaveform.value = w; engine.beatWaveform = w; persistSettingsDebounced() }
    fun setSubdivisionWaveform(w: ClickWaveform)   { _subdivisionWaveform.value = w; engine.subdivisionWaveform = w; persistSettingsDebounced() }
    fun setTripletWaveform(w: ClickWaveform)       { _tripletWaveform.value = w; engine.tripletWaveform = w; persistSettingsDebounced() }

    fun setQuietEnabled(on: Boolean) { _quietEnabled.value = on; engine.quietEnabled = on; persistSettingsDebounced() }
    fun setQuietPlayBars(n: Int)     { val c = n.coerceIn(1, 32); _quietPlayBars.value = c; engine.quietPlayBars = c; persistSettingsDebounced() }
    fun setQuietMuteBars(n: Int)     { val c = n.coerceIn(1, 32); _quietMuteBars.value = c; engine.quietMuteBars = c; persistSettingsDebounced() }

    // Tempo trainer.
    fun setTrainerEnabled(on: Boolean) = driver.setTrainerEnabled(on)
    fun setTrainerStart(v: Double)  { driver.trainerStartBPM = v.coerceIn(30.0, 300.0) }
    fun setTrainerTarget(v: Double) { driver.trainerTargetBPM = v.coerceIn(30.0, 300.0) }
    fun setTrainerStep(v: Double)   { driver.trainerStepBPM = v.coerceIn(1.0, 30.0) }
    fun setTrainerEveryBars(n: Int) { driver.trainerEveryBars = n.coerceIn(1, 32) }

    // Practice timer.
    fun setTimerEnabled(on: Boolean) = driver.setTimerEnabled(on)
    fun setTimerMinutes(n: Int)      { driver.timerMinutes = n.coerceIn(1, 240) }

    fun setFlashEnabled(on: Boolean) { _flashEnabled.value = on; persistSettingsDebounced() }

    // Reference tone.
    fun setToneEnabled(on: Boolean) {
        _toneEnabled.value = on; engine.toneEnabled = on; engine.syncTransport(); persistSettingsDebounced()
    }
    fun setToneFrequency(hz: Double) {
        val c = hz.coerceIn(20.0, 8_000.0); _toneFrequency.value = c; engine.toneFrequency = c
    }
    fun setToneVolume(v: Double) {
        val c = v.coerceIn(0.0, 1.0); _toneVolume.value = c; engine.toneVolume = c
    }
    fun stepToneSemitones(semis: Int) {
        val factor = Math.pow(2.0, semis / 12.0)
        setToneFrequency(_toneFrequency.value * factor)
    }
    fun setToneA440() { setToneFrequency(440.0) }

    // Transport.
    fun toggleRun() {
        engine.metronomeOn = !engine.metronomeOn
        engine.syncTransport()
        if (engine.isRunning) engine.transportEpoch = engine.transportEpoch + 1
    }
    fun stopTransport() {
        engine.metronomeOn = false
        engine.syncTransport()
    }

    fun tap() { tapTempo.tap()?.let { setBpm(it) } }

    // ----- Presets / Setlists -----

    /** Save the current state as a new preset with [name]. */
    fun savePreset(name: String) {
        val p = snapshotCurrentAsPreset(name)
        val updated = _presets.value + p
        _presets.value = updated
        persistPresets(updated)
    }

    fun deletePreset(id: java.util.UUID) {
        val updated = _presets.value.filterNot { it.id == id }
        _presets.value = updated
        persistPresets(updated)
    }

    fun loadPreset(preset: Preset) {
        applyPresetToState(preset)
        persistSettingsDebounced()
    }

    fun saveSetlist(setlist: Setlist) {
        val updated = _setlists.value.filter { it.id != setlist.id } + setlist
        _setlists.value = updated
        persistSetlists(updated)
    }

    fun deleteSetlist(id: java.util.UUID) {
        val updated = _setlists.value.filterNot { it.id == id }
        _setlists.value = updated
        persistSetlists(updated)
    }

    private fun applyPresetToState(p: Preset) {
        setBpm(p.bpm)
        setBeatsPerCycle(p.beatsPerCycle)
        val accents = p.accents.map { BeatAccent.fromRaw(it) }
        _accents.value = accents; engine.accents = accents
        setMasterVolume(p.masterVolume)
        setSwing(p.swing)
        setAccentWaveform(p.accentWaveform)
        setBeatWaveform(p.beatWaveform)
        // Android-extended fields (empty for older Swift presets).
        if (p.subdivisionGrid.isNotEmpty()) {
            _subdivisionGrid.value = p.subdivisionGrid; engine.subdivisionGrid = p.subdivisionGrid
        }
        if (p.tripletGrid.isNotEmpty()) {
            _tripletGrid.value = p.tripletGrid; engine.tripletGrid = p.tripletGrid
        }
        setSubdivisionWaveform(p.subdivisionWaveform)
        setTripletWaveform(p.tripletWaveform)
        setSubdivisionLevel(p.subdivisionLevel)
        setTripletLevel(p.tripletLevel)
    }

    private fun snapshotCurrentAsPreset(name: String): Preset = Preset(
        name = name,
        bpm = _bpm.value,
        beatsPerCycle = _beatsPerCycle.value,
        accents = _accents.value.map { it.raw },
        layers = SubLayer.defaults,
        masterVolume = _masterVolume.value,
        swing = _swing.value,
        accentWaveform = _accentWaveform.value,
        beatWaveform = _beatWaveform.value,
        subdivisionGrid = _subdivisionGrid.value,
        tripletGrid = _tripletGrid.value,
        subdivisionWaveform = _subdivisionWaveform.value,
        tripletWaveform = _tripletWaveform.value,
        subdivisionLevel = _subdivisionLevel.value,
        tripletLevel = _tripletLevel.value,
    )

    private fun persistPresets(list: List<Preset>) {
        viewModelScope.launch(Dispatchers.IO) { presetStore.savePresets(list) }
    }

    private fun persistSetlists(list: List<Setlist>) {
        viewModelScope.launch(Dispatchers.IO) { presetStore.saveSetlists(list) }
    }

    private var settingsSaveJob: kotlinx.coroutines.Job? = null
    /** Debounce session-state writes so we're not hitting disk on every slider drag. */
    private fun persistSettingsDebounced() {
        settingsSaveJob?.cancel()
        settingsSaveJob = viewModelScope.launch(Dispatchers.IO) {
            delay(400)
            settingsStore.save(snapshotCurrentAsPreset("Last session"))
        }
    }

    override fun onCleared() {
        engine.stop()
        super.onCleared()
    }
}
