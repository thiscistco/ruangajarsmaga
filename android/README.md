# RuangAjar Guru — Native Android, fitur 1

Kotlin + Jetpack Compose (bukan WebView). Modul Android berada dalam repository RuangAjar yang sama. Aplikasi memakai Supabase proyek yang sudah ada; tidak membuat backend baru. Fitur 2–7 dan pengaturan profil web belum termasuk.

## Cakupan

- Login email/password dari admin, toggle lihat/sembunyikan password, pesan kesalahan tanpa respons mentah server.
- Verifikasi `/auth/v1/user`, membership `teacher` aktif, dan profil guru yang tertaut. Admin yang juga teacher boleh masuk; admin saja/siswa/nonaktif ditolak. Profil beberapa sekolah didukung untuk identifikasi, belum ada pemilihan penugasan.
- Refresh token dienkripsi AES-GCM menggunakan Android Keystore; access token hanya di memori. Password tidak disimpan ke disk/saved state. Backup dan trafik HTTP non-TLS dimatikan; screenshot/recents dibatasi dengan FLAG_SECURE.
- Pemulihan sesi dengan refresh-token rotation saat startup/kembali ke foreground dan pemeriksaan ulang setelah lima menit layar aktif. Token hasil rotasi disimpan sebelum verifikasi role. Gagal jaringan tidak menampilkan data guru dan menawarkan retry tanpa membuang refresh token.
- Logout menghapus sesi lokal dahulu lalu mencoba revoke `scope=local`. Jika server tidak terjangkau, pesan menyatakan pencabutan server belum terkonfirmasi. Logout tidak memengaruhi sesi admin di perangkat lain.
- Otorisasi sebenarnya tetap RLS Supabase, bukan UI atau metadata yang bisa diubah pengguna. Jangan pernah mengemas service-role/secret key di APK. Semua akses data tahap berikutnya juga wajib memakai JWT pengguna dan memeriksa sesi/izin server.

## Build lokal

Kebutuhan: Android Studio Meerkat atau lebih baru, JDK 17, Android SDK 35, Gradle 8.11.1. Minimal Android 8.0/API 26. AGP 8.9.1, Kotlin 2.1.10.

1. Buka direktori `android/` di Android Studio.
2. Salin `local.properties.example` menjadi `local.properties`; pastikan `sdk.dir` diatur Android Studio.
3. Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY=sb_publishable_...` dari proyek **ruangajar-test**. Publishable key memang dapat diekstrak dari APK; keamanan bergantung pada RLS. Key `anon` legacy belum didukung konfigurasi ini. Jangan pakai key `service_role`/`sb_secret_...`.
4. Dengan Gradle 8.11.1 terpasang, jalankan dari `android/`: `gradle testDebugUnitTest assembleDebug`. Anda juga dapat membuat wrapper lokal menggunakan `gradle wrapper --gradle-version 8.11.1` lalu memakai `./gradlew`.
5. APK debug: `app/build/outputs/apk/debug/app-debug.apk`. Instal pada emulator/perangkat uji privat. Ini bukan APK rilis bertanda tangan untuk Play Store.

Repo belum menyertakan binary Gradle wrapper. Workflow `.github/workflows/android.yml` memasang Gradle/SDK/JDK pada GitHub Actions, menjalankan unit test dan assembleDebug, lalu mengunggah artifact debug **tanpa konfigurasi produksi**. Artifact tersebut hanya menampilkan petunjuk konfigurasi, bukan siap login. Untuk APK login, build dengan konfigurasi publishable dari langkah di atas. Tidak perlu mengirim key atau kredensial ke chat.

## Uji penerimaan privat (belum dijalankan di perangkat)

1. Login guru aktif: nama/email tampil, tanpa akses admin.
2. Akun admin+teacher boleh masuk; akun admin saja/siswa/guru nonaktif tidak boleh masuk.
3. Password salah/email belum terdaftar: pesan generik; tidak menampilkan payload/token.
4. Tutup/buka aplikasi dan putar layar: sesi pulih; password tidak disimpan.
5. Matikan jaringan: retry tersedia; data tidak ditampilkan sebelum verifikasi. Nyalakan lagi dan coba ulang.
6. Nonaktifkan role/cabut sesi melalui administrasi: saat pemeriksaan berikutnya akses ditolak.
7. Logout online/offline: token lokal dihapus; jika revoke server gagal ada peringatan.
8. Periksa penyimpanan aplikasi: tidak ada token plaintext; backup aplikasi tidak memuat sesi.

Unit test repository menggunakan transport/vault palsu, bukan akun nyata. Enkripsi Keystore, lifecycle, keyboard, dan UI memerlukan pengujian emulator/perangkat. Workspace Arena saat pembuatan tidak memiliki Java/Gradle/SDK dan jaringan Google Maven/Gradle dibatasi; build Android lokal belum dapat dijalankan. Status workflow GitHub Actions dilaporkan terpisah, jangan menganggap APK sudah lulus build sebelum CI berhasil.
