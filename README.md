# RuangAjar — Tahap 1

Web admin Next.js dengan Supabase Auth dan skema Postgres. Workspace tidak berisi akun bawaan atau data sekolah. Jangan masukkan data pribadi ke preview ini.

## Menjalankan dan menguji

1. `npm ci`
2. `npm test` — menerapkan migrasi ke Postgres dalam memori (PGlite) dan menguji izin dengan identitas JWT simulasi. Fixture tidak masuk ke aplikasi.
3. `npm run build` lalu `npm run dev` untuk memeriksa UI. Tanpa konfigurasi Supabase, API tidak menampilkan data dan login tidak aktif.

## Uji integrasi berikutnya (belum dijalankan)

Gunakan Supabase lokal lewat CLI/Docker atau lingkungan privat yang sudah disetujui. Terapkan `supabase/migrations/202611180001_foundation.sql`. Salin `.env.example` ke `.env.local` dan isi URL serta **publishable key** proyek tersebut (bukan service-role key). Buat akun individual lewat Supabase Auth, lalu melalui akses database tepercaya buat baris `schools` dan kaitkan UUID pengguna itu ke `memberships` dengan `role='admin'`. Mulai ulang web dan verifikasi login, pembaruan sesi, logout, dan akses yang ditolak. Proyek lokal dan cloud tidak dikonfigurasi otomatis oleh aplikasi. UI admin tahap ini hanya mendukung akun dengan satu sekolah admin aktif, walaupun skema mendukung lebih dari satu sekolah.

Kebijakan database menolak akses anonim, membatasi akses berdasarkan keanggotaan dan peran, serta mencatat UUID pelaku publikasi, koreksi absensi dan pratinjau guru. Admin tidak diberi izin tulis nilai. Menu pengaturan, perubahan profil, impor, undangan/pemulihan akun, dan pemilihan sekolah belum tersedia. Sebelum mengimpor data nyata, uji integrasi login di lingkungan privat dan verifikasi kebijakan akses pada instance yang akan dipakai.

## Akun guru dan siswa oleh admin

Terapkan migrasi `202611180007_account_link.sql` sekali setelah migrasi sebelumnya. Di Vercel proyek RuangAjar, tambahkan `SUPABASE_SERVICE_ROLE_KEY` dari proyek Supabase yang sama sebagai secret server-side, lalu redeploy. Jangan memakai awalan `NEXT_PUBLIC_`, membagikan key di chat, atau menyimpannya di Git.

Admin memilih **Buat Akun** pada profil Guru/Siswa yang belum tertaut, mengisi email login dan kata sandi 8–128 karakter. Email login boleh berbeda dari email kontak guru. Akun langsung dikonfirmasi oleh admin; pastikan alamat benar dan bagikan kredensial melalui saluran aman. Email yang telah terdaftar ditolak, tidak diambil alih. Keanggotaan, penautan profil, dan audit disimpan dalam satu transaksi; jika penautan gagal, server mencoba menghapus akun Auth baru. Pesan kegagalan pembersihan memerlukan pemeriksaan Supabase Auth oleh pengelola. Password tidak disimpan di profil atau audit.

Pembuatan akun tidak memberi akses admin. Halaman login web saat ini tetap khusus admin; antarmuka login/dashboard guru dan siswa belum termasuk fase ini. Pengujian database menggunakan fixture lokal; uji Auth end-to-end membutuhkan konfigurasi server dan akun uji privat.

## Hapus guru permanen

Migrasi `202611180008_delete_teacher.sql` menyediakan RPC admin-only dengan pratinjau jumlah penugasan, absensi, nilai, materi, dan jurnal. Ikon Hapus pada Guru membuka konfirmasi; admin wajib mengetik nama persis dan mencentang persetujuan. Semua penugasan guru (termasuk semester lama) beserta catatan tersebut dihapus dalam satu transaksi, kemudian profil dan keanggotaan teacher sekolah itu dihapus. Perubahan jumlah data sejak pratinjau membatalkan penghapusan sampai konfirmasi diperbarui. Tidak ada hak edit nilai umum yang ditambahkan.

Akun Supabase Auth **tidak dihapus**, termasuk jika hanya digunakan sebagai guru. Peran admin/siswa, keanggotaan sekolah lain, data master siswa/kelas/mapel, enrollment, serta audit tetap disimpan. Email login tetap terdaftar dan tidak dapat dipakai untuk membuat akun baru melalui Buat Akun; penautan kembali akun lama belum tersedia di UI. Penghapusan profil tidak sama dengan penghapusan identitas Auth. Operasi tercatat sebagai `teacher_permanent_delete`. Cadangkan data penting sebelum mengonfirmasi; tindakan ini tidak menyediakan undo.

Pengujian otomatis memverifikasi izin, isolasi sekolah, pratinjau tanpa penghapusan, konfirmasi salah, pembersihan relasi, serta preservasi akun/peran lain dan audit. Uji interaksi browser dengan akun privat belum dilakukan. Migrasi hanya memasang fungsi, tidak menghapus data guru yang ada.
