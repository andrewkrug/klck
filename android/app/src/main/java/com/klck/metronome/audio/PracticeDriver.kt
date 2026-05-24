package com.klck.metronome.audio

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Off-audio-thread practice helpers. Observes the engine's beat/measure
 * tick and applies higher-level practice behaviors:
 *
 *   - **Tempo Trainer:** ramp BPM from a starting value to a target by
 *     +N every M measures. Auto-disables once the target is reached.
 *   - **Practice Timer:** count down a wall-clock duration; auto-stops
 *     the engine when it hits zero.
 *
 * Designed so the ViewModel can call `enableTrainer(...)` / `enableTimer(...)`
 * declaratively; the driver owns the tick coroutine and updates StateFlows
 * the UI observes.
 */
class PracticeDriver(
    private val engine: MetronomeEngine,
    private val scope: CoroutineScope,
    private val onSetBpm: (Double) -> Unit,
    private val onStop: () -> Unit,
) {
    // Trainer state.
    private val _trainerEnabled = MutableStateFlow(false)
    val trainerEnabled: StateFlow<Boolean> = _trainerEnabled.asStateFlow()
    var trainerStartBPM = 80.0
    var trainerTargetBPM = 160.0
    var trainerStepBPM = 4.0
    var trainerEveryBars = 4

    // Timer state.
    private val _timerEnabled = MutableStateFlow(false)
    val timerEnabled: StateFlow<Boolean> = _timerEnabled.asStateFlow()
    private val _timerRemainingSec = MutableStateFlow(0L)
    val timerRemainingSec: StateFlow<Long> = _timerRemainingSec.asStateFlow()
    var timerMinutes = 10

    private var loopJob: Job? = null

    fun setTrainerEnabled(on: Boolean) {
        _trainerEnabled.value = on
        if (on) onSetBpm(trainerStartBPM)
        ensureLoopRunning()
    }

    fun setTimerEnabled(on: Boolean) {
        _timerEnabled.value = on
        _timerRemainingSec.value = if (on) (timerMinutes * 60L) else 0L
        ensureLoopRunning()
    }

    private fun ensureLoopRunning() {
        if (loopJob?.isActive == true) return
        loopJob = scope.launch {
            var lastTrainerMeasure = -1
            var lastTickMs = System.currentTimeMillis()
            while (true) {
                delay(100)
                if (!engine.isRunning) {
                    lastTrainerMeasure = -1
                    lastTickMs = System.currentTimeMillis()
                    continue
                }

                // Trainer: bump BPM whenever the measure index has advanced
                // past the next multiple of `trainerEveryBars`.
                if (_trainerEnabled.value) {
                    val m = engine.currentMeasure
                    if (lastTrainerMeasure < 0) lastTrainerMeasure = m
                    if (m > lastTrainerMeasure && m % trainerEveryBars == 0) {
                        val next = (engine.bpm + trainerStepBPM)
                            .coerceAtMost(trainerTargetBPM)
                        onSetBpm(next)
                        if (next >= trainerTargetBPM) {
                            _trainerEnabled.value = false
                        }
                        lastTrainerMeasure = m
                    }
                }

                // Timer: decrement remaining; stop transport at zero.
                if (_timerEnabled.value) {
                    val now = System.currentTimeMillis()
                    val deltaMs = now - lastTickMs
                    lastTickMs = now
                    val remaining = (_timerRemainingSec.value * 1000 - deltaMs)
                        .coerceAtLeast(0L)
                    _timerRemainingSec.value = remaining / 1000
                    if (remaining == 0L) {
                        _timerEnabled.value = false
                        onStop()
                    }
                } else {
                    lastTickMs = System.currentTimeMillis()
                }
            }
        }
    }
}
