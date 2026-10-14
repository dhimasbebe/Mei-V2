# Cara Mengakses Kembali Database MySQL Lama (Mei-V)

> Tujuan: menemukan kembali database MySQL backend PHP lama, mengekspornya sebagai `.sql`, lalu memakainya di Mei-V2 / Laravel.
> Status: **alamat server sudah ditemukan, tapi domainnya sudah mati.** Langkah berikutnya = cari akun hosting.
> Terakhir diperbarui: 14 Oktober 2026.

---

## 0. Hasil pemeriksaan di komputer ini (fakta, bukan dugaan)

| Pemeriksaan | Hasil |
|---|---|
| MySQL/MariaDB server lokal | ❌ tidak terpasang (tidak ada XAMPP / Laragon / WAMP / MySQL) |
| MySQL client (`mysql`, `mysqldump`) | ❌ tidak ada di PATH |
| Docker | ❌ tidak terpasang |
| File `*.sql` milik proyek ini | ❌ tidak ada di disk |
| File `*.php` backend | ❌ tidak ada di disk |
| Proyek Android lama / APK Mei-V di disk | ❌ tidak ada (17 APK lain ada, tapi bukan Mei-V) |

**Kesimpulan**: database lama **bukan lokal**. Dia ada di **hosting/server remote**, di belakang endpoint `*.php` yang dulu dipanggil aplikasi Android.

---

## 1. Status terbaru (hasil verifikasi)

| Item | Hasil |
|---|---|
| Repo `dhimasbebe/Mei-V` | ✅ **sudah kembali** — publik, `size 6160`, branch `master`, bahasa Java, topik `maintenance`, `updated_at 2026-10-13T17:32:30Z` |
| Repo `dhimasbebe/Mei-V2` | ⚠️ masih **size 0** (belum ada commit) |
| **BASE_URL server lama** | ✅ **`https://meivtelpro.my.id/`** (dari `app/src/main/java/com/example/mei_v/api/ApiClient.java`) |
| Domain `meivtelpro.my.id` | ❌ **NXDOMAIN** (DNS Status 3 dari nameserver PANDI `b.dns.id`) — domain tidak ada lagi |
| Situs / endpoint PHP | ❌ tidak terjangkau (`fetch failed`, tidak ada snapshot di Wayback Machine) |
| APK lama di repo | ✅ ada: `app/release/meiv.apk` (5,7 MB) — berguna sebagai referensi perilaku app lama |

**Artinya**: semua endpoint lama (`login.php`, `input_data_ac.php`, dst.) memang ada di `https://meivtelpro.my.id/` — dan sekarang tidak terjangkau karena **domainnya sudah mati**.

> **Penting — domain mati ≠ database hilang.** Domain dan hosting adalah dua hal terpisah. File PHP + database MySQL biasanya **masih ada** di akun hosting; yang hilang hanya "pintu masuk"-nya. Jadi fokusnya sekarang: **temukan akun hosting-nya**, bukan domainnya.

---

## 2. Langkah sekarang: temukan akun hosting

Domain `.my.id` dikelola PANDI dan harganya murah (sering dibundel dengan paket hosting Indonesia), jadi kemungkinan besar ada akun hosting yang pernah dipakai.

### 2.1 Cari bukti kepemilikan akun hosting
Cari di email (termasuk email lama) dengan kata kunci:
- `meivtelpro` · `my.id` · `hosting` · `invoice` · `perpanjangan` · `renewal` · `cPanel`
- Nama provider umum: **Niagahoster, Rumahweb, Hostinger, Dewaweb, IDCloudHost, Domainesia, Jagoan Hosting, Masterweb, Qwords**

Email invoice/perpanjangan berisi nama provider, ID pelanggan, dan nama paket — itu kunci untuk login ke member area.

### 2.2 Cara lain menemukan provider
- Riwayat browser: `chrome://history` → cari `cpanel`, `phpmyadmin`, `niagahoster`, `rumahweb`, dll.
- WhatsApp/email ke rekan/klien yang dulu meminta aplikasi ini.
- Riwayat transaksi/mutasi rekening untuk pembayaran hosting (kalau ingat kira-kira tahunnya).
- Folder "backup" di Google Drive / OneDrive / Dropbox.

### 2.3 Kalau provider hosting sudah ketemu
Login ke **member area provider** (bukan domain proyek). Dari situ:

