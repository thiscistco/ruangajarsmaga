package id.smaga.ruangajar.guru

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

interface TokenVault { fun read(): String?; fun save(refreshToken: String); fun clear() }
data class Reply(val code: Int, val body: String)
fun interface Transport { fun request(method: String, path: String, bearer: String?, body: JSONObject?): Reply }
class AuthProblem(val userMessage: String, val invalidSession: Boolean = false) : Exception(userMessage)
data class TeacherIdentity(val schoolId: String, val name: String)
data class TeacherSession(val email: String, val teachers: List<TeacherIdentity>)

class SupabaseTransport(baseUrl: String, private val key: String) : Transport {
    private val base = baseUrl.trimEnd('/')
    init {
        val uri = URI(base)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.query == null && uri.fragment == null && uri.path.isNullOrEmpty())
        require(key.startsWith("sb_publishable_")) { "Only a publishable key may be packaged in Android" }
    }
    override fun request(method: String, path: String, bearer: String?, body: JSONObject?): Reply {
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            if (bearer != null) connection.setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            return Reply(code, stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally { connection.disconnect() }
    }
}

// Called only from the ViewModel's IO dispatcher. No password or token is logged.
class AuthRepository(private val api: Transport, private val vault: TokenVault) {
    private var accessToken: String? = null
    fun hasSavedSession() = vault.read() != null

    fun login(email: String, password: String): TeacherSession {
        val response = api.request("POST", "/auth/v1/token?grant_type=password", null,
            JSONObject().put("email", email.trim()).put("password", password))
        if (response.code !in 200..299) throw AuthProblem(
            if (response.code == 429) "Terlalu banyak percobaan. Tunggu sebelum mencoba lagi."
            else if (response.code in listOf(400, 401, 422)) "Tidak dapat masuk. Periksa email dan password."
            else "Layanan login belum tersedia. Coba lagi nanti.")
        return accept(response)
    }

    fun restore(): TeacherSession {
        val refresh = vault.read() ?: throw AuthProblem("Silakan masuk kembali.", true)
        val response = api.request("POST", "/auth/v1/token?grant_type=refresh_token", null,
            JSONObject().put("refresh_token", refresh))
        if (response.code in listOf(400, 401, 403)) {
            vault.clear(); accessToken = null
            throw AuthProblem("Sesi berakhir. Silakan masuk kembali.", true)
        }
        if (response.code !in 200..299) throw AuthProblem("Sesi belum dapat diperiksa. Periksa koneksi lalu coba lagi.")
        return accept(response)
    }

    private fun accept(response: Reply): TeacherSession {
        val tokens = JSONObject(response.body)
        val access = tokens.getString("access_token")
        val refresh = tokens.getString("refresh_token")
        require(access.isNotBlank() && refresh.isNotBlank())
        accessToken = access
        // Persist rotated refresh token before any network authorization checks.
        vault.save(refresh)
        try { return verifyTeacher(access) }
        catch (e: AuthProblem) {
            if (e.invalidSession) logout()
            throw e
        }
    }

    private fun checked(path: String, access: String): String {
        val response = api.request("GET", path, access, null)
        if (response.code in listOf(401, 403)) throw AuthProblem("Akses guru tidak tersedia. Silakan masuk kembali.", true)
        if (response.code !in 200..299) throw AuthProblem("Data akses belum dapat diperiksa. Coba lagi.")
        return response.body
    }

    private fun verifyTeacher(access: String): TeacherSession {
        val user = JSONObject(checked("/auth/v1/user", access))
        val uid = user.getString("id")
        // Prevent arbitrary query construction from an invalid server response.
        java.util.UUID.fromString(uid)
        val memberships = JSONArray(checked("/rest/v1/memberships?select=school_id&user_id=eq.$uid&role=eq.teacher&active=eq.true", access))
        val schools = (0 until memberships.length()).map { memberships.getJSONObject(it).getString("school_id") }.toSet()
        if (schools.isEmpty()) throw AuthProblem("Akun ini tidak memiliki akses guru aktif. Hubungi admin sekolah.", true)
        val profiles = JSONArray(checked("/rest/v1/teachers?select=school_id,name&user_id=eq.$uid", access))
        val teachers = (0 until profiles.length()).map { profiles.getJSONObject(it) }
            .filter { it.getString("school_id") in schools }
            .map { TeacherIdentity(it.getString("school_id"), it.getString("name")) }
        if (teachers.isEmpty()) throw AuthProblem("Profil guru belum tertaut. Hubungi admin sekolah.", true)
        return TeacherSession(user.optString("email"), teachers)
    }

    // Local logout always happens first. Remote failure is reported without restoring the token.
    fun logout(): Boolean {
        val token = accessToken
        vault.clear(); accessToken = null
        if (token == null) return false
        return try { api.request("POST", "/auth/v1/logout?scope=local", token, null).code in 200..299 }
        catch (_: Exception) { false }
    }
}
