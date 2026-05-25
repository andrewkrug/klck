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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
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
import java.util.UUID

@Composable
fun MemoryScreen(vm: MetronomeViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    Column(modifier = Modifier.fillMaxSize()) {
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
    val setlists by vm.setlists.collectAsStateWithLifecycle()
    var picker by remember { mutableStateOf<Preset?>(null) }

    if (presets.isEmpty()) {
        EmptyState("No presets yet.\nTap SAVE on the Metronome tab to capture your current setup.")
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(presets, key = { it.id }) { p ->
            PresetRow(
                p,
                hasSetlists = setlists.isNotEmpty(),
                onLoad = { vm.loadPreset(p) },
                onDelete = { vm.deletePreset(p.id) },
                onAddToSetlist = {
                    when {
                        setlists.isEmpty() -> { /* button hidden */ }
                        setlists.size == 1 -> vm.addPresetToSetlist(setlists.first().id, p.id)
                        else               -> picker = p
                    }
                },
            )
        }
    }

    // Setlist chooser when there are multiple.
    val pick = picker
    if (pick != null) {
        SetlistChooser(
            setlists = setlists,
            onPick = { sl -> vm.addPresetToSetlist(sl.id, pick.id); picker = null },
            onDismiss = { picker = null },
        )
    }
}

@Composable
private fun PresetRow(
    preset: Preset,
    hasSetlists: Boolean,
    onLoad: () -> Unit,
    onDelete: () -> Unit,
    onAddToSetlist: () -> Unit,
) {
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
            if (hasSetlists) {
                Button(
                    onClick = onAddToSetlist,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = DB66.LedBeat,
                    ),
                    shape = RoundedCornerShape(10.dp),
                ) { Text("+SET", fontSize = 11.sp) }
                Spacer(Modifier.width(6.dp))
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
    val presets by vm.presets.collectAsStateWithLifecycle()
    var showCreate by remember { mutableStateOf(false) }
    val expanded = remember { mutableStateOf<UUID?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        if (setlists.isEmpty()) {
            EmptyState("No setlists yet. Tap + to create one, then use +SET on a preset to add stops.")
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(setlists, key = { it.id }) { s ->
                    SetlistRow(
                        setlist = s,
                        presets = presets,
                        isExpanded = expanded.value == s.id,
                        onToggle = { expanded.value = if (expanded.value == s.id) null else s.id },
                        onDelete = { vm.deleteSetlist(s.id) },
                        onRemoveItem = { itemId -> vm.removeSetlistItem(s.id, itemId) },
                    )
                }
            }
        }

        FloatingActionButton(
            onClick = { showCreate = true },
            containerColor = DB66.LedBeat,
            contentColor = DB66.ChassisBot,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp),
        ) {
            Icon(Icons.Outlined.Add, contentDescription = "New setlist")
        }
    }

    if (showCreate) {
        NameDialog(
            title = "New setlist",
            initial = "Setlist ${setlists.size + 1}",
            onConfirm = { name -> vm.createSetlist(name); showCreate = false },
            onDismiss = { showCreate = false },
        )
    }
}

@Composable
private fun SetlistRow(
    setlist: Setlist,
    presets: List<Preset>,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
    onRemoveItem: (UUID) -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable(onClick = onToggle)) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(setlist.name,
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        "${setlist.items.size} stop${if (setlist.items.size == 1) "" else "s"} · tap to ${if (isExpanded) "collapse" else "expand"}",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontFamily = FontFamily.Monospace, fontSize = 12.sp,
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
            if (isExpanded) {
                Spacer(Modifier.height(10.dp))
                Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(DB66.PanelEdge))
                Spacer(Modifier.height(10.dp))
                if (setlist.items.isEmpty()) {
                    Text(
                        "No stops yet — go to Presets and tap +SET on a preset to add it here.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 12.sp,
                    )
                } else {
                    setlist.items.forEachIndexed { idx, item ->
                        val preset = presets.firstOrNull { it.id == item.presetID }
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text("${idx + 1}.",
                                color = DB66.LedBeat,
                                fontFamily = FontFamily.Monospace, fontSize = 13.sp,
                                modifier = Modifier.width(28.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(preset?.name ?: "(missing preset)",
                                    color = MaterialTheme.colorScheme.onSurface,
                                    fontSize = 14.sp)
                                if (preset != null) {
                                    Text(
                                        "%.0f BPM · %d beats".format(preset.bpm, preset.beatsPerCycle),
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontFamily = FontFamily.Monospace, fontSize = 11.sp,
                                    )
                                }
                            }
                            Button(
                                onClick = { onRemoveItem(item.id) },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                    contentColor = MaterialTheme.colorScheme.secondary,
                                ),
                                shape = RoundedCornerShape(8.dp),
                                modifier = Modifier.size(32.dp),
                                contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
                            ) { Text("×", fontSize = 18.sp) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SetlistChooser(
    setlists: List<Setlist>,
    onPick: (Setlist) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = DB66.Panel,
        title = { Text("Add to which setlist?", color = DB66.LedBeat) },
        text = {
            Column {
                setlists.forEach { sl ->
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onPick(sl) }.padding(vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(sl.name, color = MaterialTheme.colorScheme.onSurface, fontSize = 15.sp,
                            modifier = Modifier.weight(1f))
                        Text("${sl.items.size}",
                            color = DB66.LedBeat, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("CANCEL", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
    )
}

@Composable
private fun NameDialog(
    title: String,
    initial: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = DB66.Panel,
        title = { Text(title, color = DB66.LedBeat) },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                label = { Text("Name") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
                    focusedBorderColor = DB66.LedBeat,
                    cursorColor = DB66.LedBeat,
                    focusedLabelColor = DB66.LedBeat,
                ),
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(name) }) {
                Text("CREATE", color = DB66.LedBeat)
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
