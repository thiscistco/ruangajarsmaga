package id.smaga.ruangajar.guru

import androidx.compose.ui.graphics.Color
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.pow

class LoginThemeTest {
    private fun luminance(color: Color): Double {
        fun linear(value: Float): Double = if (value <= 0.04045f) value / 12.92 else ((value + 0.055) / 1.055).pow(2.4)
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }
    private fun contrast(a: Color, b: Color): Double {
        val x = luminance(a); val y = luminance(b)
        return (maxOf(x, y) + 0.05) / (minOf(x, y) + 0.05)
    }
    @Test fun readableTextInBothModes() {
        for (colors in listOf(LoginLightColors, LoginDarkColors)) {
            assertTrue(contrast(colors.primary, colors.onPrimary) >= 4.5)
            assertTrue(contrast(colors.background, colors.onBackground) >= 4.5)
            assertTrue(contrast(colors.surface, colors.onSurface) >= 4.5)
            assertTrue(contrast(colors.surfaceVariant, colors.onSurfaceVariant) >= 4.5)
            assertTrue(contrast(colors.surface, colors.secondary) >= 4.5)
            assertTrue(contrast(colors.background, colors.error) >= 4.5)
        }
    }
    @Test fun brightGoldIsConsistentButBackgroundChanges() {
        assertEquals(LoginGold, LoginLightColors.primary)
        assertEquals(LoginGold, LoginDarkColors.primary)
        assertNotEquals(LoginLightColors.background, LoginDarkColors.background)
        assertNotEquals(Color.White, LoginLightColors.onPrimary)
    }
}