| Kondisi akun | Tindakan |
|---|---|
| **Masih aktif** | Buka **cPanel** dari member area (bisa diakses lewat IP / temporary URL — domain tidak dibutuhkan) → **phpMyAdmin** → pilih database → **Export** → SQL |
| **Masih aktif + ada SSH** | `mysqldump -u <DB_USER> -p --single-transaction --routines --triggers <DB_NAME> > mei_v_backup_20261014.sql` |
| **Sudah expired** | Hubungi **support** dengan bukti invoice → minta restore dari backup terakhir (umumnya disimpan 7–30 hari setelah expired) |
| **Akun tidak ditemukan** | Tanya support apakah ada akun atas nama/email lain; cek kemungkinan akun di provider lain |

**Sekalian catat kredensial DB** — cari file `koneksi.php` / `config.php` di folder yang sama dengan `login.php`:
```php
$host = "localhost";
$user = "<DB_USER>";
$pass = "<DB_PASS>";
$db   = "<DB_NAME>";
```

### 2.4 Soal memperpanjang domain
`.my.id` murah (± Rp15–20 rb/tahun) dan bisa didaftarkan ulang, **tapi memperpanjang domain tidak mengembalikan data** — data ada di hosting. Domain hanya berguna lagi kalau hosting sudah ditemukan dan mau dipakai kembali.

---

## 3. Kalau akun hosting benar-benar tidak bisa dipulihkan

| Jalur | Keterangan |
|---|---|
| Dump `*.sql` lokal | Cek File Manager cPanel, folder `backup`, email lampiran besar, Google Drive |
| Backup otomatis provider | cPanel → **Backup Wizard** (backup harian/mingguan sering masih tersimpan) |
| Rekonstruksi skema | ✅ sudah dibuat: **`docs/db/schema-reconstructed.sql`** (9 tabel + view) |
| Rekonstruksi isi data | ❌ **tidak mungkin** — riwayat maintenance sejak 2022 tidak ada di kode aplikasi |

> Kalau isi data historis penting untuk laporan/tren dashboard, prioritas mutlak tetap menemukan dump atau akun hosting.

---

## 4. Dampak ke rencana Mei-V2 (penting)

Karena backend lama **sudah tidak bisa diakses**, rencana "P0 reuse PHP lama + tambah 5 endpoint" **hanya berlaku jika akun hosting berhasil dipulihkan**.

| Skenario | Rencana backend |
|---|---|
| Hosting + DB berhasil dipulihkan | Tetap: PHP lama + 5 endpoint agregat (P0), lalu Laravel (P1) |
| Hosting tidak bisa dipulihkan | **Berubah: bangun Laravel dari awal sebagai P0** — tidak ada backend lama untuk dipakai ulang. Skema diambil dari `docs/db/schema-reconstructed.sql`; data historis diimpor dari dump kalau ditemukan |

Detail kontingensi: `docs/BACKEND-RECOMMENDATION.md` §4.4.

---

## 5. Setelah database didapat

| Langkah | Keterangan |
|---|---|
| Simpan dump di luar repo | mis. `C:/Users/user/backups/mei-v/` — **jangan** di-commit ke Mei-V2 |
| Siapkan MySQL lokal | Laragon/XAMPP atau Docker MySQL (saat ini belum ada MySQL di komputer ini) |
| Impor ke lokal | `mysql -u root -p <dbname> < mei_v_backup.sql` |
| Isi `.env` Laravel | `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` |
| Tambah kolom baru | `maintenance_cycle_days` (untuk overdue / Q6) via `php artisan migrate` |

---

## Lampiran: tabel yang dibutuhkan Mei-V2

| Tabel | Dipakai oleh | Catatan |
|---|---|---|
| `users` | login.php, formregistrasi.php, updatepassword.php | role: Teknisi / Supervisor / Admin |
| `lokasi` | get_lokasi.php | `id_lokasi`, `nama_lokasi` |
| `alat` | cari_id_alat.php, detail_alat.php | `barcode`, `nama`, `tipe`, `id_lokasi` |
| `maintenance_ac` | input_data_ac.php | suhu_ac, tekanan_ac, ampere_ac, kondisi_ac |
| `maintenance_penangkal_petir` | input_data_petir.php | kondisi_baut, grouding_test |
| `maintenance_panel_listrik` | input_data_panel.php | voltage_rs/rt/st, ampere_rs/rt/st, kondisi_baut |
| `maintenance_apar` | input_data_apar.php | tekanan, selang, nossel |
| `maintenance_alarm` | input_data_alarm.php | smoke_test, heat_test, cek_batre |
| `maintenance_hydrant` | input_data_hydrant.php | tekanan, fungsi |

Field umum tiap tabel maintenance: `waktu_maintenance`, `barcode`, `username`, `id_lokasi`, `catatan`.
