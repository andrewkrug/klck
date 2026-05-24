package com.klck.metronome.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.klck.metronome.MetronomeViewModel
import com.klck.metronome.model.BeatAccent

@Composable
fun MetronomeScreen(vm: MetronomeViewModel) {
    val bpm by vm.bpm.collectAsStateWithLifecycle()
    val beats by vm.beatsPerCycle.collectAsStateWithLifecycle()
    val accents by vm.accents.collectAsStateWithLifecycle()
    val running by vm.isRunning.collectAsStateWithLifecycle()
    val activeBeat by vm.activeBeat.collectAsStateWithLifecycle()

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            // LCD-style BPM readout.
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier.fillMaxWidth().height(120.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = bpm.toInt().toString(),
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 76.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }

            // BPM slider + steppers.
            Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Tempo", color = MaterialTheme.colorScheme.onBackground, fontSize = 13.sp)
                Spacer(Modifier.height(6.dp))
                Slider(
                    value = bpm.toFloat(),
                    onValueChange = { vm.setBpm(it.toDouble()) },
                    valueRange = 30f..300f,
                    colors = SliderDefaults.colors(
                        thumbColor = MaterialTheme.colorScheme.primary,
                        activeTrackColor = MaterialTheme.colorScheme.primary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Stepper("-", onClick = { vm.setBpm(bpm - 1) })
                    Stepper("+", onClick = { vm.setBpm(bpm + 1) })
                }
            }

            // Beats per measure stepper.
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Text("Beats", color = MaterialTheme.colorScheme.onBackground, fontSize = 13.sp)
                Stepper("-", onClick = { vm.setBeatsPerCycle(beats - 1) })
                Text(
                    beats.toString(),
                    color = MaterialTheme.colorScheme.primary,
                    fontSize = 22.sp,
                    fontFamily = FontFamily.Monospace,
                )
                Stepper("+", onClick = { vm.setBeatsPerCycle(beats + 1) })
            }

            // Accent grid — tap each LED to cycle Accent / Normal / Muted.
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
            ) {
                accents.forEachIndexed { i, a ->
                    BeatLed(
                        accent = a,
                        active = (i == activeBeat) && running,
                        onTap = { vm.cycleAccent(i) },
                    )
                    if (i < accents.size - 1) Spacer(Modifier.width(8.dp))
                }
            }

            Spacer(Modifier.height(8.dp))

            // Start / Stop.
            Button(
                onClick = { vm.toggleRun() },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (running) MaterialTheme.colorScheme.secondary
                                      else MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                shape = RoundedCornerShape(28.dp),
                modifier = Modifier.fillMaxWidth().height(64.dp),
            ) {
                Text(
                    if (running) "STOP" else "START",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                )
            }

            Spacer(Modifier.height(8.dp))
            Text(
                "Klck — sample-accurate metronome",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun BeatLed(accent: BeatAccent, active: Boolean, onTap: () -> Unit) {
    val base = when (accent) {
        BeatAccent.ACCENT -> MaterialTheme.colorScheme.primary
        BeatAccent.NORMAL -> MaterialTheme.colorScheme.onSurfaceVariant
        BeatAccent.MUTED  -> Color(0xFF2A2C30)
    }
    val color = if (active) MaterialTheme.colorScheme.secondary else base
    IconButton(onClick = onTap, modifier = Modifier.size(44.dp)) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(color),
        )
    }
}

@Composable
private fun Stepper(label: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.surface,
            contentColor = MaterialTheme.colorScheme.primary,
        ),
        modifier = Modifier.size(44.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
    ) {
        Text(label, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}
