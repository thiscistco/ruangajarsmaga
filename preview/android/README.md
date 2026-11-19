# Preview login terpilih — Golden Flow Pendidikan

Preview web portrait 390×844, bukan emulator/APK. Jalankan dari root repository:

```sh
python3 -m http.server 3002 --bind 0.0.0.0 --directory preview/android
```

## Desain terpilih

Pengguna memilih konsep ilustrasi buku/pensil dengan Golden Flow dan kuning cerah. Preview mengadaptasi konsep tersebut dengan gambar dekoratif di atas, nama RuangAjar, dua kolom ikon dalam kartu putih, tombol Masuk di bawah kartu, serta bantuan admin. Ilustrasi `assets/learning-book.png` dipotong dari konsep AI pilihan pengguna `design-options/ruangajar-education-background.png`; background tepi dihapus untuk memungkinkan mode gelap. Ini adaptasi interaktif, bukan screenshot aplikasi native.

Tombol **Light mode / Dark mode** mengubah warna halaman reviewer, layar ponsel, input, dialog, dan teks. Peralihan mode tidak menghapus state simulasi atau mengganti role. Default light mode. Mode hanya di memori, tidak menyimpan kredensial atau preferensi browser. Dark mode merupakan adaptasi kontras dari konsep light yang dipilih, bukan gambar konsep kedua.

Semua kolom readonly dengan data contoh. CSP melarang koneksi jaringan dan pengiriman form; gambar hanya dari origin lokal. Tidak ada autentikasi nyata. Role, offline, bantuan, dan logout adalah simulasi. Label aksesibilitas tetap tersedia dan dekorasi diabaikan pembaca layar. Reset layar tidak mereset mode yang dipilih.

Tidak ada perubahan pada Kotlin, workflow APK, data Supabase, atau otorisasi pada tahap ini. Pilihan tema/background A/B/C sebelumnya tersimpan dalam riwayat Git; preview utama sekarang fokus pada desain terpilih.

## Validasi

Sintaks JavaScript, HTTP 200, diff check dan simulasi DOM dengan linkedom: asset tersedia, dua field dikelompokkan, mode terang/gelap pada 9 state, pergantian mode mempertahankan state, toggle password, bantuan, logout, readonly dan CSP. linkedom/Pillow hanya digunakan sementara untuk tes/pengolahan asset, bukan dependensi aplikasi. Belum diuji secara visual di browser/emulator atau perangkat nyata.
