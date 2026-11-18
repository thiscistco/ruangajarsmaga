package id.smaga.ruangajar.guru

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class AuthRepositoryTest {
    private val uid = "00000000-0000-4000-8000-000000000001"
    private class Vault : TokenVault {
        var token: String? = null
        override fun read() = token
        override fun save(refreshToken: String) { token = refreshToken }
        override fun clear() { token = null }
    }
    private fun tokens(refresh: String = "refresh-new") = Reply(200, """{"access_token":"access","refresh_token":"$refresh"}""")
    private fun api(vault: Vault, active: Boolean = true, profile: Boolean = true, failCheck: Boolean = false) = Transport { _, path, bearer, body ->
        when {
            path.startsWith("/auth/v1/token") -> tokens()
            path == "/auth/v1/user" -> {
                assertEquals("refresh-new", vault.token) // rotation saved before verification
                if (failCheck) throw IOException("private transport diagnostic")
                assertEquals("access", bearer)
                Reply(200, """{"id":"$uid","email":"teacher@example.test"}""")
            }
            path.startsWith("/rest/v1/memberships") -> {
                assertTrue(path.contains("user_id=eq.$uid"))
                assertTrue(path.contains("role=eq.teacher&active=eq.true"))
                Reply(200, if (active) """[{"school_id":"school"}]""" else "[]")
            }
            path.startsWith("/rest/v1/teachers") -> Reply(200, if (profile) """[{"school_id":"school","name":"Guru Uji"},{"school_id":"other","name":"Not allowed"}]""" else "[]")
            path.startsWith("/auth/v1/logout") -> { assertNull(vault.token); assertNull(body); Reply(204, "") }
            else -> error("Unexpected request")
        }
    }
    @Test fun loginRequiresActiveTeacherAndMatchingProfile() {
        val vault = Vault()
        val result = AuthRepository(api(vault), vault).login("teacher@example.test", "test-password")
        assertEquals(1, result.teachers.size)
        assertEquals("Guru Uji", result.teachers.single().name)
        assertEquals("refresh-new", vault.token)
    }
    @Test fun inactiveOrNonTeacherAccountIsRejectedAndCleared() {
        val vault = Vault()
        try { AuthRepository(api(vault, active = false), vault).login("admin@example.test", "test-password"); fail() }
        catch (e: AuthProblem) { assertTrue(e.invalidSession) }
        assertNull(vault.token)
    }
    @Test fun missingTeacherProfileIsRejected() {
        val vault = Vault()
        try { AuthRepository(api(vault, profile = false), vault).login("teacher@example.test", "test-password"); fail() }
        catch (e: AuthProblem) { assertTrue(e.invalidSession) }
        assertNull(vault.token)
    }
    @Test fun networkFailureDoesNotDiscardRotatedRefreshToken() {
        val vault = Vault().apply { token = "old-refresh" }
        try { AuthRepository(api(vault, failCheck = true), vault).restore(); fail() }
        catch (_: IOException) { assertEquals("refresh-new", vault.token) }
    }
    @Test fun invalidRefreshClearsSession() {
        val vault = Vault().apply { token = "expired" }
        val repo = AuthRepository(Transport { _, path, _, body ->
            assertTrue(path.contains("refresh_token")); assertEquals("expired", body!!.getString("refresh_token")); Reply(400, "")
        }, vault)
        try { repo.restore(); fail() } catch (e: AuthProblem) { assertTrue(e.invalidSession) }
        assertNull(vault.token)
    }
    @Test fun wrongPasswordDoesNotPersistOrExposeServerResponse() {
        val vault = Vault()
        val repo = AuthRepository(Transport { _, _, _, _ -> Reply(400, "private debug content") }, vault)
        try { repo.login("teacher@example.test", "wrong"); fail() }
        catch (e: AuthProblem) { assertFalse(e.userMessage.contains("private debug")) }
        assertNull(vault.token)
    }
    @Test fun logoutClearsLocalTokenBeforeRemoteRequest() {
        val vault = Vault()
        val repo = AuthRepository(api(vault), vault)
        repo.login("teacher@example.test", "test-password")
        assertTrue(repo.logout()); assertNull(vault.token)
    }
    @Test fun temporaryRefreshFailurePreservesStoredSession() {
        val vault = Vault().apply { token = "keep-refresh" }
        val repo = AuthRepository(Transport { _, _, _, _ -> Reply(503, "") }, vault)
        try { repo.restore(); fail() } catch (e: AuthProblem) { assertFalse(e.invalidSession) }
        assertEquals("keep-refresh", vault.token)
    }
    @Test fun offlineLogoutStillRemovesLocalSession() {
        val vault = Vault()
        val delegate = api(vault)
        val repo = AuthRepository(Transport { method, path, token, body ->
            if (path.contains("logout")) throw IOException("offline")
            delegate.request(method, path, token, body)
        }, vault)
        repo.login("teacher@example.test", "test-password")
        assertFalse(repo.logout()); assertNull(vault.token)
    }
    @Test fun rejectsSecretKeysAndCleartextUrls() {
        for ((url, key) in listOf("http://example.test" to "sb_publishable_test", "https://example.test" to "sb_secret_do_not_use", "https://example.test" to "service-role")) {
            try { SupabaseTransport(url, key); fail() } catch (_: IllegalArgumentException) { }
        }
    }
}
