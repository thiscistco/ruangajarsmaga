package id.smaga.ruangajar.guru

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.*
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        val preferences = getSharedPreferences("display_preferences", MODE_PRIVATE)
        setContent {
            var dark by rememberSaveable { mutableStateOf(preferences.getBoolean("dark_mode", false)) }
            val colors = if (dark) LoginDarkColors else LoginLightColors
            val view = LocalView.current
            SideEffect {
                window.statusBarColor = colors.background.toArgb()
                window.navigationBarColor = colors.background.toArgb()
                WindowCompat.getInsetsController(window, view).apply {
                    isAppearanceLightStatusBars = !dark
                    isAppearanceLightNavigationBars = !dark
                }
            }
            MaterialTheme(colorScheme = colors) {
                LoginScreen(dark = dark, onToggleMode = {
                    dark = !dark
                    preferences.edit().putBoolean("dark_mode", dark).apply()
                })
            }
        }
    }
}

@Composable
private fun LoginScreen(dark: Boolean, onToggleMode: () -> Unit, model: LoginViewModel = viewModel()) {
    val state by model.state.collectAsStateWithLifecycle()
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner, model) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) model.resume() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(state.session, owner) {
        if (state.session != null) {
            delay(5 * 60 * 1000L)
            if (owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) model.resume()
        }
    }
    LoginContent(state, dark, onToggleMode, model::login, model::resume, model::logout, model::selectRole)
}

@Composable
private fun GoldenFlowBackground() {
    Canvas(Modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        drawPath(Path().apply {
            moveTo(-w * .1f, h * .1f)
            cubicTo(w * .25f, h * .22f, w * .5f, -h * .06f, w * 1.1f, h * .14f)
            lineTo(w * 1.1f, h * .19f)
            cubicTo(w * .5f, h * .02f, w * .25f, h * .25f, -w * .1f, h * .12f)
            close()
        }, LoginGold.copy(alpha = .045f))
        drawPath(Path().apply {
            moveTo(-w * .1f, h * .87f)
            cubicTo(w * .2f, h * .7f, w * .6f, h * 1.12f, w * 1.1f, h * .86f)
            lineTo(w * 1.1f, h * 1.1f)
            lineTo(-w * .1f, h * 1.1f)
            close()
        }, LoginGold.copy(alpha = .065f))
    }
}

