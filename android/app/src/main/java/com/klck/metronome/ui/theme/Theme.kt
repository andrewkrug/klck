package com.klck.metronome.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Boss DB-66-inspired palette: dark chassis, pale LCD green.
private val ChassisDark   = Color(0xFF101113)
private val ChassisDarker = Color(0xFF06070A)
private val LcdGreen      = Color(0xFFB4E48E)
private val Amber         = Color(0xFFE89A2C)

private val KlckDarkScheme = darkColorScheme(
    primary       = LcdGreen,
    onPrimary     = ChassisDarker,
    secondary     = Amber,
    onSecondary   = ChassisDarker,
    background    = ChassisDarker,
    onBackground  = LcdGreen,
    surface       = ChassisDark,
    onSurface     = LcdGreen,
    surfaceVariant = Color(0xFF1A1B1F),
    onSurfaceVariant = Color(0xFF9FBE7A),
)

// Klck is dark-only; a light scheme exists only so the app doesn't crash on a
// light-theme device. In practice we ignore the system setting.
private val KlckLightScheme = lightColorScheme(
    primary    = ChassisDark,
    background = Color(0xFFF5F5F5),
    surface    = Color.White,
)

@Composable
fun KlckTheme(useDark: Boolean = true, content: @Composable () -> Unit) {
    val scheme = if (useDark) KlckDarkScheme else KlckLightScheme
    MaterialTheme(colorScheme = scheme, content = content)
}
