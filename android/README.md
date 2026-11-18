# RuangAjar Guru & Siswa — Native Android, fitur 1

Kotlin + Jetpack Compose (bukan WebView). Modul Android berada dalam repository RuangAjar yang sama. Aplikasi memakai Supabase proyek yang sudah ada; tidak membuat backend baru. Fitur 2–7 dan pengaturan profil web belum termasuk.

## Cakupan

- Login email/password dari admin, toggle lihat/sembunyikan password, pesan kesalahan tanpa respons mentah server.
- Verifikasi `/auth/v1/user`, membership `teacher`/`student` aktif dan profil sesuai peran yang tertaut di sekolah yang sama. Guru dan siswa boleh masuk; admin yang juga teacher/student boleh masuk; admin saja atau membership nonaktif ditolak. Profil beberapa sekolah didukung untuk identifikasi, belum ada pemilihan penugasan.
- Refresh token dienkripsi AES-GCM menggunakan Android Keystore; access token hanya di memori. Password tidak disimpan ke disk/saved state. Backup dan trafik HTTP non-TLS dimatikan; screenshot/recents dibatasi dengan FLAG_SECURE.
- Pemulihan sesi dengan refresh-token rotation saat startup/kembali ke foreground dan pemeriksaan ulang setelah lima menit layar aktif. Token hasil rotasi disimpan sebelum verifikasi role. Gagal jaringan tidak menampilkan data akun dan menawarkan retry tanpa membuang refresh token.
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

1. Login guru aktif menuju Ruang Guru; siswa aktif menuju Ruang Siswa. Nama/email tampil, tanpa akses admin.
2. Akun admin+teacher dan siswa aktif boleh masuk; akun admin saja/guru atau siswa nonaktif tidak boleh masuk.
3. Password salah/email belum terdaftar: pesan generik; tidak menampilkan payload/token.
4. Tutup/buka aplikasi dan putar layar: sesi pulih; password tidak disimpan.
5. Matikan jaringan: retry tersedia; data tidak ditampilkan sebelum verifikasi. Nyalakan lagi dan coba ulang.
6. Nonaktifkan role/cabut sesi melalui administrasi: saat pemeriksaan berikutnya akses ditolak.
7. Logout online/offline: token lokal dihapus; jika revoke server gagal ada peringatan.
8. Periksa penyimpanan aplikasi: tidak ada token plaintext; backup aplikasi tidak memuat sesi.

Unit test repository menggunakan transport/vault palsu, bukan akun nyata. Enkripsi Keystore, lifecycle, keyboard, dan UI memerlukan pengujian emulator/perangkat. Workspace Arena saat pembuatan tidak memiliki Java/Gradle/SDK dan jaringan Google Maven/Gradle dibatasi; build Android lokal belum dapat dijalankan. Status workflow GitHub Actions dilaporkan terpisah, jangan menganggap APK sudah lulus build sebelum CI berhasil.

## Build APK melalui GitHub Actions

Build debug dan unit test pada commit `13ec557` berhasil di run `44225222698`. Artifact saat itu tidak dikonfigurasi untuk login. Pengujian perangkat nyata tetap diperlukan.

Workflow sekarang menyediakan build manual opsional dengan konfigurasi. Setelah workflow tersedia di branch default (PR digabungkan):

1. Buka GitHub repository → **Settings → Secrets and variables → Actions → Variables**.
2. Tambahkan `RUANGAJAR_SUPABASE_URL` dan `RUANGAJAR_SUPABASE_PUBLISHABLE_KEY` untuk proyek RuangAjar yang sama. Gunakan key berawalan `sb_publishable_` saja. Jangan pernah menambahkan service-role/secret key sebagai nilai variabel ini. Publishable key bukan rahasia dan akan berada dalam APK; RLS tetap wajib.
3. Buka **Actions → Android Guru → Run workflow**, pilih branch yang dimaksud, centang **Build APK login dengan Repository Variables RuangAjar**.
4. Setelah berhasil, unduh artifact **ruangajar-guru-debug-configured**, ekstrak ZIP lalu instal APK pada HP uji. Tanpa centang, artifact tetap **ruangajar-guru-debug-unconfigured**. Build PR otomatis selalu tanpa konfigurasi.
5. Ini APK debug, bukan distribusi Play Store. Artifact disimpan tujuh hari. Jangan bagikan APK debug ke publik sebelum uji akses dan sesi selesai.

## Preview portrait di Arena

`preview/android/index.html` merupakan simulasi web visual berdasarkan layout Compose fitur 1, **bukan emulator dan bukan APK asli**. Jalankan dari root repo:

`python3 -m http.server 3001 --bind 0.0.0.0 --directory preview/android`

Preview memiliki ukuran dasar 390×844 dan diskalakan agar muat. Pilih login, sukses, akses ditolak, offline, belum dikonfigurasi, atau loading. Ikon mata dan logout dapat disimulasikan. Kolom kredensial contoh readonly; CSP memblokir koneksi jaringan dan submit form. Tidak ada autentikasi sungguhan, storage sesi, atau panggilan Supabase. Tampilan font, keyboard, lifecycle, dan Material 3 asli tetap harus diuji lewat APK/emulator.


## Pembaruan login guru dan siswa

Nama tampilan aplikasi menjadi **RuangAjar**. Package/applicationId `id.smaga.ruangajar.guru`, alias Keystore, nama artifact dan nama workflow lama sengaja dipertahankan agar instalasi/sesi yang ada tetap kompatibel, bukan membuat aplikasi kedua.

Kolom email memakai ikon amplop dan placeholder `NIP@ruangajar.id`; password memakai ikon gembok dan tombol mata. Label teks visual dihilangkan tetapi semantics Email login/Password tetap tersedia untuk TalkBack. Petunjuk: guru `NIP@ruangajar.id`, siswa `NISN@ruangajar.id` (ganti NIP/NISN dengan identitas masing-masing saat admin membuat akun). Alamat email lama tetap bisa login: format domain/panjang nomor tidak dipakai sebagai aturan pemberian role dan akun lama tidak diubah otomatis. Tidak ada verifikasi kepemilikan NIP/NISN baru di tahap ini.

Tujuan login berasal dari membership aktif + profil yang cocok berdasarkan school_id dan user_id. Metadata role/email tidak dipercaya untuk otorisasi. Satu role langsung membuka halaman sambutan role tersebut; akun dua role memilih Guru/Siswa dan boleh beralih hanya di antara role terverifikasi. Saat refresh, pilihan dipertahankan bila masih valid. Ini masih fitur 1: dashboard kelas/tugas/ujian siswa belum dibuat. Tidak perlu migrasi; RLS own_student dan own_teacher sudah tersedia.

Preview portrait menampilkan skenario login guru, login siswa, Ruang Guru, Ruang Siswa, serta akun dua peran. Tetap simulasi dengan kredensial readonly; tidak membuktikan login perangkat nyata. Tes Android diperluas untuk siswa, email yang tidak sesuai role, admin-only, admin+teacher, profil siswa hilang, dua role, dan restore/logout siswa. Tambahkan pemeriksaan TalkBack dan pemilihan role di checklist uji perangkat.
