# Beranda Guru web

## Implementasi

- Login dengan peran teacher aktif + profil yang sesuai membuka TeacherHome. Akun admin+teacher memiliki tombol `Buka dashboard guru saya` dan dapat kembali ke admin; ini berbeda dari pratinjau guru admin yang tetap read-only.
- Data diambil melalui `/api/guru`, dengan sesi/cookie yang sama seperti `/api/sekolah`. Pemeriksaan `webAccess` memerlukan konteks satu sekolah. API tidak memakai service-role key.
- Kalender minggu/bulan, jam WIB, nama guru, kelas/mapel semester aktif, jadwal, agenda dan catatan pribadi. Preferensi tema ikon disimpan di localStorage, tidak ada data privat/token baru di localStorage.
- CRUD agenda/catatan memiliki revision check. Agenda dapat memiliki waktu mulai/selesai; catatan tidak memerlukan jam. Kedua jenis privat, tidak dapat dibaca oleh akun admin lain.
- Jadwal menghasilkan pertemuan bertanggal, opsional berulang tiap minggu hingga tanggal akhir yang dipilih guru (maksimal rentang 184 hari). Semester saat ini belum mempunyai tanggal awal/akhir resmi di database; guru harus memilih tanggal akhir yang sesuai. Jadwal mengacu pada penugasan semester aktif.
- Edit satu pertemuan atau pertemuan terpilih dan seterusnya dalam rangkaian, dengan alasan. Pergeseran hari maksimal 6 hari. Pembatalan mempertahankan baris dan riwayat, tidak menghapus permanen. Jadwal sebelum hari ini, sudah dibatalkan, atau semester tidak aktif tidak dapat diubah.
- Pemeriksaan jam/bentrok dan otorisasi berada di RPC, dengan advisory transaction lock per guru untuk serialisasi penulisan. Konflik menggagalkan keseluruhan perubahan.
- Riwayat detail jadwal tersimpan privat; UI menampilkan 30 metadata perubahan terbaru. Isi catatan tidak disalin ke audit admin.

## Database

Migrasi `202611180011_teacher_home.sql` berhasil diterapkan ke **ruangajar-test** (`uyhmglukvzimucfmthhk`) melalui connector pada sesi ini. Jangan ulangi migrasi yang telah diterapkan.

Tabel baru: teacher_planner_entries, teacher_meetings, teacher_planner_history. RLS aktif pada ketiganya, hanya SELECT untuk authenticated sesuai pemilik. Mutasi hanya lewat RPC. Execute RPC untuk anon ditolak; fungsi security-definer memakai search_path kosong dan pemeriksaan peran/pemilik. Status RLS dan privilege RPC diverifikasi melalui metadata database setelah migrasi.

Identitas assignment pada pertemuan disimpan tanpa FK yang menghalangi penghapusan guru/penugasan oleh alur admin lama. Bila penugasan hilang, UI menandai penugasan diarsipkan dan tidak mengizinkan edit. Riwayat pertemuan tetap tersimpan.

## Di luar cakupan

Absensi, jurnal, nilai, tugas/ujian dan pengaitan datanya ke meeting belum diubah. Tidak ada tenggat tugas fiktif di kalender. Belum ada aturan bentrok lintas guru/ruang, notifikasi, jadwal resmi sekolah, atau akses admin ke isi catatan pribadi. Kalender bulanan menandai agenda/catatan yang tersimpan.

## Validasi

`npm test`: pengujian schema/RLS melalui PGlite, privasi antar guru/admin/siswa, peran nonaktif, penugasan milik guru, validasi waktu, revision stale, rollback bentrok, pembatalan, perubahan tunggal/ke depan dan utilitas kalender/WIB. `npm run build` dan `git diff --check`.

Pengujian login end-to-end dengan akun nyata dan pemeriksaan visual browser/perangkat belum dilakukan. Preview statis `preview/teacher` masih simulasi terpisah. Untuk aplikasi asli gunakan Next.js dengan environment Supabase server sebagaimana `.env.example`; konfigurasi lokal belum tersedia. Deployment produksi membutuhkan merge PR dan verifikasi Vercel.
