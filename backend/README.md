# Mei-V2 Backend (Laravel 13 + Sanctum 4.3)

REST API untuk aplikasi Mei-V2 (Flutter mobile + dashboard web).

15 endpoint di bawah prefix `/api/v1`, autentikasi Bearer token (Sanctum),
envelope respons seragam `{ code, data, message }`. Diuji dengan
**19 uji / 173 assertion** (`php artisan test`).

## Setup

### Cara cepat (Windows)

Dari akar repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1
```

Script memasang PHP + Composer bila belum ada, mengaktifkan ekstensi,
menjalankan `composer install`, membuat `.env` + `APP_KEY`, lalu `migrate --seed`.

Bila PHP belum ada di sistem, script mengunduh **PHP 8.3.35 NTS portabel** ke
`tools/php/` (di-gitignore, tidak mengubah instalasi PHP sistem) dan menaruh
Composer sebagai `backend/composer.phar`. Hapus `tools/php/` untuk membatalkannya.

Tambahkan `-RunTests` untuk langsung menjalankan uji setelah setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1 -RunTests
```

### Cara manual

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate

# SQLite (default, nol konfigurasi) - berkas dibuat otomatis:
#   database/database.sqlite
php artisan migrate --seed

# atau MySQL/MariaDB: ubah DB_* di .env lalu
# CREATE DATABASE meiv2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
php artisan migrate --seed

php artisan serve --host=0.0.0.0 --port=8000
```

## Uji

```bash
cd backend
php artisan test          # 19 uji, 173 assertion
```

Atau dari akar repo, sekaligus dengan uji kontrak model Dart dan kompilasi app:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Live   # rekam ulang fixture dulu
```

`backend/tools/capture_fixtures.py` merekam respons API sungguhan ke
`app/test/fixtures/`; fixture itulah yang dipakai uji kontrak model Dart.

## Persyaratan

| Perangkat | Versi |
|---|---|
| PHP | >= 8.2 (script memasang 8.3.35 portabel) |
| Laravel | 13.x |
| Sanctum | 4.3 |
| Ekstensi | `openssl`, `pdo`, `mbstring`, `tokenizer`, `curl`, `fileinfo`, `xml`, `dom` |
| Ekstensi DB | `pdo_sqlite` + `sqlite3` (default) atau `pdo_mysql` |
| Composer | 2.x (script memasang 2.10.3) |

## Konfigurasi `.env`

```env
APP_NAME="Mei-V2 API"
APP_URL=http://localhost:8000
APP_TIMEZONE=Asia/Jakarta

# SQLite (default)
DB_CONNECTION=sqlite

# MySQL/MariaDB
# DB_CONNECTION=mysql
# DB_HOST=127.0.0.1
# DB_PORT=3306
# DB_DATABASE=meiv2
# DB_USERNAME=root
# DB_PASSWORD=

SESSION_DRIVER=database
CACHE_STORE=file
QUEUE_CONNECTION=sync

SANCTUM_STATEFUL_DOMAINS=localhost,127.0.0.1,localhost:8080,127.0.0.1:8080
SANCTUM_TOKEN_EXPIRATION=
```

> `SANCTUM_TOKEN_EXPIRATION` kosong berarti token tidak pernah kedaluwarsa —
> cocok untuk perangkat lapangan. Isi dalam **menit** bila ingin token otomatis
> kedaluwarsa (mis. `10080` = 7 hari).

## Endpoint

Prefix: `/api/v1`. Semua endpoint selain `login` memerlukan header
`Authorization: Bearer <token>`.

| Method | Endpoint | Keterangan |
|---|---|---|
| POST | `/auth/login` | → `{ token, user }` |
| POST | `/auth/logout` | Hapus token aktif |
| GET | `/auth/me` | Profil pengguna |
| GET | `/kategori` | 7 kategori + `jumlah_alat` |
| GET | `/kategori/{id}/spesifikasi` | Checklist kategori (form dinamis) |
| GET | `/lokasi` | Daftar ruang + `jumlah_alat` |
| GET | `/alat` | Filter `q`, `id_kategori`, `id_lokasi` |
| GET | `/alat/{barcode}` | Detail alat + `terakhir_maintenance` |
| GET | `/maintenance` | Berpaginasi: `page`, `per_page`, `barcode_alat`, `id_kategori`, `dari`, `sampai` |
| POST | `/maintenance` | Kirim hasil (idempoten) |
| GET | `/maintenance/{id}` | Detail + seluruh checklist |
| GET | `/dashboard/kpi` | Ringkasan KPI |
| GET | `/dashboard/trends` | `?days=7\|30\|90` |
| GET | `/dashboard/distribution` | Jumlah alat per kategori |
| GET | `/dashboard/overdue` | `?limit=10` |

