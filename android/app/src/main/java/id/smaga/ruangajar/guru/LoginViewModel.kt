package id.smaga.ruangajar.guru

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class LoginUi(
    val busy: Boolean = false,
    val configured: Boolean = true,
    val savedSession: Boolean = false,
    val session: LearningSession? = null,
    val selectedRole: String? = null,
    val message: String = ""
)

class LoginViewModel(application: Application) : AndroidViewModel(application) {
    private val vault = EncryptedTokenVault(application)
    private val repository = runCatching {
        AuthRepository(SupabaseTransport(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY), vault)
    }.getOrNull()
    private val mutable = MutableStateFlow(LoginUi(configured = repository != null))
    val state = mutable.asStateFlow()

    init { resume() }

    fun login(email: String, password: String) {
        if (mutable.value.busy || repository == null) return
        if (email.trim().isEmpty() || password.isEmpty()) {
            mutable.value = mutable.value.copy(message = "Isi email dan password."); return
        }
        authenticate { repository.login(email, password) }
    }

    fun resume() {
        if (mutable.value.busy || repository == null) return
        mutable.value = mutable.value.copy(busy = true)
        viewModelScope.launch {
            val saved = withContext(Dispatchers.IO) { runCatching { repository.hasSavedSession() }.getOrDefault(false) }
            mutable.value = mutable.value.copy(busy = false, savedSession = saved, session = null)
            if (saved) authenticate { repository.restore() }
        }
    }

    fun selectRole(role: String) {
        val current = mutable.value
        if (!current.busy && role in (current.session?.roles ?: emptyList())) {
            mutable.value = current.copy(selectedRole = role)
        }
    }

    private fun authenticate(work: () -> LearningSession) {
        val previousRole = mutable.value.selectedRole
        mutable.value = mutable.value.copy(busy = true, session = null, message = "")
        viewModelScope.launch {
            try {
                val session = withContext(Dispatchers.IO) { work() }
                mutable.value = LoginUi(session = session, savedSession = true, selectedRole = session.preferredRole(previousRole))
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                val saved = withContext(Dispatchers.IO) { runCatching { repository?.hasSavedSession() == true }.getOrDefault(false) }
                mutable.value = LoginUi(savedSession = saved, message = (e as? AuthProblem)?.userMessage
                    ?: "Belum dapat terhubung atau menyimpan sesi dengan aman. Periksa koneksi lalu coba lagi.")
            }
        }
    }

    fun logout() {
        if (mutable.value.busy || repository == null) return
        mutable.value = mutable.value.copy(busy = true, session = null)
        viewModelScope.launch {
            try {
                val remoteClosed = withContext(Dispatchers.IO) { repository.logout() }
                mutable.value = LoginUi(message = if (remoteClosed) "Anda sudah keluar."
                    else "Sesi di perangkat dihapus. Pencabutan sesi di server belum dapat dikonfirmasi.")
            } catch (e: CancellationException) { throw e }
            catch (_: Exception) { mutable.value = LoginUi(savedSession = true, message = "Sesi perangkat belum dapat dihapus. Coba keluar kembali.") }
        }
    }
}
