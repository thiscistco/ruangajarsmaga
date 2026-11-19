package id.smaga.ruangajar.guru

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Bright gold is paired with charcoal text in both modes, never white text.
val LoginGold = Color(0xFFFFDA3B)
val LoginGoldText = Color(0xFF28210C)
val LoginLightColors = lightColorScheme(
    primary = LoginGold, onPrimary = LoginGoldText,
    primaryContainer = Color(0xFFFFECA0), onPrimaryContainer = LoginGoldText,
    secondary = Color(0xFF6B5317), onSecondary = Color.White,
    background = Color(0xFFFAF6F0), onBackground = Color(0xFF252525),
    surface = Color.White, onSurface = Color(0xFF252525),
    surfaceVariant = Color(0xFFF3EEE5), onSurfaceVariant = Color(0xFF625E55),
    outline = Color(0xFF81786B), outlineVariant = Color(0xFFE5E0D7),
    error = Color(0xFFA22B27), onError = Color.White
)
val LoginDarkColors = darkColorScheme(
    primary = LoginGold, onPrimary = LoginGoldText,
    primaryContainer = Color(0xFF554719), onPrimaryContainer = Color(0xFFFFECA0),
    secondary = Color(0xFFE9CE7E), onSecondary = Color(0xFF302810),
    background = Color(0xFF181A1D), onBackground = Color(0xFFF6F4EC),
    surface = Color(0xFF25282C), onSurface = Color(0xFFF6F4EC),
    surfaceVariant = Color(0xFF303338), onSurfaceVariant = Color(0xFFC6C3B9),
    outline = Color(0xFFA5A095), outlineVariant = Color(0xFF4C4F52),
    error = Color(0xFFFFB4AB), onError = Color(0xFF601410)
)
