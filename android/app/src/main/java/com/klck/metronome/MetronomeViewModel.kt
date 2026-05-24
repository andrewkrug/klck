package com.klck.metronome

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.klck.metronome.audio.MetronomeEngine
import com.klck.metronome.model.BeatAccent
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Bridges the [MetronomeEngine] (audio-thread-friendly @Volatile state) into
 * Compose-friendly [StateFlow]s. UI reads StateFlow; ViewModel methods write
 * through to the engine.
 */
class MetronomeViewModel : ViewModel() {

    private val engine = MetronomeEngine()

    private val _bpm = MutableStateFlow(engine.bpm)
    val bpm: StateFlow<Double> = _bpm.asStateFlow()

    private val _beatsPerCycle = MutableStateFlow(engine.beatsPerCycle)
    val beatsPerCycle: StateFlow<Int> = _beatsPerCycle.asStateFlow()

    private val _accents = MutableStateFlow(engine.accents)
    val accents: StateFlow<List<BeatAccent>> = _accents.asStateFlow()

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    private val _activeBeat = MutableStateFlow(-1)
    val activeBeat: StateFlow<Int> = _activeBeat.asStateFlow()

    init {
        // Poll the engine's currentBeatIndex while running. Cheap; updates ~60Hz.
        viewModelScope.launch {
            while (true) {
                _activeBeat.value = if (engine.isRunning) engine.currentBeatIndex else -1
                delay(16)
            }
        }
    }

    fun setBpm(v: Double) {
        val clamped = v.coerceIn(30.0, 300.0)
        _bpm.value = clamped
        engine.bpm = clamped
    }

    fun setBeatsPerCycle(n: Int) {
        val clamped = n.coerceIn(1, 16)
        _beatsPerCycle.value = clamped
        // Resize accents preserving existing values.
        val current = _accents.value
        val resized = (0 until clamped).map { i ->
            current.getOrElse(i) { if (i == 0) BeatAccent.ACCENT else BeatAccent.NORMAL }
        }
        _accents.value = resized
        engine.beatsPerCycle = clamped
        engine.accents = resized
    }

    fun cycleAccent(beatIndex: Int) {
        val current = _accents.value.toMutableList()
        if (beatIndex !in current.indices) return
        current[beatIndex] = current[beatIndex].next()
        _accents.value = current
        engine.accents = current
    }

    fun toggleRun() {
        engine.toggle()
        _isRunning.value = engine.isRunning
    }

    override fun onCleared() {
        engine.stop()
        super.onCleared()
    }
}
