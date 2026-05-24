package com.klck.metronome.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.klck.metronome.MetronomeViewModel
import kotlin.math.abs

@Composable
fun TunerScreen(vm: MetronomeViewModel) {
    val ctx = LocalContext.current
    var permGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    var permDenied by remember { mutableStateOf(false) }

    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permGranted = granted
        permDenied = !granted
        if (granted) vm.tuner.start()
    }

    val listening by vm.tuner.isListening.collectAsStateWithLifecycle()
    val hasSignal by vm.tuner.hasSignal.collectAsStateWithLifecycle()
    val note by vm.tuner.noteName.collectAsStateWithLifecycle()
    val freq by vm.tuner.frequency.collectAsStateWithLifecycle()
    val cents by vm.tuner.cents.collectAsStateWithLifecycle()
    val lastError by vm.tuner.lastError.collectAsStateWithLifecycle()
    val inputLevel by vm.tuner.inputLevel.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        // Big LCD-style note readout.
        Surface(
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth().height(220.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = if (listening && hasSignal) note else "—",
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 96.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                    Text(
                        text = if (listening && hasSignal) "%.1f Hz".format(freq) else "no signal",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                    )
                }
            }
        }

        // ±50-cent meter.
        Surface(
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth().height(120.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = if (listening && hasSignal)
                            (if (cents >= 0) "+%.0f¢".format(cents) else "%.0f¢".format(cents))
                        else "—",
                        color = MaterialTheme.colorScheme.primary,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 18.sp,
                    )
                    Spacer(Modifier.height(8.dp))
                    CentsMeter(
                        cents = if (listening && hasSignal) cents else 0.0,
                        active = listening && hasSignal,
                    )
                }
            }
        }

        // Input level meter — surfaces "mic is alive but silent" vs "mic
        // is producing audio but pitch isn't locking" vs "mic isn't producing
        // anything at all", which is otherwise indistinguishable.
        if (listening) {
            InputLevelMeter(level = inputLevel)
        }

        when {
            lastError != null -> Text(
                lastError ?: "",
                color = MaterialTheme.colorScheme.secondary,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
            )
            permDenied -> Text(
                "Microphone access denied. Grant it in Settings → Apps → Klck → Permissions to use the tuner.",
                color = MaterialTheme.colorScheme.secondary,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.weight(1f))

        Button(
            onClick = {
                if (listening) {
                    vm.tuner.stop()
                } else if (permGranted) {
                    vm.tuner.start()
                } else {
                    permLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (listening) MaterialTheme.colorScheme.secondary
                                  else MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
            shape = RoundedCornerShape(28.dp),
            modifier = Modifier.fillMaxWidth().height(58.dp),
        ) {
            Text(if (listening) "STOP" else "LISTEN",
                fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }

        Text(
            "Pitch detected entirely on-device. No audio is recorded or transmitted.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 11.sp,
            textAlign = TextAlign.Center,
        )
    }

    // Auto-stop when leaving the tab.
    LaunchedEffect(Unit) { /* no-op; stop happens when ViewModel is cleared. */ }
}

/** Horizontal level bar — shows the live RMS of the mic input scaled
 *  with a soft compression curve so quiet voice / guitar shows as
 *  ~mid-bar instead of barely-visible. Greys out when the level is
 *  near-zero so it's obvious the mic is silent. */
@Composable
private fun InputLevelMeter(level: Float) {
    val display = kotlin.math.sqrt(level.coerceIn(0f, 1f)).coerceIn(0f, 1f)
    val active = level > 0.001f
    // Capture theme-derived colors out here — they're @Composable getters
    // and can't be read from inside Canvas's draw lambda.
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.secondary
    val onSurfaceMuted = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
    val track = Color(0xFF1A1B1F)
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            if (active) "INPUT" else "INPUT · silent",
            color = if (active) primary else onSurfaceMuted,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            fontSize = 10.sp,
        )
        androidx.compose.foundation.Canvas(
            modifier = Modifier.fillMaxWidth().height(8.dp),
        ) {
            drawRect(track, size = size)
            if (active) {
                val w = size.width * display
                drawRect(
                    color = if (display > 0.8f) secondary else primary,
                    size = androidx.compose.ui.geometry.Size(w, size.height),
                )
            }
        }
    }
}

/** Horizontal ±50-cent needle. Active = green, snapping to center when within ±5¢. */
@Composable
private fun CentsMeter(cents: Double, active: Boolean) {
    val clamped = cents.coerceIn(-50.0, 50.0)
    val color = when {
        !active        -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
        abs(cents) < 5 -> MaterialTheme.colorScheme.primary
        else           -> MaterialTheme.colorScheme.secondary
    }
    Canvas(modifier = Modifier.fillMaxWidth().height(36.dp)) {
        val w = size.width
        val h = size.height
        // Track.
        drawRect(Color(0xFF1A1B1F), topLeft = Offset(0f, h / 2 - 2), size = androidx.compose.ui.geometry.Size(w, 4f))
        // Ticks at -50, -25, 0, +25, +50.
        for (i in -2..2) {
            val x = w / 2 + (i * 25f / 50f) * (w / 2)
            val tickH = if (i == 0) h * 0.8f else h * 0.5f
            drawRect(Color(0xFF3A3C40), topLeft = Offset(x - 1f, (h - tickH) / 2),
                size = androidx.compose.ui.geometry.Size(2f, tickH))
        }
        // Needle.
        val needleX = (w / 2 + (clamped.toFloat() / 50f) * (w / 2))
        drawRect(color, topLeft = Offset(needleX - 3f, 0f),
            size = androidx.compose.ui.geometry.Size(6f, h))
    }
}
