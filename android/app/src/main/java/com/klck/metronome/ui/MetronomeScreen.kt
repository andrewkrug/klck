package com.klck.metronome.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.klck.metronome.MetronomeViewModel
import com.klck.metronome.model.BeatAccent
import com.klck.metronome.model.ClickWaveform
import com.klck.metronome.ui.theme.ButtonGradient
import com.klck.metronome.ui.theme.DB66
import com.klck.metronome.ui.theme.LcdGradient
import com.klck.metronome.ui.theme.StartGradient

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
            onConfirm = { name -> vm.savePreset(name); showSaveDialog = false },
            onDismiss = { showSaveDialog = false },
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            BeatLightsView(accents, activeBeat, running)
            LcdReadout(bpm.toInt(), beats, running)
            TempoControls(bpm, onChange = vm::setBpm, onTap = vm::tap)
            BeatsRow(beats, onChange = vm::setBeatsPerCycle)
            AccentGrid(accents, vm::cycleAccent)
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
            LabeledPanel("Master") {
                LabeledSlider("Volume",
                    vm.masterVolume.collectAsStateWithLifecycle().value,
                    0.0..1.0, vm::setMasterVolume)
            }
            SoundsSection(vm)
            FeelSection(vm)
            QuietCountSection(vm)
            TempoTrainerSection(vm)
            PracticeTimerSection(vm)
            ToneSection(vm)
            Spacer(Modifier.height(120.dp))
        }

        // Sticky bottom bar: SAVE + START/STOP.
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            DeviceButton(
                label = "SAVE",
                onClick = { showSaveDialog = true },
                modifier = Modifier.height(56.dp),
                fontSize = 14,
            )
            DeviceButton(
                label = if (running) "STOP" else "START",
                onClick = { vm.toggleRun() },
                modifier = Modifier.weight(1f).height(56.dp),
                gradient = if (running) StartGradient else StartGradient,
                contentColor = Color.White,
                fontSize = 18,
            )
        }

        if (flashEnabled && running) BeatFlash(beatPulse, activeBeat)
    }
}

// -------- Beat lights (DB-66 LED strip) --------

@Composable
private fun BeatLightsView(accents: List<BeatAccent>, activeBeat: Int, running: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth().height(30.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        accents.forEachIndexed { i, a ->
            val isAccent = a == BeatAccent.ACCENT
            val on = running && i == activeBeat
            val size = if (isAccent) 20.dp else 16.dp
            val color = when {
                !on            -> DB66.LedOff
                isAccent       -> DB66.LedAccent
                else           -> DB66.LedBeat
            }
            Box(
                modifier = Modifier
                    .padding(horizontal = 5.dp)
                    .shadow(elevation = if (on) 10.dp else 0.dp,
                            shape = CircleShape,
                            spotColor = color, ambientColor = color)
                    .size(size)
                    .clip(CircleShape)
                    .background(color)
                    .border(1.dp, Color.Black.copy(alpha = 0.5f), CircleShape),
            )
        }
    }
}

// -------- LCD readout --------

@Composable
private fun LcdReadout(bpm: Int, beats: Int, running: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(elevation = 4.dp, shape = RoundedCornerShape(10.dp))
            .clip(RoundedCornerShape(10.dp))
            .background(LcdGradient)
            .border(3.dp, Color.Black.copy(alpha = 0.55f), RoundedCornerShape(10.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(modifier = Modifier.fillMaxWidth()) {
                LcdText("TEMPO", 12)
                Spacer(Modifier.weight(1f))
                LcdText(if (running) "▶ RUN" else "■ STOP", 12)
            }
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LcdText("%3d".format(bpm), 68, FontWeight.Black)
                Column(modifier = Modifier.padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    LcdText("BPM", 14, FontWeight.Black)
                }
            }
            Row(modifier = Modifier.fillMaxWidth()) {
                LcdField("BEAT", "$beats/4")
                LcdDivider()
                LcdField("SUBDIV", "OFF")
                LcdDivider()
                LcdField("SWING", "0%")
                LcdDivider()
                LcdField("TIMER", "--:--")
            }
        }
    }
}

@Composable
private fun LcdText(s: String, size: Int, weight: FontWeight = FontWeight.Bold) {
    Text(s, color = DB66.LcdInk, fontFamily = FontFamily.Monospace,
        fontWeight = weight, fontSize = size.sp)
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.LcdField(label: String, value: String) {
    Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = DB66.LcdInk.copy(alpha = 0.55f),
            fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 9.sp)
        Text(value, color = DB66.LcdInk,
            fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Black, fontSize = 12.sp)
    }
}

@Composable
private fun LcdDivider() {
    Box(modifier = Modifier.width(1.dp).height(22.dp).background(DB66.LcdInk.copy(alpha = 0.25f)))
}

// -------- Tempo / Beats / Accents --------

