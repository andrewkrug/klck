package com.klck.metronome.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.klck.metronome.MetronomeViewModel
import com.klck.metronome.model.BeatAccent
import com.klck.metronome.model.ClickWaveform

@Composable
fun MetronomeScreen(vm: MetronomeViewModel) {
    val bpm by vm.bpm.collectAsStateWithLifecycle()
    val beats by vm.beatsPerCycle.collectAsStateWithLifecycle()
    val accents by vm.accents.collectAsStateWithLifecycle()
    val running by vm.isRunning.collectAsStateWithLifecycle()
    val activeBeat by vm.activeBeat.collectAsStateWithLifecycle()
    val flashEnabled by vm.flashEnabled.collectAsStateWithLifecycle()
    val beatPulse by vm.beatPulse.collectAsStateWithLifecycle()

    var showSaveDialog by remember { mutableStateOf(false) }
    if (showSaveDialog) {
        SavePresetDialog(
            currentBpm = bpm.toInt(),
            currentBeats = beats,
            onConfirm = { name ->
                vm.savePreset(name); showSaveDialog = false
            },
            onDismiss = { showSaveDialog = false },
        )
    }

    Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                LcdReadout(bpm.toInt(), running, activeBeat, beats)
                TempoControls(bpm, onChange = vm::setBpm, onTap = vm::tap)
                BeatsRow(beats, onChange = vm::setBeatsPerCycle)
                AccentGrid(accents, activeBeat, running, vm::cycleAccent)
                SubdivisionGrid(
                    title = "Sixteenths (e · and · a)",
                    cellsPerBeat = 4,
                    beats = beats,
                    grid = vm.subdivisionGrid.collectAsStateWithLifecycle().value,
                    onToggle = vm::toggleSubdivision,
                    level = vm.subdivisionLevel.collectAsStateWithLifecycle().value,
                    onLevelChange = vm::setSubdivisionLevel,
                )
                SubdivisionGrid(
                    title = "Triplets (tri · ple · let)",
                    cellsPerBeat = 3,
                    beats = beats,
                    grid = vm.tripletGrid.collectAsStateWithLifecycle().value,
                    onToggle = vm::toggleTriplet,
                    level = vm.tripletLevel.collectAsStateWithLifecycle().value,
                    onLevelChange = vm::setTripletLevel,
                )
                Section("Master") {
                    LabeledSlider("Volume",
                        vm.masterVolume.collectAsStateWithLifecycle().value,
                        0.0..1.0, vm::setMasterVolume,
                    )
                }
                SoundsSection(vm)
                FeelSection(vm)
                QuietCountSection(vm)
                TempoTrainerSection(vm)
                PracticeTimerSection(vm)
                ToneSection(vm)
                Spacer(Modifier.height(72.dp))  // breathing room under sticky button
            }

        // Sticky bottom bar: SAVE + START/STOP.
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Button(
                onClick = { showSaveDialog = true },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.primary,
                ),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.height(54.dp),
            ) { Text("SAVE", fontSize = 14.sp, fontWeight = FontWeight.Bold) }
            Button(
                onClick = { vm.toggleRun() },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (running) MaterialTheme.colorScheme.secondary
                                      else MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.weight(1f).height(54.dp),
            ) {
                Text(if (running) "STOP" else "START",
                    fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }

        // Screen flash overlay.
        if (flashEnabled && running) BeatFlash(beatPulse, activeBeat)
    }
}

@Composable
private fun SavePresetDialog(
    currentBpm: Int,
    currentBeats: Int,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf("Preset ${currentBpm}-${currentBeats}") }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("Save preset", color = MaterialTheme.colorScheme.primary) },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                label = { Text("Name") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    cursorColor = MaterialTheme.colorScheme.primary,
                    focusedLabelColor = MaterialTheme.colorScheme.primary,
                ),
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(name.ifBlank { "Untitled" }) }) {
                Text("SAVE", color = MaterialTheme.colorScheme.primary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("CANCEL", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
    )
}

@Composable
private fun LcdReadout(bpm: Int, running: Boolean, activeBeat: Int, beats: Int) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth().height(140.dp),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = bpm.toString(),
                    color = MaterialTheme.colorScheme.primary,
                    fontSize = 80.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                )
                Text(
                    text = if (running && activeBeat >= 0) "BEAT ${activeBeat + 1} / $beats" else "BPM",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
    }
}

@Composable
private fun TempoControls(bpm: Double, onChange: (Double) -> Unit, onTap: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Slider(
            value = bpm.toFloat(),
            onValueChange = { onChange(it.toDouble()) },
            valueRange = 30f..300f,
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Stepper("-1", onClick = { onChange(bpm - 1) })
            Stepper("+1", onClick = { onChange(bpm + 1) })
            Stepper("-5", onClick = { onChange(bpm - 5) })
            Stepper("+5", onClick = { onChange(bpm + 5) })
            Stepper("TAP", onClick = onTap, wide = true)
        }
    }
}

