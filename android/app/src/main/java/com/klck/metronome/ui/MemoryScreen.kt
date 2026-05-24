package com.klck.metronome.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.klck.metronome.MetronomeViewModel
import com.klck.metronome.model.Preset
import com.klck.metronome.model.Setlist
import com.klck.metronome.ui.theme.DB66

@Composable
fun MemoryScreen(vm: MetronomeViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    Column(modifier = Modifier.fillMaxSize()) {
        // Use Material 3's default indicator (which positions itself
        // correctly) — overriding it with our own modifier was painting
        // a full-width amber block.
        TabRow(
            selectedTabIndex = tab,
            containerColor = DB66.Panel,
            contentColor = DB66.LedBeat,
        ) {
            Tab(
                selected = tab == 0,
                onClick = { tab = 0 },
                text = { Text("Presets", fontFamily = FontFamily.Monospace) },
                selectedContentColor = DB66.LedBeat,
                unselectedContentColor = DB66.Engrave,
            )
            Tab(
                selected = tab == 1,
                onClick = { tab = 1 },
                text = { Text("Setlists", fontFamily = FontFamily.Monospace) },
                selectedContentColor = DB66.LedBeat,
                unselectedContentColor = DB66.Engrave,
            )
        }
        when (tab) {
            0 -> PresetsTab(vm)
            else -> SetlistsTab(vm)
        }
    }
}

@Composable
private fun PresetsTab(vm: MetronomeViewModel) {
    val presets by vm.presets.collectAsStateWithLifecycle()
    if (presets.isEmpty()) {
        EmptyState(
            "No presets yet.\nTap SAVE on the Metronome tab to capture your current setup.",
        )
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(presets, key = { it.id }) { p -> PresetRow(p, onLoad = { vm.loadPreset(p) }, onDelete = { vm.deletePreset(p.id) }) }
    }
}

@Composable
private fun PresetRow(preset: Preset, onLoad: () -> Unit, onDelete: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onLoad)
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(preset.name,
                    color = MaterialTheme.colorScheme.primary,
                    fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    "%.0f BPM · %d beats".format(preset.bpm, preset.beatsPerCycle),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                )
            }
            Button(
                onClick = onDelete,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    contentColor = MaterialTheme.colorScheme.secondary,
                ),
                shape = RoundedCornerShape(10.dp),
            ) { Text("DELETE", fontSize = 11.sp) }
        }
    }
}

@Composable
private fun SetlistsTab(vm: MetronomeViewModel) {
    val setlists by vm.setlists.collectAsStateWithLifecycle()
    if (setlists.isEmpty()) {
        EmptyState(
            "No setlists yet.\nUse the + button on a preset row in the Setlists builder to start one.\n(Setlists UI ships in a follow-up — for now, presets are usable.)",
        )
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(setlists, key = { it.id }) { s -> SetlistRow(s, onDelete = { vm.deleteSetlist(s.id) }) }
    }
}

@Composable
private fun SetlistRow(setlist: Setlist, onDelete: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(setlist.name,
                    color = MaterialTheme.colorScheme.primary,
                    fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Text("${setlist.items.size} stops",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontFamily = FontFamily.Monospace, fontSize = 12.sp)
            }
            Button(
                onClick = onDelete,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    contentColor = MaterialTheme.colorScheme.secondary,
                ),
                shape = RoundedCornerShape(10.dp),
            ) { Text("DELETE", fontSize = 11.sp) }
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    Box(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            message,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp,
        )
    }
}