## Format respons

Sukses:

```json
{ "code": 200, "data": { }, "message": "OK" }
```

Gagal (semua error, termasuk 401/403/404/500, memakai bentuk yang sama):

```json
{ "code": 422, "data": null, "message": "…", "errors": { "username": ["…"] } }
```

Paginasi (`GET /maintenance`) menaruh objek paginator Laravel di dalam `data`:

```json
{
  "code": 200,
  "data": {
    "data": [ … ],
    "current_page": 1,
    "last_page": 3,
    "per_page": 20,
    "total": 47
  },
  "message": "OK"
}
```

## Idempotensi pengiriman

`POST /maintenance` mewajibkan `client_uuid` (UUID v4 dari klien). Bila
`client_uuid` sudah pernah tersimpan, server **mengembalikan data yang sudah
ada dengan HTTP 200** — bukan error. Ini membuat pengiriman ulang dari antrean
offline aman dan tidak menggandakan data.

## Basis data

7 tabel + 2 view:

| Tabel | Keterangan |
|---|---|
| `users` | PK `username` (NIP), peran Admin / Teknisi / Supervisor |
| `kategori` | 7 jenis alat + `maintenance_cycle_days` |
| `spesifikasi` | Item checklist per kategori → **sumber form dinamis** |
| `lokasi` | Ruang + lantai |
| `alat` | PK `barcode_alat` |
| `maintenance` | Header sesi pemeliharaan + `client_uuid` unik |
| `detail_maintenance` | Satu baris per item checklist |
| `view_maintenance` | View gabungan (kompatibilitas sistem lama) |
| `detail_view` | View detail + nama spesifikasi |

## Data contoh

`MeiVSeeder` bersifat **idempoten** — boleh dijalankan berulang:

```bash
php artisan db:seed --class=MeiVSeeder
```

Isinya:

- 3 akun: `12345` Admin, `67890` Teknisi, `11111` Supervisor (password: `password`)
- 7 kategori
- **Checklist lengkap untuk ketujuh kategori** (membuktikan model checklist generik)
- 21 alat di 8 lokasi
- Riwayat pemeliharaan 90 hari terakhir — campuran tepat waktu dan overdue,
  plus satu alat (`AC-003`) yang sengaja belum pernah dipelihara

## Pengujian

```bash
php artisan test
```

**19 uji / 173 assertion** memverifikasi kontrak yang dipakai klien Flutter:
envelope respons, penamaan kunci snake_case, paginasi, idempotensi, endpoint
dashboard, keunikan ID spesifikasi lintas kategori, dan pemecahan opsi
`select` dari pemisah `|`.

Selain itu, `app/test/fixtures/` (di repo `app/`) menyimpan respons API asli
hasil `backend/tools/capture_fixtures.py`. Uji kontrak model Dart membandingkan
model Flutter terhadap fixture tersebut — **80 pemeriksaan**. Inilah yang
menemukan dua bug `client_uuid` yang membuat data offline hilang diam-diam.

Rekam ulang fixture dari server sungguhan:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Live
```

## Catatan perawatan

- **Jangan** menambahkan migrasi bawaan Laravel `0001_01_01_000000_create_users_table.php`.
  Tabel `users` sudah didefinisikan di `2024_01_01_000000_create_users_table.php`
  dengan PK `username`.
- Sanctum memuat migrasi `personal_access_tokens` otomatis dari paket.
- `EnsureRole` (`app/Http/Middleware/EnsureRole.php`) tersedia untuk membatasi
  endpoint per peran, mis. `Route::middleware('role:Admin,Supervisor')`.
  Belum dipasang agar dashboard tetap dapat diakses semua pengguna terautentikasi.
- Perhitungan KPI dilakukan di PHP (bukan SQL mentah) agar portabel antara
  SQLite, MySQL, MariaDB, dan PostgreSQL.
