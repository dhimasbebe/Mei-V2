# Saran Penerapan Mei-V2 (Rekomendasi Terbaik)

> Konteks: backend & database lama sudah tidak dapat diakses (`meivtelpro.my.id` NXDOMAIN), struktur data sudah terverifikasi dari Buku TA, dan seluruh perencanaan sudah ada di `LEGACY-ANALYSIS.md` / `PLAN-FLUTTER-LARAVEL.md`.
> Dokumen ini berisi **urutan penerapan yang saya rekomendasikan** + keputusan teknis yang paling mengurangi risiko.

---

## 1. Prinsip utama: bangun "jalur emas" lebih dulu, bukan semua fitur sekaligus

Risiko terbesar proyek ini bukan Flutter atau Laravel-nya, tapi **memastikan model data checklist (`kategori` → `spesifikasi` → `detail_maintenance`) benar-benar cocok untuk semua jenis alat**. Karena itu:

**Minggu pertama harus membuktikan satu alur penuh, ujung ke ujung, untuk SATU kategori saja (pilih AC):**

```
Login (NIP) → Home (grid dari API) → Scan barcode AC → Detail alat
→ Form dinamis (4 field AC dari tabel spesifikasi) → Submit
→ Data masuk maintenance + detail_maintenance (1 transaksi)
→ Muncul di Riwayat alat → Muncul di 1 kartu KPI dashboard
```

Kalau jalur ini jalan, sisa 6 kategori hanya **penambahan data seed**, bukan pekerjaan baru. Kalau dibangun per-layar (semua layar dulu, integrasi belakangan), bug model data baru ketemu di akhir — itu pola kegagalan paling umum.

---

## 2. Urutan rilis yang saya rekomendasikan

| Tahap | Isi | Hasil yang bisa dipakai |
|---|---|---|
| **Sprint 0** (±1 minggu) | Repo Mei-V2 + CI + Laravel skeleton + migrasi `schema-v2.sql` + seed kategori/spesifikasi + Login end-to-end + tema Flutter | Login berhasil di HP nyata |
| **Sprint 1** | Master data (kategori, spesifikasi, alat, lokasi, users) + Home + Scan + Detail Alat + Riwayat | **Teknisi sudah bisa pakai untuk melihat riwayat** — nilai cepat, walau belum bisa input |
| **Sprint 2** | Form dinamis + submit transaksi + laporan PDF/CSV | **Paritas fungsional dengan aplikasi lama tercapai** → aplikasi lama bisa dipensiunkan |
| **Sprint 3** | Dashboard web (KPI, Analytics, Records, Alat, Lokasi, Reports, Users) | Supervisor dapat monitoring — nilai tambah utama |
| **Sprint 4 (P1)** | Offline draft, notifikasi pengingat, ekspor lanjutan | Ketahanan lapangan + saran penulis TA |

**Aturan**: setiap sprint harus bisa dipakai di lapangan, bukan hanya demo. Jangan gabungkan Sprint 2 dan 3 — keduanya besar.

---

## 3. Keputusan teknis yang saya sarankan

### 3.1 Deployment

| Aspek | Rekomendasi | Alasan |
|---|---|---|
| Server | **VPS kecil** (2 vCPU / 4 GB) atau shared hosting dengan **PHP 8.2+ & MySQL 8** | Laravel 11 butuh PHP 8.2+; VPS memberi kontrol backup & cron |
| Web server | Nginx + PHP-FPM | Standar, hemat memori |
| Domain | **Domain baru + auto-renew ON** | Pelajaran langsung: domain lama mati → data hilang tak terjangkau |
| Subdomain | `api.domain` (Laravel) & `app.domain` (dashboard Flutter Web) | CORS jadi eksplisit: whitelist hanya `app.domain` |
| HTTPS | Let's Encrypt (Certbot) | Wajib: token Bearer + data alat |
| Backup | `mysqldump` harian via cron + retensi 30 hari + salinan mingguan ke luar server | Mitigasi risiko yang sudah terbukti terjadi |
| CI/CD | GitHub Actions: `flutter analyze`, `flutter test`, `php artisan test`, build web | Cegah regresi sebelum deploy |

### 3.2 Keamanan (perbaikan bug warisan — wajib)

1. Password **bcrypt** + wajib reset semua akun (password lama plaintext, tidak bisa dikonversi).
2. Semua tulis data via **POST/PUT** (lama: GET) + parameter binding (Eloquent).
3. **Bearer token Sanctum** + middleware role di server — jangan hanya sembunyikan menu di klien.
4. Rate limit pada `/auth/login` (mis. 5 percobaan/menit).
5. **Audit trail**: `created_by`, `created_at` pada maintenance.
6. Perbaiki `id_spesifikasi` agar unik per kategori (sudah dilakukan di `schema-v2.sql`).

### 3.3 Ketahanan lapangan (penting untuk teknisi)

- **Offline-first sejak desain**, walau implementasinya P1: setiap draft simpan **`client_uuid`** (UUID v4) yang di-generate di HP, dan server memberi `UNIQUE` pada kolom itu → sinkron dua kali tidak menghasilkan data ganda (idempoten).
- Timestamp pemeliharaan: kirim **waktu perangkat + waktu server**; tampilkan waktu server sebagai kebenaran (HP teknisi bisa salah jam).
- Jangan paksa login ulang saat offline: simpan token + izinkan mode terbatas (lihat draft & master data yang sudah ter-cache).

### 3.4 Data master (ini penentu keberhasilan, bukan kode)

