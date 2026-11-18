# Preview login: pilihan tema emas

Preview web portrait 390×844, bukan emulator atau APK. Jalankan dari root repository:

```sh
python3 -m http.server 3002 --bind 0.0.0.0 --directory preview/android
```

Tiga opsi interaktif:
- A / Ivory Gold: ivory #FFFCF5, kartu putih, aksen #E8B931, teks gelap. Default rekomendasi.
- B / Soft Gold Glass: gradasi krem emas dan kartu putih transparan dengan CSS backdrop-filter (fallback kartu transparan jika blur tidak didukung).
- C / Charcoal Gold: background #181818, kartu gelap, teks terang dan tombol emas dengan teks gelap.

Login hanya menampilkan logo/nama, email/password berikon, ikon mata, Masuk dan Hubungi admin. Label aksesibilitas tetap tersedia. Placeholder gabungan NIP / NISN@ruangajar.id; penjelasan format dipindahkan ke bantuan. Bantuan tidak menghubungi orang atau layanan mana pun.

Selector di luar frame ponsel adalah kontrol reviewer, bukan bagian UI aplikasi. Semua kolom readonly dengan data contoh, CSP melarang koneksi jaringan dan pengiriman form. Tema tidak dipersistenkan. Login, role, offline, dan logout semuanya simulasi. Tidak ada perubahan pada Kotlin, workflow APK, data Supabase atau otorisasi. Tema Android native menunggu pilihan pengguna.

Validasi pada perubahan ini: sintaks JavaScript, HTTP 200, git diff check, serta simulasi DOM dengan linkedom untuk tiga tema, placeholder/label, password toggle, bantuan, seluruh state, dan logout. linkedom hanya dipasang sementara di cache dan tidak menambah dependensi aplikasi. Belum ada pengujian screenshot/browser atau emulator Android.