@Composable
private fun TempoControls(bpm: Double, onChange: (Double) -> Unit, onTap: () -> Unit) {
    LabeledPanel("Tempo") {
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Slider(
                value = bpm.toFloat(),
                onValueChange = { onChange(it.toDouble()) },
                valueRange = 30f..300f,
                colors = SliderDefaults.colors(
                    thumbColor = DB66.LedBeat,
                    activeTrackColor = DB66.LedBeat,
                    inactiveTrackColor = DB66.Panel,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DeviceButton("-1", { onChange(bpm - 1) }, fontSize = 12)
                DeviceButton("+1", { onChange(bpm + 1) }, fontSize = 12)
                DeviceButton("-5", { onChange(bpm - 5) }, fontSize = 12)
                DeviceButton("+5", { onChange(bpm + 5) }, fontSize = 12)
                DeviceButton("TAP", onTap, fontSize = 12,
                    contentColor = DB66.LedBeat)
            }
        }
    }
}

@Composable
private fun BeatsRow(beats: Int, onChange: (Int) -> Unit) {
    LabeledPanel("Meter") {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Beats", color = DB66.Engrave, fontSize = 13.sp,
                modifier = Modifier.weight(1f))
            DeviceButton("-", { onChange(beats - 1) }, fontSize = 14)
            Text(beats.toString(), color = DB66.LedBeat,
                fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            DeviceButton("+", { onChange(beats + 1) }, fontSize = 14)
        }
    }
}

@Composable
private fun AccentGrid(accents: List<BeatAccent>, onTap: (Int) -> Unit) {
    LabeledPanel("Accents") {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            accents.forEachIndexed { i, a ->
                val color = when (a) {
                    BeatAccent.ACCENT -> DB66.LedAccent
                    BeatAccent.NORMAL -> DB66.LedBeat.copy(alpha = 0.6f)
                    BeatAccent.MUTED  -> DB66.LedOff
                }
                Box(
                    modifier = Modifier
                        .padding(horizontal = 5.dp)
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(color)
                        .border(1.dp, Color.Black.copy(alpha = 0.5f), CircleShape)
                        .clickable { onTap(i) },
                )
            }
        }
    }
}

// -------- Subdivision grids --------

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
    LabeledPanel(title) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (b in 0 until beats) {
                for (c in 0 until cellsPerBeat) {
                    val idx = b * cellsPerBeat + c
                    val isMainSlot = c == 0
                    val on = grid.getOrElse(idx) { false }
                    val color = when {
                        isMainSlot -> DB66.LedOff
                        on         -> DB66.LedBeat
                        else       -> Color(0xFF2A2C30)
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(26.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(color)
                            .then(if (!isMainSlot) Modifier.clickable { onToggle(idx) } else Modifier),
                    )
                }
                if (b < beats - 1) Spacer(Modifier.width(4.dp))
            }
        }
        Spacer(Modifier.height(6.dp))
        LabeledSlider("Level", level, 0.0..1.0, onLevelChange)
    }
}

// -------- Sounds (per-role waveform pickers) --------

@Composable
private fun SoundsSection(vm: MetronomeViewModel) {
    val accentW by vm.accentWaveform.collectAsStateWithLifecycle()
    val beatW by vm.beatWaveform.collectAsStateWithLifecycle()
    val subW by vm.subdivisionWaveform.collectAsStateWithLifecycle()
    val tripW by vm.tripletWaveform.collectAsStateWithLifecycle()
    LabeledPanel("Sounds") {
        WaveformRow("Accent",  accentW, vm::setAccentWaveform)
        WaveformRow("Beat",    beatW,   vm::setBeatWaveform)
        WaveformRow("16ths",   subW,    vm::setSubdivisionWaveform)
        WaveformRow("Triplet", tripW,   vm::setTripletWaveform)
    }
}

@Composable
private fun WaveformRow(label: String, current: ClickWaveform, onSelect: (ClickWaveform) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 3.dp)) {
        Text(label, color = DB66.Engrave, fontSize = 12.sp, modifier = Modifier.width(64.dp))
        WaveformDropdown(current, onSelect)
    }
}

@Composable
private fun WaveformDropdown(current: ClickWaveform, onSelect: (ClickWaveform) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        DeviceButton(current.label, { expanded = true }, fontSize = 12,
            contentColor = DB66.LedBeat)
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ClickWaveform.entries.forEach { w ->
                DropdownMenuItem(text = { Text(w.label) }, onClick = {
                    onSelect(w); expanded = false
                })
            }
        }
    }
}

// -------- Feel / Quiet / Trainer / Timer / Tone --------