@Composable
private fun LoginContent(
    state: LoginUi, dark: Boolean, onToggleMode: () -> Unit,
    onLogin: (String, String) -> Unit, onRetry: () -> Unit, onLogout: () -> Unit, onRole: (String) -> Unit
) {
    // Password and visibility deliberately stay out of saved-instance state.
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var visible by remember { mutableStateOf(false) }
    var confirmLogout by remember { mutableStateOf(false) }
    var help by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val submit = {
        if (!state.busy && email.isNotBlank() && password.isNotEmpty()) {
            onLogin(email, password)
            password = ""; visible = false; focus.clearFocus()
        }
    }
    LaunchedEffect(state.session) { if (state.session != null) { password = ""; visible = false } }
    val colors = MaterialTheme.colorScheme
    Surface(Modifier.fillMaxSize(), color = colors.background) {
        Box(Modifier.fillMaxSize()) {
            GoldenFlowBackground()
            Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding()
                .verticalScroll(rememberScrollState()).padding(horizontal = 28.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally) {
                Row(Modifier.widthIn(max = 420.dp).fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onToggleMode,
                        modifier = Modifier.heightIn(min = 48.dp).semantics {
                            contentDescription = if (dark) "Aktifkan light mode" else "Aktifkan dark mode"
                        }, colors = ButtonDefaults.textButtonColors(contentColor = colors.onSurfaceVariant)) {
                        Icon(if (dark) Icons.Default.LightMode else Icons.Default.DarkMode, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(if (dark) "Light mode" else "Dark mode", fontSize = 12.sp)
                    }
                }
                Column(Modifier.widthIn(max = 420.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(painterResource(R.drawable.learning_book), contentDescription = null,
                        modifier = Modifier.fillMaxWidth().aspectRatio(921f / 588f))
                    Spacer(Modifier.height(14.dp))
                    Text("RuangAjar", fontSize = 32.sp, fontWeight = FontWeight.Normal, letterSpacing = (-1).sp, color = colors.onBackground)
                    Spacer(Modifier.height(34.dp))
                    when {
                        !state.configured -> MessageCard {
                            Text("Aplikasi belum dikonfigurasi", style = MaterialTheme.typography.titleLarge)
                            Text("Pengelola perlu mengisi URL Supabase dan publishable key saat build. Jangan masukkan service role key ke aplikasi.")
                        }
                        state.busy -> MessageCard {
                            CircularProgressIndicator(color = colors.secondary, modifier = Modifier.size(36.dp))
                            Text("Memeriksa akun…", modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                        }
                        state.session != null -> MessageCard {
                            val session = state.session
                            val role = state.selectedRole
                            if (role == null) {
                                Text("Pilih tampilan", style = MaterialTheme.typography.titleLarge)
                                Text("Akun ini memiliki lebih dari satu peran aktif.")
                                session.roles.forEach { available ->
                                    Button(onClick = { onRole(available) }, modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp)) {
                                        Text(if (available == "teacher") "Masuk sebagai Guru" else "Masuk sebagai Siswa")
                                    }
                                }
                            } else {
                                val profiles = session.profiles.filter { it.role == role }
                                val label = if (role == "teacher") "Guru" else "Siswa"
                                Text("Ruang $label", style = MaterialTheme.typography.titleLarge)
                                Text("Selamat datang, ${profiles.first().name}.")
                                Text(session.email)
                                Text("Akses ${label.lowercase()} aktif: ${profiles.size} sekolah.")
                                Text(if (role == "teacher") "Login guru berhasil. Penugasan dan pembelajaran tersedia pada tahap berikutnya."
                                    else "Login siswa berhasil. Kelas, materi, tugas, dan ujian tersedia pada tahap berikutnya.")
                                if (session.roles.size > 1) session.roles.filter { it != role }.forEach { other ->
                                    TextButton(onClick = { onRole(other) }, colors = ButtonDefaults.textButtonColors(contentColor = colors.secondary)) {
                                        Text(if (other == "teacher") "Beralih ke Guru" else "Beralih ke Siswa")
                                    }
                                }
                            }
                            OutlinedButton(onClick = { confirmLogout = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.onSurface)) { Text("Keluar") }
                        }
                        state.savedSession -> MessageCard {
                            Text("Periksa sesi tersimpan", style = MaterialTheme.typography.titleLarge)
                            Text("Akses akun belum dapat diverifikasi. Coba lagi setelah koneksi tersedia.")
                            Button(onClick = onRetry, modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp)) { Text("Coba lagi") }
                            TextButton(onClick = { confirmLogout = true }, colors = ButtonDefaults.textButtonColors(contentColor = colors.secondary)) { Text("Hapus sesi dan masuk ulang") }
                        }
                        else -> {
                            Surface(shape = RoundedCornerShape(28.dp), color = colors.surface,
                                border = BorderStroke(1.dp, colors.outlineVariant), shadowElevation = if (dark) 0.dp else 5.dp,
                                modifier = Modifier.fillMaxWidth()) {
                                Column(Modifier.padding(17.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                    val fieldColors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = colors.secondary, unfocusedBorderColor = colors.outlineVariant,
                                        focusedContainerColor = if (dark) colors.surfaceVariant else colors.surface,
                                        unfocusedContainerColor = if (dark) colors.surfaceVariant else colors.surface,
                                        cursorColor = colors.secondary)
                                    OutlinedTextField(value = email, onValueChange = { email = it },
                                        placeholder = { Text("NIP / NISN@ruangajar.id", fontSize = 12.sp) },
                                        leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                                        modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Email login" }, singleLine = true,
                                        shape = RoundedCornerShape(26.dp), colors = fieldColors,
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                                        keyboardActions = KeyboardActions(onNext = { focus.moveFocus(androidx.compose.ui.focus.FocusDirection.Down) }))
                                    OutlinedTextField(value = password, onValueChange = { password = it },
                                        leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
                                        modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Password" }, singleLine = true,
                                        shape = RoundedCornerShape(26.dp), colors = fieldColors,
                                        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                                        keyboardActions = KeyboardActions(onDone = { submit() }),
                                        trailingIcon = { IconButton(onClick = { visible = !visible }) {
                                            Icon(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                                contentDescription = if (visible) "Sembunyikan password" else "Tampilkan password")
                                        } })
                                }
                            }
                            Spacer(Modifier.height(18.dp))
                            Button(onClick = { submit() }, enabled = email.isNotBlank() && password.isNotEmpty(),
                                shape = RoundedCornerShape(26.dp), modifier = Modifier.fillMaxWidth().padding(horizontal = 17.dp).heightIn(min = 50.dp)) { Text("Masuk") }
                            TextButton(onClick = { help = true }, modifier = Modifier.heightIn(min = 48.dp),
                                colors = ButtonDefaults.textButtonColors(contentColor = colors.onSurfaceVariant)) { Text("Hubungi admin", fontSize = 13.sp) }
                        }
                    }
                    if (state.message.isNotEmpty()) Text(state.message, color = colors.error,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 17.dp, vertical = 16.dp).semantics { liveRegion = LiveRegionMode.Polite })
                    Spacer(Modifier.height(24.dp))
                }
            }
        }
    }
    if (help) AlertDialog(onDismissRequest = { help = false },
        containerColor = colors.surface, titleContentColor = colors.onSurface, textContentColor = colors.onSurfaceVariant,
        title = { Text("Hubungi admin sekolah") },
        text = { Text("Guru menggunakan NIP@ruangajar.id dan siswa menggunakan NISN@ruangajar.id.\n\nUntuk akun baru atau lupa password, hubungi admin sekolah melalui saluran resmi.") },
        confirmButton = { TextButton(onClick = { help = false }, colors = ButtonDefaults.textButtonColors(contentColor = colors.secondary)) { Text("Mengerti") } })
    if (confirmLogout) AlertDialog(onDismissRequest = { confirmLogout = false },
        containerColor = colors.surface, titleContentColor = colors.onSurface, textContentColor = colors.onSurfaceVariant,
        title = { Text("Keluar dari akun?") }, text = { Text("Sesi tersimpan di perangkat ini akan dihapus.") },
        confirmButton = { TextButton(onClick = { confirmLogout = false; onLogout() }, colors = ButtonDefaults.textButtonColors(contentColor = colors.secondary)) { Text("Keluar") } },
        dismissButton = { TextButton(onClick = { confirmLogout = false }, colors = ButtonDefaults.textButtonColors(contentColor = colors.secondary)) { Text("Batal") } })
}

@Composable
private fun MessageCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
    }
}

@Preview(name = "Golden Flow • Light", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun LoginLightPreview() {
    MaterialTheme(colorScheme = LoginLightColors) { LoginContent(LoginUi(), false, {}, { _, _ -> }, {}, {}, {}) }
}

@Preview(name = "Golden Flow • Dark", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun LoginDarkPreview() {
    MaterialTheme(colorScheme = LoginDarkColors) { LoginContent(LoginUi(), true, {}, { _, _ -> }, {}, {}, {}) }
}