@Composable
private fun BeatsRow(beats: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Beats", color = MaterialTheme.colorScheme.onBackground, fontSize = 13.sp)
        Stepper("-", onClick = { onChange(beats - 1) })
        Text(beats.toString(),
            color = MaterialTheme.colorScheme.primary,
            fontSize = 22.sp, fontFamily = FontFamily.Monospace)
        Stepper("+", onClick = { onChange(beats + 1) })
    }
}

@Composable
private fun AccentGrid(
    accents: List<BeatAccent>,
    activeBeat: Int,
    running: Boolean,
    onTap: (Int) -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        accents.forEachIndexed { i, a ->
            val base = when (a) {
                BeatAccent.ACCENT -> MaterialTheme.colorScheme.primary
                BeatAccent.NORMAL -> MaterialTheme.colorScheme.onSurfaceVariant
                BeatAccent.MUTED  -> Color(0xFF2A2C30)
            }
            val color = if (i == activeBeat && running) MaterialTheme.colorScheme.secondary else base
            Box(
                modifier = Modifier
                    .padding(horizontal = 4.dp)
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(color)
                    .clickable { onTap(i) },
            )
        }
    }
}

@Composable
private fun SubdivisionGrid(
    title: String,
    cellsPerBeat: Int,
    beats: Int,
    grid: List<Boolean>,
    onToggle: (Int) -> Unit,
    level: Double,
    onLevelChange: (Double) -> Unit,
) {
    Section(title) {
        // One row of cellsPerBeat * beats squares; index 0 of each beat is
        // the main-beat slot (rendered greyed out + not tappable).
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            for (b in 0 until beats) {
                for (c in 0 until cellsPerBeat) {
                    val idx = b * cellsPerBeat + c
                    val isMainSlot = c == 0
                    val on = grid.getOrElse(idx) { false }
                    val color = when {
                        isMainSlot -> Color(0xFF15171B)
                        on         -> MaterialTheme.colorScheme.primary
                        else       -> Color(0xFF2A2C30)
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(28.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(color)
                            .then(
                                if (!isMainSlot) Modifier.clickable { onToggle(idx) }
                                else Modifier
                            ),
                    )
                }
                // Tiny gap between beats to make the groups visible.
                if (b < beats - 1) Spacer(Modifier.width(4.dp))
            }
        }
        Spacer(Modifier.height(6.dp))
        LabeledSlider("Level", level, 0.0..1.0, onLevelChange)
    }
}

@Composable
private fun SoundsSection(vm: MetronomeViewModel) {
    val accentW by vm.accentWaveform.collectAsStateWithLifecycle()
    val beatW by vm.beatWaveform.collectAsStateWithLifecycle()
    val subW by vm.subdivisionWaveform.collectAsStateWithLifecycle()
    val tripW by vm.tripletWaveform.collectAsStateWithLifecycle()
    Section("Sounds") {
        WaveformRow("Accent",  accentW, vm::setAccentWaveform)
        WaveformRow("Beat",    beatW,   vm::setBeatWaveform)
        WaveformRow("16ths",   subW,    vm::setSubdivisionWaveform)
        WaveformRow("Triplet", tripW,   vm::setTripletWaveform)
    }
}

@Composable
private fun WaveformRow(label: String, current: ClickWaveform, onSelect: (ClickWaveform) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 12.sp, modifier = Modifier.width(64.dp))
        WaveformDropdown(current, onSelect)
    }
}

@Composable
private fun WaveformDropdown(current: ClickWaveform, onSelect: (ClickWaveform) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Button(
            onClick = { expanded = true },
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text(current.label, fontSize = 13.sp) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ClickWaveform.entries.forEach { w ->
                DropdownMenuItem(text = { Text(w.label) }, onClick = {
                    onSelect(w); expanded = false
                })
            }
        }
    }
}

@Composable
private fun FeelSection(vm: MetronomeViewModel) {
    val swing by vm.swing.collectAsStateWithLifecycle()
    val offbeat by vm.clickOnOffbeats.collectAsStateWithLifecycle()
    val flash by vm.flashEnabled.collectAsStateWithLifecycle()
    Section("Feel") {
        LabeledSlider("Swing", swing, 0.0..0.6, vm::setSwing,
            valueLabel = "${(swing * 100).toInt()}%")
        ToggleRow("Click on offbeats", offbeat, vm::setClickOnOffbeats)
        ToggleRow("Screen flash on beat", flash, vm::setFlashEnabled)
    }
}

@Composable
private fun QuietCountSection(vm: MetronomeViewModel) {
    val on by vm.quietEnabled.collectAsStateWithLifecycle()
    val play by vm.quietPlayBars.collectAsStateWithLifecycle()
    val mute by vm.quietMuteBars.collectAsStateWithLifecycle()
    Section("Quiet Count") {
        ToggleRow("Enabled", on, vm::setQuietEnabled)
        StepperRow("Play bars", play, vm::setQuietPlayBars)
        StepperRow("Mute bars", mute, vm::setQuietMuteBars)
    }
}