@Composable
private fun FeelSection(vm: MetronomeViewModel) {
    val swing by vm.swing.collectAsStateWithLifecycle()
    val offbeat by vm.clickOnOffbeats.collectAsStateWithLifecycle()
    val flash by vm.flashEnabled.collectAsStateWithLifecycle()
    LabeledPanel("Feel") {
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
    LabeledPanel("Quiet Count") {
        ToggleRow("Enabled", on, vm::setQuietEnabled)
        StepperRow("Play bars", play, vm::setQuietPlayBars)
        StepperRow("Mute bars", mute, vm::setQuietMuteBars)
    }
}

@Composable
private fun TempoTrainerSection(vm: MetronomeViewModel) {
    val on by vm.trainerEnabled.collectAsStateWithLifecycle()
    LabeledPanel("Tempo Trainer") {
        ToggleRow("Enabled", on, vm::setTrainerEnabled)
        Text("Ramps BPM by +N every M measures until target.",
            color = DB66.Engrave.copy(alpha = 0.7f), fontSize = 11.sp)
    }
}

@Composable
private fun PracticeTimerSection(vm: MetronomeViewModel) {
    val on by vm.timerEnabled.collectAsStateWithLifecycle()
    val remaining by vm.timerRemainingSec.collectAsStateWithLifecycle()
    val mins = remaining / 60
    val secs = remaining % 60
    LabeledPanel("Practice Timer") {
        ToggleRow("Enabled", on, vm::setTimerEnabled)
        if (on) {
            Text("Stops in %d:%02d".format(mins, secs),
                color = DB66.LedBeat, fontFamily = FontFamily.Monospace, fontSize = 16.sp)
        }
    }
}

@Composable
private fun ToneSection(vm: MetronomeViewModel) {
    val on by vm.toneEnabled.collectAsStateWithLifecycle()
    val freq by vm.toneFrequency.collectAsStateWithLifecycle()
    val vol by vm.toneVolume.collectAsStateWithLifecycle()
    LabeledPanel("Reference Tone") {
        ToggleRow("Play", on, vm::setToneEnabled)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("%.1f Hz".format(freq), color = DB66.LedBeat,
                fontFamily = FontFamily.Monospace, fontSize = 16.sp,
                modifier = Modifier.width(100.dp))
            DeviceButton("-1", { vm.stepToneSemitones(-1) }, fontSize = 12)
            DeviceButton("+1", { vm.stepToneSemitones(1) }, fontSize = 12)
            DeviceButton("A=440", vm::setToneA440, fontSize = 12, contentColor = DB66.LedBeat)
        }
        LabeledSlider("Volume", vol, 0.0..1.0, vm::setToneVolume)
    }
}

// -------- Flash overlay --------

@Composable
private fun BeatFlash(beatPulse: Long, activeBeat: Int) {
    val baseAlpha = if (activeBeat == 0) 0.30f else 0.14f
    var alpha by remember(beatPulse) { mutableStateOf(baseAlpha) }
    LaunchedEffect(beatPulse) { alpha = baseAlpha }
    val animated by animateFloatAsState(targetValue = 0f, label = "flash")
    val current = maxOf(alpha + animated - alpha, 0f)
    Box(modifier = Modifier.fillMaxSize().background(DB66.LedAccent.copy(alpha = current)))
}

// -------- Shared widgets --------

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
            Text(label, color = DB66.Engrave, fontSize = 12.sp, modifier = Modifier.weight(1f))
            Text(valueLabel ?: "%.0f%%".format(value * 100),
                color = DB66.LedBeat, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onChange(it.toDouble()) },
            valueRange = range.start.toFloat()..range.endInclusive.toFloat(),
            colors = SliderDefaults.colors(
                thumbColor = DB66.LedBeat,
                activeTrackColor = DB66.LedBeat,
                inactiveTrackColor = DB66.Panel,
            ),
        )
    }
}

@Composable
private fun ToggleRow(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = DB66.Engrave, fontSize = 13.sp, modifier = Modifier.weight(1f))
        Switch(checked = on, onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = DB66.LedBeat,
                checkedTrackColor = DB66.LedBeat.copy(alpha = 0.35f),
                uncheckedThumbColor = DB66.Engrave,
                uncheckedTrackColor = DB66.Panel,
            ))
    }
}

@Composable
private fun StepperRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, color = DB66.Engrave, fontSize = 13.sp, modifier = Modifier.weight(1f))
        DeviceButton("-", { onChange(value - 1) }, fontSize = 14)
        Text(value.toString(), color = DB66.LedBeat,
            fontFamily = FontFamily.Monospace, fontSize = 16.sp)
        DeviceButton("+", { onChange(value + 1) }, fontSize = 14)
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
        containerColor = DB66.Panel,
        title = { Text("Save preset", color = DB66.LedBeat) },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                label = { Text("Name") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = DB66.Engrave,
                    unfocusedTextColor = DB66.Engrave,
                    focusedBorderColor = DB66.LedBeat,
                    cursorColor = DB66.LedBeat,
                    focusedLabelColor = DB66.LedBeat,
                ),
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(name.ifBlank { "Untitled" }) }) {
                Text("SAVE", color = DB66.LedBeat)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("CANCEL", color = DB66.Engrave)
            }
        },
    )
}