- **Kumpulkan lebih dulu**: daftar alat (barcode, merk, kategori, lokasi) + daftar ruangan/lantai. Tanpa ini aplikasi tidak bisa dipakai. Minta dalam bentuk Excel/CSV → impor lewat seeder/artisan command.
- **QR/barcode fisik**: pertahankan `barcode_alat` VARCHAR(10) agar label QR lama yang sudah ditempel tetap terbaca. Untuk alat yang belum berlabel, cetak QR baru (isi QR = `barcode_alat`, bukan URL, supaya tidak bergantung domain).
- **Deskripsi fungsi alat** (untuk layar Detail Alat, seperti penjelasan Panel Listrik di aplikasi lama) → simpan di `kategori.deskripsi`, bukan di kode.

### 3.5 Notifikasi (saran penulis TA)

Mulai dari yang paling murah, naik bertahap:
1. **Laravel Scheduler** harian: hitung alat overdue → kirim **email** ke Supervisor + ringkasan harian.
2. Tahap 2: **WhatsApp** (gateway) atau FCM untuk teknisi.
3. Tahap 3: in-app notification center di dashboard.
Jangan langsung FCM — butuh Firebase + konfigurasi per platform, sementara nilainya sama untuk pengingat harian.

---

## 4. Keputusan yang saya rekomendasikan untuk pertanyaan terbuka

| # | Pertanyaan | Rekomendasi saya | Alasan |
|---|---|---|---|
| Q6 | Siklus pemeliharaan / definisi overdue | **30 hari default, disimpan per kategori** (`kategori.maintenance_cycle_days`), bisa diubah dari dashboard; overdue = `hari ini - terakhir maintenance > cycle` | Fleksibel tanpa perlu ubah kode; siap dikoreksi setelah data nyata masuk |
| Q11 | Kategori Genset | **Pertahankan kategori, tunda form-nya** sampai checklist dikonfirmasi | Sudah ada di rancangan lama; menghapus berarti nanti perlu migrasi |
| Q12 | Username = NIP, tanpa registrasi mandiri | **Ya, dipertahankan**; akun dibuat Admin di dashboard | Sesuai kebutuhan operasional Telkom Property |
| Q13 | Warna brand | Ambil hex resmi dari brand guideline; sementara pakai merah Telkom (± `#EC1C24`) | Jangan asal menebak warna korporat |
| Q15 | Data historis 2022 | **Cari dump `.sql`** (lihat `DB-RECOVERY.md`) — kalau tidak ketemu, mulai dari nol dan tandai periode lama sebagai "tanpa data" | Struktur sudah aman; hanya isi data yang hilang |

---

## 5. Yang paling sering membuat proyek seperti ini gagal

| Risiko | Mitigasi |
|---|---|
| Master data alat/lokasi tidak lengkap → teknisi tidak menemukan alat | Selesaikan impor master data **sebelum** Sprint 1 selesai |
| Kategori/checklist di-hardcode di Flutter (bug lama) | Selalu ambil dari `GET /kategori` + `/spesifikasi` |
| Form dinamis kaku saat kategori punya tipe input baru (mis. foto) | `spesifikasi.tipe_input` sudah menyiapkan `number/text/select`; tambah `photo` di P1 |
| Teknisi menolak aplikasi baru karena berbeda dari yang lama | Pertahankan alur & istilah lama (ALAT, Kondisi, Catatan Perbaikan, grid ikon) — ubah hanya yang memperbaiki bug |
| Data hilang lagi | Backup harian + auto-renew domain + jangan simpan kredensial di repo |
| Aplikasi versi lama di HP teknisi rusak saat backend update | API berversi (`/api/v1`) dan perubahan bersifat aditif |

---

## 6. Langkah 7 hari pertama (checklist konkret)

1. **Hari 1** — Buat repo Mei-V2 (kosong), `flutter create`, dual entry, CI skeleton; buat repo/DB backend baru.
2. **Hari 1** — Minta daftar aset & ruangan ke Telkom Property (Excel): barcode, merk, kategori, lokasi, lantai.
3. **Hari 2** — Laravel + migrasi `schema-v2.sql` + seeder 7 kategori & checklist + `/health`.
4. **Hari 3** — Auth (Sanctum) + envelope + CORS + middleware role + rate limit.
5. **Hari 4** — Impor master data (alat, lokasi, users) + endpoint `kategori/spesifikasi/alat/lokasi`.
6. **Hari 5** — Flutter: data layer + tema (merah Telkom/hitam/putih) + layar Login + Home grid dari API.
7. **Hari 6** — Scan + Detail Alat + Riwayat (jalur baca lengkap) → uji dengan 1 teknisi.
8. **Hari 7** — Demo jalur emas (AC) end-to-end + catat temuan → putuskan lanjut Sprint 2.

**Definisi sukses minggu pertama**: seorang teknisi bisa login dengan NIP, scan satu alat AC, melihat riwayatnya, dan mengisi form 4 field lalu menyimpan — semua data tercatat benar di database.

---

## 7. Perkiraan tenaga & waktu

| Konfigurasi tim | Perkiraan MVP (Sprint 0–3) |
|---|---|
| 1 fullstack (Flutter + Laravel) | ±8–10 minggu |
| 1 Flutter + 1 backend | ±5–6 minggu |
| 1 Flutter + 1 backend + 1 QA paruh waktu | ±4–5 minggu (dengan CI & matriks regresi 9 use case) |

Bila harus memotong: potong **Analytics** di dashboard (Sprint 3), **jangan** potong form dinamis, transaksi simpan, atau laporan — tiga hal itu inti nilai sistem lama.
