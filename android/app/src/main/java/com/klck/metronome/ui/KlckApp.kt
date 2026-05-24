package com.klck.metronome.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccessTime
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.klck.metronome.MetronomeViewModel
import com.klck.metronome.ui.theme.ChassisGradient
import com.klck.metronome.ui.theme.DB66

/** Top-level navigation between Klck's three main screens. */
@Composable
fun KlckApp(vm: MetronomeViewModel) {
    var tab by remember { mutableStateOf(Tab.METRONOME) }
    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            NavigationBar(containerColor = DB66.ChassisBot) {
                Tab.entries.forEach { t ->
                    NavigationBarItem(
                        selected = tab == t,
                        onClick = { tab = t },
                        icon = { Icon(t.icon, contentDescription = t.label) },
                        label = { Text(t.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = DB66.LedBeat,
                            selectedTextColor = DB66.LedBeat,
                            indicatorColor = DB66.Panel,
                            unselectedIconColor = DB66.Engrave,
                            unselectedTextColor = DB66.Engrave,
                        ),
                    )
                }
            }
        },
        modifier = Modifier.background(ChassisGradient),
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(ChassisGradient)
                .padding(padding),
        ) {
            when (tab) {
                Tab.METRONOME -> MetronomeScreen(vm)
                Tab.MEMORY    -> MemoryScreen(vm)
                Tab.TUNER     -> TunerScreen(vm)
            }
        }
    }
}

enum class Tab(val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    METRONOME("Metronome", Icons.Outlined.AccessTime),
    MEMORY   ("Memory",    Icons.Outlined.Bookmark),
    TUNER    ("Tuner",     Icons.Outlined.GraphicEq),
}
