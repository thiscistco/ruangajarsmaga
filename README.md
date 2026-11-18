# RuangAjar — Tahap 1

Web admin Next.js dengan Supabase Auth dan skema Postgres. Workspace tidak berisi akun bawaan atau data sekolah. Jangan masukkan data pribadi ke preview ini.

## Menjalankan dan menguji

1. `npm ci`
2. `npm test` — menerapkan migrasi ke Postgres dalam memori (PGlite) dan menguji izin dengan identitas JWT simulasi. Fixture tidak masuk ke aplikasi.
3. `npm run build` lalu `npm run dev` untuk memeriksa UI. Tanpa konfigurasi Supabase, API tidak menampilkan data dan login tidak aktif.

## Uji integrasi berikutnya (belum dijalankan)

Gunakan Supabase lokal lewat CLI/Docker atau lingkungan privat yang sudah disetujui. Terapkan `supabase/migrations/202611180001_foundation.sql`. Salin `.env.example` ke `.env.local` dan isi URL serta **publishable key** proyek tersebut (bukan service-role key). Buat akun individual lewat Supabase Auth, lalu melalui akses database tepercaya buat baris `schools` dan kaitkan UUID pengguna itu ke `memberships` dengan `role='admin'`. Mulai ulang web dan verifikasi login, pembaruan sesi, logout, dan akses yang ditolak. Proyek lokal dan cloud tidak dikonfigurasi otomatis oleh aplikasi. UI admin tahap ini hanya mendukung akun dengan satu sekolah admin aktif, walaupun skema mendukung lebih dari satu sekolah.

Kebijakan database menolak akses anonim, membatasi akses berdasarkan keanggotaan dan peran, serta mencatat UUID pelaku publikasi, koreksi absensi dan pratinjau guru. Admin tidak diberi izin tulis nilai. Menu pengaturan, perubahan profil, impor, undangan/pemulihan akun, dan pemilihan sekolah belum tersedia. Sebelum mengimpor data nyata, uji integrasi login di lingkungan privat dan verifikasi kebijakan akses pada instance yang akan dipakai.
