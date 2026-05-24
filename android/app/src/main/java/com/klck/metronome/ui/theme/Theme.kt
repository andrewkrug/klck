package com.klck.metronome.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * Boss Dr. Beat DB-66-inspired palette. Mirrors
 * Sources/Klck/Views/DB66Theme.swift::DB66 exactly so the Android UI
 * lands at the same visual touchstones as iOS.
 */
object DB66 {
    // Chassis
    val ChassisTop = Color(red = 0.20f, green = 0.21f, blue = 0.22f)
    val ChassisBot = Color(red = 0.10f, green = 0.105f, blue = 0.11f)
    val Panel      = Color(red = 0.16f, green = 0.165f, blue = 0.175f)
    val PanelEdge  = Color.White.copy(alpha = 0.06f)
    val Engrave    = Color(red = 0.62f, green = 0.64f, blue = 0.66f)

    // LCD
    val LcdBack     = Color(red = 0.66f, green = 0.73f, blue = 0.55f)
    val LcdBackEdge = Color(red = 0.56f, green = 0.63f, blue = 0.46f)
    val LcdInk      = Color(red = 0.09f, green = 0.13f, blue = 0.07f)
    val LcdInkDim   = LcdInk.copy(alpha = 0.22f)

    // LEDs
    val LedAccent = Color(red = 1.0f,  green = 0.27f, blue = 0.20f)   // red
    val LedBeat   = Color(red = 1.0f,  green = 0.74f, blue = 0.18f)   // amber
    val LedOff    = Color.White.copy(alpha = 0.10f)

    // Buttons
    val BtnTop    = Color(red = 0.27f, green = 0.28f, blue = 0.30f)
    val BtnBot    = Color(red = 0.17f, green = 0.175f, blue = 0.19f)
    val StartTop  = Color(red = 0.93f, green = 0.30f, blue = 0.24f)
    val StartBot  = Color(red = 0.74f, green = 0.18f, blue = 0.14f)
}

val ChassisGradient = Brush.verticalGradient(listOf(DB66.ChassisTop, DB66.ChassisBot))
val LcdGradient     = Brush.verticalGradient(listOf(DB66.LcdBack, DB66.LcdBackEdge))
val ButtonGradient  = Brush.verticalGradient(listOf(DB66.BtnTop, DB66.BtnBot))
val StartGradient   = Brush.verticalGradient(listOf(DB66.StartTop, DB66.StartBot))

// Material color scheme maps the DB-66 surface tokens into roles Compose
// components (sliders, switches) pick up automatically. Custom widgets read
// from DB66 directly for the hardware-look bits.
private val KlckDarkScheme = darkColorScheme(
    primary          = DB66.LedBeat,            // amber accent for primary surfaces
    onPrimary        = Color(0xFF1A1108),
    secondary        = DB66.LedAccent,          // red for "stop" / warning states
    onSecondary      = Color(0xFF1A0805),
    background       = DB66.ChassisBot,
    onBackground     = DB66.Engrave,
    surface          = DB66.Panel,
    onSurface        = DB66.Engrave,
    surfaceVariant   = Color(0xFF1A1B1F),
    onSurfaceVariant = DB66.Engrave.copy(alpha = 0.85f),
)

@Composable
fun KlckTheme(@Suppress("UNUSED_PARAMETER") useDark: Boolean = true, content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = KlckDarkScheme, content = content)
}
