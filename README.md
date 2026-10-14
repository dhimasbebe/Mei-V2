# Mei-V2

Aplikasi pemeliharaan alat **Telkom Property Surabaya Utara** — dibangun ulang dari
aplikasi Android lama (Java) menjadi **Flutter** (mobile) + **dashboard web**
monitoring, dengan backend **Laravel 13**.

> Repo ini adalah penulisan ulang (v2). Repo lama
> [`dhimasbebe/Mei-V`](https://github.com/dhimasbebe/Mei-V) **tidak diubah sama sekali**
> dan hanya dipakai sebagai referensi.

---

## Daftar isi

- [Fitur](#fitur)
- [Struktur repo](#struktur-repo)
- [Mulai cepat](#mulai-cepat)
- [Akun demo](#akun-demo)
- [Endpoint API](#endpoint-api)
- [Verifikasi](#verifikasi)
- [Menjalankan mode pengembangan](#menjalankan-mode-pengembangan)
- [Build manual (tanpa script)](#build-manual-tanpa-script)
- [Catatan desain](#catatan-desain)
- [Pemecahan masalah](#pemecahan-masalah)

---

## Fitur

### Aplikasi mobile (Flutter)

| Fitur | Keterangan |
|---|---|
| Login | NIP + password, token Bearer (Sanctum) |
| Beranda | Grid 7 kategori dengan ikon asli Mei-V |
| Scan barcode | `mobile_scanner` (Code128 / QR) |
| Detail alat | Kode, merk, detail lokasi, status jatuh tempo |
| **Form pemeliharaan dinamis** | Checklist dibangun otomatis dari tabel `spesifikasi` |
| Riwayat | Daftar pemeliharaan per alat |
| Profil | Info pengguna + logout |

### Dashboard web (Flutter Web)

| Fitur | Keterangan |
|---|---|
| KPI | Total alat, kategori, pemeliharaan bulan ini, % tepat waktu, overdue |
| Tren | Grafik garis pemeliharaan (7 / 30 / 90 hari) |
| Distribusi | Pie chart jumlah alat per kategori |
| Daftar overdue | Alat yang melewati siklus, diurutkan paling terlambat |
| Rekaman | Tabel riwayat berpaginasi + filter kondisi |

### Backend (Laravel 13)

- REST API 15 endpoint, prefix `/api/v1`
- Autentikasi **Laravel Sanctum 4.3** (Bearer token)
- Envelope respons seragam `{ code, data, message }` (+ `errors` untuk 422)
- **Idempoten**: `POST /maintenance` memakai `client_uuid` — kirim ulang tidak menggandakan data
- Perhitungan KPI portabel (SQLite / MySQL / MariaDB / PostgreSQL)
- 19 uji, 173 assertion (`php artisan test`)

---

## Struktur repo

```
mei-v2/
├── app/                        # Flutter — mobile + dashboard web
│   ├── lib/
│   │   ├── main.dart           # entry MOBILE
│   │   ├── main_web.dart       # entry DASHBOARD WEB
│   │   ├── core/               # tema, warna, string, config, router
│   │   ├── domain/models/      # model (fromJson/toJson manual, tanpa codegen)
│   │   ├── data/               # api client, service, repositories
│   │   ├── providers/          # Riverpod
│   │   └── presentation/       # layar & widget
│   ├── assets/
│   │   ├── images/             # 7 ikon kategori ASLI Mei-V
│   │   └── logos/              # logoputih / logohitam / logotelpro ASLI
│   ├── android/                # platform Android (Gradle 9.1, AGP 9.0.1, Kotlin 2.3.20)
│   └── web/                    # platform web
│
├── backend/                    # Laravel 13
│   ├── app/
│   │   ├── Http/Controllers/Api/
│   │   ├── Http/Middleware/EnsureRole.php
│   │   ├── Models/
│   │   └── Providers/AppServiceProvider.php
│   ├── database/
│   │   ├── migrations/         # 7 tabel + 2 view
│   │   └── seeders/MeiVSeeder.php
│   ├── routes/api.php
│   └── config/
│
├── scripts/
│   ├── setup-backend.ps1       # pasang & siapkan backend (sekali jalan)
│   ├── verify-all.ps1          # SATU perintah: uji backend + kontrak model + kompilasi app
│   ├── build-app.ps1           # build APK / dashboard web
│   └── run-dev.ps1             # jalankan backend + dashboard sekaligus
│
├── tools/
│   ├── check-scripts.ps1       # validasi semua .ps1 (parse + ASCII + kutip keriting)
│   ├── modelcheck/             # harness uji kontrak model Dart vs JSON Laravel
│   └── php/                    # PHP portabel (diunduh setup-backend.ps1, tidak di-commit)
│
├── docs/                       # PRD, arsitektur, analisis sistem lama, skema DB
└── .github/workflows/ci.yml    # CI: test backend + analyze/build Flutter
```

---

## Verifikasi

Satu perintah memeriksa ketiga lapis sekaligus:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

| Langkah | Yang diperiksa | Hasil acuan |
|---|---|---|
| 1/3 | `php artisan test` | 19 uji, 173 assertion |
| 2/3 | Kontrak model Dart vs JSON Laravel | 80 pemeriksaan |
| 3/3 | `flutter analyze` + kompilasi `main.dart` & `main_web.dart` | 0 error |

Tambahan:

```powershell
# Rekam ulang fixture dari server sungguhan dulu (uji end-to-end paling kuat)
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Live

# Tampilkan toolchain yang terdeteksi lalu keluar
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Check

# Validasi semua skrip PowerShell (parse + ASCII + kutip keriting)
powershell -ExecutionPolicy Bypass -File .\tools\check-scripts.ps1
```

**Langkah 2** membandingkan model Dart dengan JSON **asli** hasil tangkapan API
Laravel (`app/test/fixtures/`), bukan JSON buatan tangan. Uji ini menemukan dua
bug nyata pada generator `client_uuid` — UUID tidak valid karena limpahan int64,
dan UUID kembar dalam milidetik yang sama — yang keduanya menyebabkan data
pemeliharaan offline hilang diam-diam saat sinkronisasi. Lihat
[Catatan desain](#catatan-desain).

**Langkah 3** memakai `gen_kernel` langsung bila `flutter analyze` tidak tersedia,
sehingga kedua entry point tetap diperiksa tipenya tanpa perlu Gradle.

---

## Mulai cepat

### Prasyarat

| Perangkat | Versi | Catatan |
|---|---|---|
| Flutter SDK | 3.44.8 (stable) | Dart 3.12.2 |
| PHP | >= 8.2 | dipasang otomatis oleh script bila belum ada |
| Composer | terbaru | diunduh otomatis oleh script |
| Android SDK | API 36 | hanya untuk build APK |
| JDK | 17 | hanya untuk build APK |

### 1. Siapkan backend

```powershell
cd mei-v2
powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1
```

Script akan memasang PHP + Composer bila perlu, mengaktifkan ekstensi,
menjalankan `composer install`, membuat `.env` + `APP_KEY`, lalu
`migrate --seed`.

**Ingin memakai MySQL** (seperti aplikasi lama)? Buat database dulu, lalu:

```sql
CREATE DATABASE meiv2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1 -UseMysql -RunTests
```

### 2. Build aplikasi

```powershell
# APK Android + dashboard web sekaligus
powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1

# hanya APK, untuk HP fisik (memakai IP LAN komputer)
powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1 -Target apk -Backend device

# hanya dashboard web
powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1 -Target web
```

Hasil build:

| Target | Lokasi |
|---|---|
| APK | `app/build/app/outputs/flutter-apk/app-release.apk` |
| Dashboard web | `app/build/web/` |

### 3. Jalankan

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1
```

Membuka dua jendela: Laravel di `:8000` dan dashboard web di `:8080`.

### 4. Verifikasi

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

Menjalankan uji backend, uji kontrak model Dart, dan kompilasi kedua entry
point Flutter dalam satu perintah. Rincian di [Verifikasi](#verifikasi).

---

## Akun demo

Dibuat oleh `MeiVSeeder`. Password semuanya **`password`**.

| NIP | Peran |
|---|---|
| `12345` | Admin |
| `67890` | Teknisi |
| `11111` | Supervisor |

Data contoh mencakup **7 kategori**, checklist lengkap untuk ketujuhnya,
**21 alat** di 8 lokasi, dan riwayat pemeliharaan 90 hari terakhir sehingga
grafik dashboard langsung terisi.

---

## Endpoint API

Semua respons memakai envelope:

```json
{ "code": 200, "data": { }, "message": "OK" }
```

| Method | Endpoint | Auth | Keterangan |
|---|---|:---:|---|
| `POST` | `/api/v1/auth/login` | - | → `{ token, user }` |
| `POST` | `/api/v1/auth/logout` | ✓ | Hapus token aktif |
| `GET` | `/api/v1/auth/me` | ✓ | Profil pengguna |
| `GET` | `/api/v1/kategori` | ✓ | 7 kategori + `jumlah_alat` |
| `GET` | `/api/v1/kategori/{id}/spesifikasi` | ✓ | Checklist kategori (form dinamis) |
| `GET` | `/api/v1/lokasi` | ✓ | Daftar ruang |
| `GET` | `/api/v1/alat` | ✓ | Filter `q`, `id_kategori`, `id_lokasi` |
| `GET` | `/api/v1/alat/{barcode}` | ✓ | Detail alat + status jatuh tempo |
| `GET` | `/api/v1/maintenance` | ✓ | Berpaginasi + filter tanggal |
| `POST` | `/api/v1/maintenance` | ✓ | Kirim hasil (idempoten via `client_uuid`) |
| `GET` | `/api/v1/maintenance/{id}` | ✓ | Detail + seluruh checklist |
| `GET` | `/api/v1/dashboard/kpi` | ✓ | Ringkasan KPI |
| `GET` | `/api/v1/dashboard/trends?days=30` | ✓ | Deret harian |
| `GET` | `/api/v1/dashboard/distribution` | ✓ | Jumlah alat per kategori |
| `GET` | `/api/v1/dashboard/overdue?limit=10` | ✓ | Alat melewati siklus |

Contoh:

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"12345\",\"password\":\"password\"}"

curl http://localhost:8000/api/v1/kategori \
  -H "Authorization: Bearer <token>"
```

---

## Menjalankan mode pengembangan

### Backend

```bash
cd backend
php artisan serve --host=0.0.0.0 --port=8000
```

### Aplikasi

```bash
cd app

# dashboard web (tanpa perlu Chrome)
flutter run -d web-server --web-port=8080 \
  --target lib/main_web.dart \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Android (emulator)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Android (HP fisik - ganti dengan IP LAN komputer)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
```

> `10.0.2.2` adalah alamat host komputer dilihat dari emulator Android.
> HP fisik harus memakai **IP LAN** komputer dan server dijalankan dengan `--host=0.0.0.0`.

### Pengujian

```bash
cd backend && php artisan test      # 19 uji, 173 assertion
cd app     && flutter test          # uji kontrak model (models_test.dart)
cd app     && flutter analyze       # analisis statis
```

Atau semuanya sekaligus, plus kompilasi kedua entry point:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

---

## Build manual (tanpa script)

<details>
<summary>Perintah lengkap</summary>

**Backend**

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=0.0.0.0 --port=8000
```

**APK**

```bash
cd app
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

**Dashboard web**

```bash
cd app
flutter pub get
flutter build web --release \
  --target lib/main_web.dart \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

</details>

---

## Catatan desain

### Palet warna & logo mengikuti Mei-V asli

Diambil langsung dari `colors.xml` dan `drawable/` aplikasi lama:

| Elemen | Nilai |
|---|---|
| Merah merek | `#CB2400` |
| Top bar | hitam `#000000` |
| Latar | putih |
| Garis tabel | `#AFAFAF` |
| Tombol | pil (radius 50dp) |
| Header tabel | `#CB2400` |

Ikon kategori (`ac.png`, `apar.png`, `fire_alarm.png`, `genset.png`,
`hydrant.png`, `panel_listrik.png`, `penangkal_petir.png`) dan logo
(`logoputih.png`, `logohitam.png`, `logotelpro.png`) dipakai apa adanya.
Ikon peluncur Android dan ikon web dibuat dari logo putih di atas latar `#CB2400`.

### Satu form dinamis, bukan enam

Aplikasi lama memiliki 6 layar form terpisah (AC, Alarm, APAR, Panel, Hydrant,
Petir) yang sebenarnya membaca daftar field dari tabel `spesifikasi`. Mei-V2
memakai **satu** layar form yang dibangun dari data tersebut — menambah jenis
field baru cukup dengan menambah baris di tabel, tanpa mengubah kode.

### Perbaikan tabrakan ID

Pada sistem lama, ID spesifikasi bertabrakan antar kategori (AC dan Hydrant
sama-sama memakai ID 1–2; Alarm dan APAR sama-sama 23–25). Di Mei-V2 setiap
baris `spesifikasi` memiliki ID unik global.

### `client_uuid` — dua bug yang ditemukan uji kontrak

`POST /maintenance` idempoten lewat `client_uuid`. Uji kontrak terhadap JSON
Laravel sungguhan menemukan dua bug pada generatornya:

1. **UUID tidak valid.** `DateTime.now().microsecondsSinceEpoch << 13` melewati
   batas `int64`, menjadi negatif, dan `toRadixString(16)` memancarkan tanda
   minus — menghasilkan `-344e620--344-4-34-a-34--344e62065db`. Server menolak
   seluruh batch.
2. **UUID kembar.** Setelah bug 1 diperbaiki, 3000 UUID beruntun hanya
   menghasilkan 5 nilai unik. `DateTime.now()` di Windows bergranularitas ~1 ms,
   sehingga payload yang dibuat dalam milidetik yang sama identik — dan server
   membuangnya sebagai duplikat. Data pemeliharaan hilang diam-diam.

Perbaikannya: penghitung urut 32-bit yang disebar ke bit atas, lalu empat putaran
xorshift32 per kata keluaran. Satu putaran tidak cukup — selisih kecil pada state
hanya menyebar sebagian, dan 3000 UUID beruntun masih menyisakan ~600 tabrakan.
Hasil akhir: **3000/3000 valid dan unik**, diverifikasi setiap kali `verify-all`
dijalankan.

---

## Pemecahan masalah

**`flutter` tidak dikenali**
Tambahkan `<flutter-sdk>\bin` ke PATH, buka terminal **baru**.

**`php` tidak dikenali setelah pemasangan otomatis**
Tutup terminal, buka terminal baru agar PATH diperbarui, jalankan ulang script.

**Build APK gagal: `Could not determine java version`**
Pasang JDK 17, lalu: `flutter config --jdk-dir="C:\Program Files\Microsoft\jdk-17..."`

**Aplikasi tidak bisa menghubungi API**
- Emulator → `http://10.0.2.2:8000/api/v1`
- HP fisik → IP LAN komputer, server dijalankan dengan `--host=0.0.0.0`
- Pastikan Windows Firewall mengizinkan port 8000

**CORS diblokir di dashboard web**
`backend/config/cors.php` sudah mengizinkan semua origin untuk pengembangan.
Untuk produksi, ganti `allowed_origins` dengan domain asli.

**Ingin mulai ulang database**
```bash
cd backend
php artisan migrate:fresh --seed
```

**`flutter analyze` gagal: `All pipe instances are busy` / `CreateFile failed 231`**
Bukan masalah proyek. Lingkungan yang menyuntikkan hook `CreateFileW` ke proses
anak memblokir peluncuran `git.exe`/`cmd.exe` oleh Flutter. Di terminal biasa hal
ini tidak terjadi. `verify-all.ps1` menanganinya: langkah itu menjadi peringatan,
lalu kompilasi `gen_kernel` tetap memeriksa kedua entry point.

**Skrip PowerShell gagal di-parse dengan pesan aneh**
PowerShell 5.1 membaca `.ps1` UTF-8 **tanpa BOM** sebagai CP1252; tanda kutip
keriting (`"` `"`) lalu dianggap pembatas string. Semua skrip di repo ini wajib
ASCII murni — jalankan `tools\check-scripts.ps1` untuk memeriksanya.

**Ingin tahu kenapa salah satu langkah verifikasi dilewati**
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Check
```
Menampilkan php, dart, flutter, SDK, dan `platform_strong.dill` yang terdeteksi.

---

## Dokumen

| Berkas | Isi |
|---|---|
| `docs/PRD.md` | Kebutuhan produk |
| `docs/ARCHITECTURE.md` | Arsitektur & keputusan teknis |
| `docs/LEGACY-ANALYSIS.md` | Analisis aplikasi lama |
| `docs/PLAN-FLUTTER-LARAVEL.md` | Rencana migrasi |
| `docs/BACKEND-RECOMMENDATION.md` | Alasan pemilihan Laravel |
| `docs/IMPLEMENTATION-ADVICE.md` | Saran penerapan |
| `docs/DB-RECOVERY.md` | Cara memulihkan skema dari sistem lama |
| `docs/db/schema-v2.sql` | Skema basis data v2 |
| `docs/db/schema-reconstructed.sql` | Skema lama yang direkonstruksi |
| `docs/class-diagram.mermaid` | Diagram kelas |
| `docs/sequence-diagram.mermaid` | Diagram sekuens |
| `STATUS.md` | Status implementasi |
| `backend/README.md` | Rincian backend |

---

## Lisensi

Proyek akademik — Tugas Akhir Dhimas Bintang Bagaskara (1201181005).