@Composable
private fun TempoTrainerSection(vm: MetronomeViewModel) {
    val on by vm.trainerEnabled.collectAsStateWithLifecycle()
    Section("Tempo Trainer") {
        ToggleRow("Enabled", on, vm::setTrainerEnabled)
        Text(
            "Ramps BPM by +N every M measures until target.",
            color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp,
        )
        // Trainer settings are configured directly on the driver — the
        // engine doesn't need fine-grained StateFlows for them; defaults
        // (80→160, +4 every 4) are sensible. (UI for editing the targets
        // is part of the deferred persistence/presets work.)
    }
}

@Composable
private fun PracticeTimerSection(vm: MetronomeViewModel) {
    val on by vm.timerEnabled.collectAsStateWithLifecycle()
    val remaining by vm.timerRemainingSec.collectAsStateWithLifecycle()
    val mins = remaining / 60
    val secs = remaining % 60
    Section("Practice Timer") {
        ToggleRow("Enabled", on, vm::setTimerEnabled)
        if (on) {
            Text(
                "Stops in %d:%02d".format(mins, secs),
                color = MaterialTheme.colorScheme.primary,
                fontFamily = FontFamily.Monospace, fontSize = 16.sp,
            )
        }
    }
}

@Composable
private fun ToneSection(vm: MetronomeViewModel) {
    val on by vm.toneEnabled.collectAsStateWithLifecycle()
    val freq by vm.toneFrequency.collectAsStateWithLifecycle()
    val vol by vm.toneVolume.collectAsStateWithLifecycle()
    Section("Reference Tone") {
        ToggleRow("Play", on, vm::setToneEnabled)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("%.1f Hz".format(freq),
                color = MaterialTheme.colorScheme.primary,
                fontFamily = FontFamily.Monospace, fontSize = 16.sp,
                modifier = Modifier.width(100.dp),
            )
            Stepper("-1", onClick = { vm.stepToneSemitones(-1) })
            Stepper("+1", onClick = { vm.stepToneSemitones(1) })
            Stepper("A=440", onClick = vm::setToneA440, wide = true)
        }
        LabeledSlider("Volume", vol, 0.0..1.0, vm::setToneVolume)
    }
}

@Composable
private fun BeatFlash(beatPulse: Long, activeBeat: Int) {
    // Pulse alpha briefly each beat — brighter on the downbeat.
    var alpha by remember(beatPulse) { mutableStateOf(if (activeBeat == 0) 0.30f else 0.14f) }
    LaunchedEffect(beatPulse) { alpha = if (activeBeat == 0) 0.30f else 0.14f }
    val animated by animateFloatAsState(targetValue = 0f, label = "flash")
    val current = maxOf(alpha + animated - alpha, 0f)
    Box(modifier = Modifier
        .fillMaxSize()
        .background(MaterialTheme.colorScheme.primary.copy(alpha = current)))
}

// --- generic widgets ---

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title.uppercase(),
                color = MaterialTheme.colorScheme.primary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            content()
        }
    }
}

@Composable
private fun LabeledSlider(
    label: String,
    value: Double,
    range: ClosedFloatingPointRange<Double>,
    onChange: (Double) -> Unit,
    valueLabel: String? = null,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 12.sp, modifier = Modifier.weight(1f))
            Text(valueLabel ?: "%.0f%%".format(value * 100),
                color = MaterialTheme.colorScheme.primary, fontSize = 12.sp,
                fontFamily = FontFamily.Monospace)
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onChange(it.toDouble()) },
            valueRange = range.start.toFloat()..range.endInclusive.toFloat(),
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
            ),
        )
    }
}

@Composable
private fun ToggleRow(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp, modifier = Modifier.weight(1f))
        Switch(checked = on, onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = MaterialTheme.colorScheme.primary,
                checkedTrackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.35f),
            ))
    }
}

@Composable
private fun StepperRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp, modifier = Modifier.weight(1f))
        Stepper("-", onClick = { onChange(value - 1) })
        Text(value.toString(),
            color = MaterialTheme.colorScheme.primary,
            fontFamily = FontFamily.Monospace, fontSize = 16.sp)
        Stepper("+", onClick = { onChange(value + 1) })
    }
}

@Composable
private fun Stepper(label: String, onClick: () -> Unit, wide: Boolean = false) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(if (wide) 14.dp else 22.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
            contentColor = MaterialTheme.colorScheme.primary,
        ),
        modifier = if (wide) Modifier.height(44.dp) else Modifier.size(44.dp),
        contentPadding = PaddingValues(horizontal = if (wide) 14.dp else 0.dp),
    ) {
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}
