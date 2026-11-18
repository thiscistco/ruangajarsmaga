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

## Tambah guru/siswa sekaligus akun

Migrasi `202611180009_add_profile_account.sql` menambahkan transaksi service-role-only untuk profil, keanggotaan aktif, enrollment siswa, dan audit. **Tambah Guru** meminta nama, email login (juga email profil), dan password. **Tambah Siswa** meminta nama, email login, password serta kelas semester aktif (NIS tidak lagi diperlukan setelah migrasi 010); tombol simpan dinonaktifkan bila tidak tersedia kelas aktif. Password tetap memiliki ikon lihat/sembunyikan dan validasi 8–128 karakter.

Server membuat akun Auth terlebih dahulu, kemudian memanggil RPC dengan identitas admin yang sudah diverifikasi. Jika transaksi database gagal, server mencoba menghapus hanya akun Auth baru itu; bila pembersihan gagal, pesan meminta pengelola memeriksa Auth. Akun lama/email yang sudah terdaftar tidak diambil alih. Password tidak masuk profil, audit, atau respons API. Gangguan jaringan/server antara Auth dan transaksi masih dapat memerlukan pemeriksaan manual; keduanya bukan satu transaksi lintas layanan.

Impor Excel guru/siswa kini membuat akun juga (lihat format migrasi 010 di bawah). **Buat Akun** masih tersedia pada profil lama/hasil impor tanpa akun. Tidak ada pembuatan akun otomatis untuk data lama, perubahan akun admin, atau perubahan halaman login guru/siswa pada fitur ini. Pengujian database dan build dijalankan; uji browser/Auth end-to-end dengan akun privat belum dilakukan.


## Impor akun dan antarmuka (migrasi 010)

`202611180010_account_import.sql` membuat NIS nullable (nilai lama dipertahankan), mengubah edit siswa agar tidak membutuhkan/menghapus NIS, dan menambahkan RPC impor akun khusus service role. Tidak perlu mengulang migrasi lama. Impor profil lama guru/siswa pada endpoint web digantikan dengan **Impor Akun**; impor kelas/mapel/penugasan tidak berubah.

Format Excel: **Role, Nama, Email, Password, Kelas**. Kolom Kelas tetap ada, tetapi boleh kosong untuk guru; siswa wajib kelas semester aktif. Role hanya `guru` atau `siswa`, dapat dicampur dalam satu file. Maksimal 500 baris / 1 MB per file. Browser mengirim batch berurutan berisi 10 baris (maksimal 50 permintaan), dengan progres dan ringkasan kumulatif. File diparsing ulang di server pada setiap batch, tetapi hanya baris batch yang diproses. Duplikat email diperiksa di seluruh file, termasuk antar-batch. Satu baris per email. Format sel sebagai teks; spasi password tidak dipangkas. Jangan bagikan file kredensial atau unggah ke chat. File tidak disimpan di server/Git; respons dan audit tidak memuat password.

- Profil guru lama: email dan nama harus cocok (abaikan kapitalisasi/spasi luar). Nama sama/email berbeda atau email sama/nama berbeda dilaporkan.
- Profil siswa lama: nama harus unik dalam sekolah dan enrollment kelas harus cocok. Nama ganda atau kelas berbeda dilaporkan untuk diperiksa; tidak menebak identitas.
- Profil tanpa akun yang cocok ditautkan, profil baru dibuat. Profil yang sudah tertaut dilewati tanpa reset password/aktivasi ulang. Akun Auth lama yang belum tertaut tidak diambil alih; email terdaftar ditolak.
- Ringkasan memisahkan profil baru, akun ditautkan, dilewati, dan kesalahan per baris. Batch tidak atomik: baris sukses tetap tersimpan walaupun baris lain gagal. Batas waktu batch bisa menghasilkan baris belum diproses; ulangi hanya baris tersebut. Bila respons hilang/koneksi putus, periksa profil dan Auth sebelum mengulang.
- Auth dan database bukan satu transaksi lintas layanan; rollback database diikuti upaya hapus Auth baru. Kegagalan pembersihan diberitahukan untuk pemeriksaan manual.

Label statis “Workspace lokal” diganti “Portal Admin Sekolah”; label itu bukan deteksi lingkungan. Sidebar desktop dapat diperkecil menjadi ikon; preferensi tersimpan di localStorage browser tanpa kredensial. Mobile tetap memakai menu overlay. Tes database, parser Excel, dan alur Auth mock dijalankan; uji browser dan Auth cloud end-to-end belum dilakukan.


## Ekspor pembelajaran dan impor 500 baris

Absensi, Jurnal Mengajar, Materi, dan Penilaian memiliki **Unduh Excel** dan **Cetak / Simpan PDF**. Ekspor memakai baris yang sedang tampil setelah pencarian, dari data yang sudah dimuat melalui API admin (bukan mengambil seluruh database atau menambah hak akses). Tombol dinonaktifkan jika belum login/tidak ada baris. Laporan memuat sekolah, waktu WIB, pencarian, jumlah baris, kelas/mapel/guru dan kolom terkait; materi menyertakan isi materi. Excel menyimpan input pengguna sebagai sel teks, bukan formula. Pratinjau cetak merender teks lewat React, bukan HTML mentah, dan tombol Cetak membuka dialog browser; pilih tujuan **Simpan sebagai PDF**. Laporan panjang dapat memerlukan pengaturan skala cetak.

Selama impor akun, jangan tutup tab. Navigasi aplikasi dan penutupan dialog dibatasi; browser diberi peringatan sebelum keluar. Progres menghitung baris yang responsnya telah diterima, termasuk yang gagal/dilewati. Respons gagal menghentikan pengiriman batch berikutnya; tidak ada retry otomatis atau penyimpanan password di localStorage. Hasil batch yang sudah sukses tetap berlaku. Periksa profil/Auth untuk batch dengan hasil tidak pasti sebelum mengulang. Batas 500 adalah per file, bukan jaminan 500 akun selalu sukses (kebijakan Auth/rate limit tetap berlaku). Kelas guru boleh kosong; siswa wajib kelas semester aktif.

Tes otomatis mencakup file 500/501 baris, duplikat lintas batch, 50 batch berurutan, batch terakhir parsial, berhenti saat koneksi gagal, dan workbook untuk keempat menu termasuk nilai nol serta teks berawalan formula. Tes database dan build lulus; pratinjau cetak/browser dan 500 akun Auth cloud belum diuji end-to-end. Perubahan batas batch/ekspor ini tidak membutuhkan migrasi database tambahan.
