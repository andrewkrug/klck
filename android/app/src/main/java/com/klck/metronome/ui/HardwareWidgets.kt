package com.klck.metronome.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.klck.metronome.ui.theme.ButtonGradient
import com.klck.metronome.ui.theme.DB66

/**
 * Recessed control panel — DB-66 chassis cutout. Mirrors the iOS
 * `DevicePanel` ViewModifier: rounded corners, faint inner border, drop
 * shadow.
 *
 * The content slot is laid out as a [Column] with consistent inter-child
 * spacing. (Earlier this was a [Box], which silently stacked multiple
 * children on top of each other — every panel with two-or-more rows
 * rendered as a tangle of overlapping labels.)
 */
@Composable
fun DevicePanel(
    modifier: Modifier = Modifier,
    inset: Dp = 14.dp,
    spacing: Dp = 10.dp,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    androidx.compose.foundation.layout.Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(elevation = 4.dp, shape = RoundedCornerShape(14.dp))
            .clip(RoundedCornerShape(14.dp))
            .background(DB66.Panel)
            .border(BorderStroke(1.dp, DB66.PanelEdge), RoundedCornerShape(14.dp))
            .padding(inset),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(spacing),
        content = content,
    )
}

/**
 * Beveled rubber button. Gradient top→bottom, faint inner border, drop
 * shadow, press-down scale. Matches `DeviceButtonStyle` on iOS.
 */
@Composable
fun DeviceButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    gradient: Brush = ButtonGradient,
    contentColor: Color = DB66.Engrave,
    fontSize: Int = 13,
    fontWeight: FontWeight = FontWeight.Bold,
    cornerRadius: Dp = 10.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Box(
        modifier = modifier
            .scale(if (pressed) 0.95f else 1f)
            .shadow(elevation = if (pressed) 0.dp else 2.dp, shape = RoundedCornerShape(cornerRadius))
            .clip(RoundedCornerShape(cornerRadius))
            .background(gradient)
            .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.12f)), RoundedCornerShape(cornerRadius))
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(contentPadding),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = contentColor,
            fontSize = fontSize.sp,
            fontWeight = fontWeight,
            fontFamily = FontFamily.SansSerif,
        )
    }
}

/**
 * Engraved section header on the chassis — small monospaced label that
 * separates panels, matching the silk-screened labels around DB-66
 * controls.
 */
@Composable
fun EngraveLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        color = DB66.Engrave,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
        modifier = modifier,
    )
}

/**
 * Helper combining EngraveLabel + DevicePanel, the most common pattern.
 */
@Composable
fun LabeledPanel(
    label: String,
    modifier: Modifier = Modifier,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        EngraveLabel(label)
        DevicePanel(content = content)
    }
}
