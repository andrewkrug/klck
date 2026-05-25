package com.klck.metronome

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import com.klck.metronome.ui.KlckApp
import com.klck.metronome.ui.theme.KlckTheme

class MainActivity : ComponentActivity() {

    private val vm: MetronomeViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            KlckTheme(useDark = true) {
                KlckApp(vm)
            }
        }
    }
}
