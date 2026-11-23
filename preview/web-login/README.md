# Preview login web

`index.html` adalah simulasi desain yang tidak mengirim kredensial. Form readonly memakai data contoh, CSP memblokir koneksi jaringan. Live preview statis port 3003 bukan login asli.

Implementasi login asli ada di `app/LoginPage.js`, menggunakan endpoint same-origin `/api/sekolah`. Server memakai `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` (lihat `.env.example`), tidak membutuhkan service-role key untuk login. Tidak ada kredensial/token yang disimpan di localStorage; hanya preferensi tema.

- Peran aktif diverifikasi server dari memberships dan profil guru/siswa dengan user_id + school_id yang sama.
- Akun lintas sekolah ditolak untuk menghindari konteks sekolah ambigu.
- Akun dengan peran admin membuka dashboard admin; admin+guru tetap membuka dashboard admin yang ada.
- Guru/siswa membuka konfirmasi peran dan tombol keluar, bukan dashboard pembelajaran baru.
- Operasi administrasi tetap memerlukan pemeriksaan admin server-side dan RLS.
- Tidak ada perubahan skema/migrasi atau pembuatan akun pada pekerjaan ini.

Validasi: `npm test` (termasuk web-access) dan `npm run build`. Uji akun asli, pemulihan cookie sesi, login gagal, peran nonaktif, logout dan portrait/landscape pada perangkat tetap perlu dilakukan di deployment yang terkonfigurasi. Jangan masukkan password ke chat.
