# Preview Beranda Guru — opsi 2

Jalankan `python3 -m http.server 3004 --bind 0.0.0.0 --directory preview/teacher`.

Preview statis terpisah dari aplikasi produksi dan Supabase. CSP memblokir koneksi/form eksternal. Data jadwal, agenda dan catatan hanya berada dalam memori; reload mereset simulasi. localStorage hanya untuk tema.

Fitur preview: jam WIB, tanggal minggu/bulan, navigasi kalender, sidebar ringkas/mobile, ikon tema, kelas contoh, CRUD agenda/catatan dan simulasi pola jadwal mingguan dengan validasi jam/bentrok. Kalender bulanan menandai agenda/catatan, bukan tenggat tugas fiktif.

Belum diimplementasikan: data akun asli/RLS, masa berlaku jadwal, pengecualian satu pertemuan, riwayat, tenggat tugas, absensi/jurnal/nilai. Persyaratan ini tetap diperlukan saat integrasi; simulasi jadwal tidak mewakili implementasi final perubahan pertengahan semester.

Validasi dilakukan: sintaks JavaScript dan git diff --check. Uji browser/perangkat dan integrasi backend belum dilakukan.
