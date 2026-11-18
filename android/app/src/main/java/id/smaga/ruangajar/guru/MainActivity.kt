package id.smaga.ruangajar.guru

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
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
        setContent {
            MaterialTheme(colorScheme = lightColorScheme(primary = Color(0xFF6842D9))) {
                Surface(Modifier.fillMaxSize(), color = Color(0xFFF7F8FC)) { LoginScreen() }
            }
        }
    }
}

@Composable
private fun LoginScreen(model: LoginViewModel = viewModel()) {
    val state by model.state.collectAsStateWithLifecycle()
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner, model) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) model.resume() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    // Recheck access periodically only while this screen is foregrounded.
    LaunchedEffect(state.session, owner) {
        if (state.session != null) {
            delay(5 * 60 * 1000L)
            if (owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) model.resume()
        }
    }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var visible by remember { mutableStateOf(false) }
    var confirmLogout by remember { mutableStateOf(false) }
    LaunchedEffect(state.session) { if (state.session != null) { password = ""; visible = false } }

    Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding().verticalScroll(rememberScrollState())
        .padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(40.dp))
        Text("RuangAjar", style = MaterialTheme.typography.headlineLarge, color = MaterialTheme.colorScheme.primary)
        Text("PORTAL GURU", style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.height(28.dp))
        Card(Modifier.widthIn(max = 480.dp).fillMaxWidth()) {
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                when {
                    !state.configured -> {
                        Text("Aplikasi belum dikonfigurasi", style = MaterialTheme.typography.titleLarge)
                        Text("Pengelola perlu mengisi URL Supabase dan publishable key saat build. Jangan masukkan service role key ke aplikasi.")
                    }
                    state.busy -> {
                        CircularProgressIndicator()
                        Text("Memeriksa akun dan akses guru…")
                    }
                    state.session != null -> {
                        val session = state.session!!
                        Text("Login berhasil", style = MaterialTheme.typography.titleLarge)
                        Text("Selamat datang, ${session.teachers.first().name}.")
                        Text(session.email)
                        Text("Akses guru aktif: ${session.teachers.size} sekolah.")
                        Text("Fitur 1 selesai: login dan sesi guru. Daftar penugasan dan pembelajaran akan tersedia pada tahap berikutnya.")
                        OutlinedButton(onClick = { confirmLogout = true }, modifier = Modifier.fillMaxWidth()) { Text("Keluar") }
                    }
                    state.savedSession -> {
                        Text("Periksa sesi tersimpan", style = MaterialTheme.typography.titleLarge)
                        Text("Akses guru belum dapat diverifikasi. Data pembelajaran tidak ditampilkan sebelum verifikasi berhasil.")
                        Button(onClick = model::resume, modifier = Modifier.fillMaxWidth()) { Text("Coba lagi") }
                        TextButton(onClick = { confirmLogout = true }) { Text("Hapus sesi dan masuk ulang") }
                    }
                    else -> {
                        Text("Masuk sebagai guru", style = MaterialTheme.typography.titleLarge)
                        Text("Gunakan akun yang dibuat admin sekolah. Tidak ada pendaftaran mandiri.")
                        OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next))
                        OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                            visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(onDone = { model.login(email, password); password = ""; visible = false }),
                            trailingIcon = { IconButton(onClick = { visible = !visible }) {
                                Icon(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = if (visible) "Sembunyikan password" else "Tampilkan password")
                            } })
                        Button(onClick = { model.login(email, password); password = ""; visible = false },
                            enabled = email.isNotBlank() && password.isNotEmpty(), modifier = Modifier.fillMaxWidth()) { Text("Masuk") }
                        Text("Lupa password atau akses ditolak? Hubungi admin sekolah.", style = MaterialTheme.typography.bodySmall)
                    }
                }
                if (state.message.isNotEmpty()) Text(state.message, color = MaterialTheme.colorScheme.error)
            }
        }
        Spacer(Modifier.height(20.dp))
        Text("RuangAjar • Aplikasi Guru", style = MaterialTheme.typography.bodySmall)
    }
    if (confirmLogout) AlertDialog(onDismissRequest = { confirmLogout = false },
        title = { Text("Keluar dari akun?") }, text = { Text("Sesi tersimpan di perangkat ini akan dihapus.") },
        confirmButton = { TextButton(onClick = { confirmLogout = false; model.logout() }) { Text("Keluar") } },
        dismissButton = { TextButton(onClick = { confirmLogout = false }) { Text("Batal") } })
}
