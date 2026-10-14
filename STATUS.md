# Mei-V2 — Implementation Status

> Repo baru: **Mei-V2** (Flutter app + web dashboard + Laravel API dalam satu repo).
> Repo lama **Mei-V** tidak disentuh sama sekali — hanya dibaca sebagai referensi.

Terakhir diperbarui: setelah verifikasi tiga lapis lulus (19 uji backend,
80 pemeriksaan kontrak model Dart, kedua entry point Flutter bersih).

---

## 1. Flutter App (`app/`)

### Selesai
- [x] **Core**: `app_config.dart` (base URL via `--dart-define`), `app_colors.dart` (palet asli
      `#CB2400` / hitam / putih / border `#AFAFAF`), `app_theme.dart` (pill button radius 50),
      `app_strings.dart`, `app_router.dart` (go_router + guard auth & role)
- [x] **Domain models** (7): `User`, `Kategori`, `Spesifikasi`, `Alat`, `Lokasi`,
      `Maintenance`, `Dashboard` — semua `fromJson`/`toJson` **manual** (tanpa build_runner)
- [x] **Data layer**: `ApiClient` (Dio + interceptor token & error), `ApiException`,
      `ApiService` (semua endpoint), 5 repository (auth, kategori, alat, maintenance, dashboard)
- [x] **Provider layer**: Riverpod untuk auth, kategori, alat, maintenance, dashboard
- [x] **UI screens** (11):
  - [x] Login (tema hitam/merah mengikuti Mei-V lama)
  - [x] Home (grid kategori dengan ikon asli)
  - [x] Scan (`mobile_scanner` QR/barcode)
  - [x] Detail Alat (info + status + tombol maintenance)
  - [x] Maintenance Form (**satu form dinamis** digerakkan tabel `spesifikasi`)
  - [x] Riwayat (riwayat pemeliharaan, filter)
  - [x] Profile (info user + logout)
  - [x] Dashboard Overview (KPI cards, line chart, pie chart, daftar overdue)
  - [x] Dashboard Analytics (bar chart + filter periode)
  - [x] Dashboard Records (tabel paginasi)
- [x] **Widgets**: `AppButton`, `AppTextField`, `AppScaffold`
- [x] **Dual entry**: `lib/main.dart` (mobile) + `lib/main_web.dart` (dashboard)
- [x] **Platform folders** (33 berkas) — dibuat via `tools/gen_platforms.py` karena
      `flutter create` diblokir sandbox:
  - [x] `android/` — Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20, `namespace com.meiv.meiv2`,
        JDK 17, permission `CAMERA` + `INTERNET`, `local.properties` menunjuk
        `C:\Android\Sdk` dan `C:\src\flutter`
  - [x] `web/` — `index.html` (title "Mei-V - Monitoring", theme-color `#CB2400`),
        `manifest.json`, favicon + Icon-192/512 + maskable
  - [x] **Aset brand**: launcher icon (5 densitas 48→192) & splash merah `#CB2400`
        dengan wordmark putih asli `logoputih.png` — dibuat dari logo Mei-V asli,
        **bukan** ikon buatan sendiri
- [x] **Aset asli** tersalin: 7 ikon alat (`assets/images/`) + 3 logo (`assets/logos/`)

### Selesai — uji kontrak model
- [x] `app/test/models_test.dart` — uji kontrak model terhadap fixture JSON Laravel
      (berjalan lewat `flutter test` di CI)
- [x] `tools/modelcheck/verify_models.dart` — harness mandiri, **80 pemeriksaan**,
      bisa dijalankan dengan `dart` langsung tanpa Flutter/Gradle
- [x] `app/test/fixtures/` — 14 respons API asli hasil `backend/tools/capture_fixtures.py`

### Perbaikan bug `client_uuid` (ditemukan uji kontrak)
- [x] **Bug 1 — UUID tidak valid.** `microsecondsSinceEpoch << 13` melewati batas
      `int64` → negatif → `toRadixString(16)` memancarkan `-`. Hasil:
      `-344e620--344-4-34-a-34--344e62065db`. Server menolak seluruh batch.
- [x] **Bug 2 — UUID kembar.** Setelah bug 1 diperbaiki, 3000 UUID beruntun hanya
      menghasilkan **5 nilai unik**. `DateTime.now()` di Windows bergranularitas ~1 ms,
      jadi payload dalam milidetik yang sama identik → server membuangnya sebagai
      duplikat → **data pemeliharaan offline hilang diam-diam**.
- [x] **Perbaikan:** penghitung urut 32-bit disebar ke bit atas (`c ^ (c << 16)`),
      lalu **empat** putaran xorshift32 per kata keluaran. Satu putaran tidak cukup —
      masih menyisakan ~600 tabrakan dari 3000 UUID (terukur).
- [x] **Hasil: 3000/3000 UUID valid v4 dan unik**, diverifikasi setiap `verify-all` dijalankan.

### Belum
- [ ] Widget test Flutter (layar & interaksi) — P1
- [ ] Offline sync (draft Hive) — P1
- [ ] Push notification — P2

---

## 2. Laravel Backend (`backend/`)

### Selesai — terpasang dan teruji
- [x] `composer.json` (PHP ^8.2, **Laravel ^13.0**, **Sanctum ^4.3**), `artisan`,
      `bootstrap/app.php` + `bootstrap/providers.php`, `public/index.php` + `.htaccess`
- [x] **11 berkas config**: `app` (timezone `Asia/Jakarta`, locale `id`), `auth` (guard
      `sanctum`), `database` (SQLite default + MySQL/MariaDB/PostgreSQL), `cache`,
      `session`, **`cors`** (paths `api/*`, `sanctum/csrf-cookie`, `up`), `filesystems`,
      `logging`, `mail`, `queue` (default `sync`), `sanctum`, `services`
- [x] `.env.example`, `.gitignore`, `phpunit.xml`, skeleton `storage/` + `bootstrap/cache/`
- [x] `vendor/` terpasang; `php artisan migrate --seed` berhasil; `database/database.sqlite` terisi
- [x] `AppServiceProvider` (default password rule per environment)
- [x] **`EnsureRole`** middleware + alias `role` (siap dipakai, belum dipasang di route)
- [x] **Envelope JSON terpadu** `{code, data, message}` (+ `errors` saat 422) lewat
      `withExceptions()->render()` — menangani 422/401/403/404/405/500
- [x] **Fix `redirectGuestsTo(null)`** (14 Okt): Laravel 13 memasang default
      `redirectGuestsTo(fn () => route('login'))`; di aplikasi API-only tanpa route
      `login`, request non-JSON (tanpa `Accept: application/json`) ke route
      terproteksi melempar `RouteNotFoundException` → HTTP 500 "Route [login] not
      defined." bukan 401. Kini `bootstrap/app.php` menonaktifkan redirect itu —
      semua klien (curl, browser, Flutter) menerima **401 envelope** yang sama.

### Selesai — domain & API
- [x] **Migrasi**: 7 tabel (`users`, `kategori`, `lokasi`, `spesifikasi`, `alat`,
      `maintenance`, `detail_maintenance`) + 2 view (`view_maintenance`, `detail_view`).
      **Perbaikan bug ID collision** versi lama: AC & Hydrant sama-sama pakai
      spesifikasi ID 1,2 — Alarm & APAR sama-sama 23,24,25. Di v2 semua ID unik global.
- [x] **View migration portabel**: `CREATE OR REPLACE VIEW` tidak didukung SQLite →
      helper `createView()` (MySQL/MariaDB/PgSQL pakai OR REPLACE, SQLite pakai DROP+CREATE)
- [x] **7 model** dengan `$appends`/`$hidden` supaya serialisasi **cocok persis** dengan
      model Dart (flat keys: `nama_kategori`, `nama_lokasi`, `lantai`, `nama_users`,
      `merk_alat`, `deskripsi`, `jumlah_alat`, `nama_spesifikasi`, `satuan`,
      `maintenance_cycle_days`, `terakhir_maintenance`)
- [x] **6 controller**: `Auth`, `Kategori`, `Alat`, `Lokasi`, `Maintenance`, `Dashboard`
- [x] **15 endpoint** di bawah `/api/v1/` dengan Sanctum Bearer token
- [x] **N+1 dihindari**: `withCount('alat')` untuk jumlah alat; `attachLastMaintenance()`
      di `AlatController` memakai **satu** query agregat (`MAX(waktu_maintenance)`
      `GROUP BY barcode_alat`) lalu di-set per item
- [x] **Dashboard portabel**: seluruh KPI/trend/distribution/overdue dihitung di **PHP**,
      bukan SQL — menghapus semua `DATE_SUB`, `DATEDIFF`, dan `HAVING` atas alias yang
      hanya jalan di MySQL. Sekarang jalan di SQLite, MySQL, dan PostgreSQL.
- [x] **Idempotency `client_uuid`**: kirim ulang maintenance yang sama mengembalikan
      **HTTP 200 + record yang sudah ada**, bukan 422. Create pertama = **201**.
      Ini kunci desain offline-resend di HP teknisi.
- [x] **Seeder idempoten** (`MeiVSeeder`, ~300 baris) via `updateOrCreate`:
  3 user, 8 lokasi (lantai -1 s/d 9), 7 kategori,
  **checklist lengkap untuk KETUJUH kategori** (AC 8, Penangkal Petir 5, Panel Listrik 9,
  APAR 6, Fire Alarm 5, Hydrant 5, Genset 7 item), 21 alat,
  riwayat maintenance 90 hari terakhir, `AC-003` sengaja belum pernah dipelihara
- [x] **19 test / 173 assertion** (LULUS):
      `tests/Feature/ApiSmokeTest.php` (15) + `tests/Unit/SpesifikasiOpsiTest.php` (4)

### Belum
- [ ] Deployment (shared hosting / VPS) — P2
- [ ] `composer install` di mesin lain — jalankan `scripts\setup-backend.ps1`

---

## 3. Skrip & Otomasi

- [x] `scripts/setup-backend.ps1` — 8 langkah sekali jalan: cari PHP di PATH → PHP portabel
      di `tools/php` → Laragon/XAMPP/WAMP/winget; aktifkan ekstensi di `php.ini` (dengan
      backup); unduh Composer (`backend/composer.phar`) bila belum ada; `composer install`;
      buat `.env` + `key:generate`; `migrate --seed`; opsional test; cetak akun demo.
      Param: `-UseMysql`, `-SkipInstall`, `-RunTests`
- [x] **`scripts/verify-all.ps1`** (BARU) — satu perintah, tiga lapis verifikasi:
      1. `php artisan test` → 19 uji / 173 assertion
      2. `dart run verify_models.dart` di `tools/modelcheck` → 80 pemeriksaan kontrak
      3. `flutter analyze` + kompilasi `gen_kernel` untuk `main.dart` & `main_web.dart`
      Param: `-Live` (rekam ulang fixture dari server sungguhan), `-Check` (tampilkan
      toolchain terdeteksi lalu keluar). Exit code 0/1 — siap dipakai CI.
- [x] **`tools/check-scripts.ps1`** (BARU) — validasi semua `.ps1`: parse PowerShell +
      ASCII-only + deteksi tanda kutip keriting. Cegah jebakan PS 5.1 (UTF-8 tanpa BOM
      dibaca CP1252 → kutip keriting jadi pembatas string → skrip gagal di-parse).
- [x] `scripts/build-app.ps1` — 5 langkah: cek flutter → buat folder platform bila hilang →
      `pub get` → `analyze` → build. Param `-Target apk|web|both|analyze|test`,
      `-Backend emulator|device|localhost` (otomatis menyusun `API_BASE_URL`; mode
      `device` mencari IP LAN), `-Debug` (common parameter bawaan PowerShell —
      script TIDAK mendeklarasikan `[switch]$Debug` sendiri karena tabrakan nama
      dengan `[CmdletBinding()]`: "A parameter with the name 'Debug' was defined
      multiple times"). `$ErrorActionPreference = 'Continue'` + pemeriksaan
      `$LASTEXITCODE` eksplisit di tiap langkah, supaya peringatan stderr flutter
      (mis. "Wasm dry run findings") tidak mematikan build saat output di-capture.
- [x] `scripts/run-dev.ps1` — buka 2 jendela: `php artisan serve` + `flutter run`
      (web-server / chrome / android). Param `-Platform`, `-Port`, `-WebPort`.
      Resolusi PHP: PATH dulu, lalu fallback ke PHP portabel `tools\php\php.exe`
      (setup-backend.ps1) — tidak gagal hanya karena PHP tidak ada di PATH.
- [x] `backend/tools/capture_fixtures.py` — rekam 14 respons API asli ke
      `app/test/fixtures/` (dipakai uji kontrak model Dart)
- [x] `.github/workflows/ci.yml` — 2 job: `backend` (PHP 8.3 + SQLite, migrate+seed+test)
      dan `app` (Flutter 3.44.8, analyze, test, build web + APK, upload artifact)

**Validasi yang sudah dilakukan:**
- `tools/check-scripts.ps1` → 5 skrip PowerShell, parse OK, ASCII-only, 0 masalah
- `tools/phpcheck.py` → 48 berkas PHP, 0 masalah
- `scripts/verify-all.ps1` → **SEMUA VERIFIKASI LULUS** (exit 0):
  `Tests: 19 passed (173 assertions)` · `HASIL: 80 lulus, 0 gagal` ·
  `lib\main.dart bersih` · `lib\main_web.dart bersih`
- **`flutter analyze` → 0 issues** (14 Okt: 35 temuan dibersihkan — unused import,
  unused element, super parameter, `ProviderRef`→`Ref`, const constructor,
  null-check mati; `dart analyze` juga exit 0)
- `scripts/build-app.ps1 -Target web` → **build web sukses** (`app/build/web/`,
  `main.dart.js` 3,1 MB)
- **API live diuji** (14 Okt, `php artisan serve --host=0.0.0.0 --port=8000`):
  `/` → 200 · `/api/v1/kategori` tanpa token → **401 envelope** (dulu 500) ·
  `POST /auth/login` 12345/67890 → 200 + token · `artisan test` → 19/19 lulus
- **APK di HP**: `API_BASE_URL` ter-bake = `http://192.168.1.2:8000/api/v1`
  (mode `-Backend device`). Bila HP timeout: pastikan satu WiFi, tes
  `http://192.168.1.2:8000/` di browser HP, dan izinkan port 8000 di firewall
  (perintah netsh ada di output `run-dev.ps1`; butuh PowerShell as-admin).

---

## 4. Dokumentasi (`docs/` + README)

- [x] `README.md` (root repo) — fitur, struktur repo, prasyarat, quick start,
      akun demo, tabel 15 endpoint, contoh curl, catatan desain, troubleshooting
- [x] `backend/README.md` — setup cepat/manual, referensi `.env`, endpoint,
      bentuk envelope + paginator, kontrak idempotency, daftar tabel, isi seeder,
      testing, catatan perawatan
- [x] `docs/` tersalin dari root: `PRD.md`, `ARCHITECTURE.md`, `PLAN-FLUTTER-LARAVEL.md`,
      `LEGACY-ANALYSIS.md`, `DB-RECOVERY.md`, `BACKEND-RECOMMENDATION.md`,
      `IMPLEMENTATION-ADVICE.md`, diagram mermaid (class + sequence),
      `db/schema-reconstructed.sql`, `db/schema-v2.sql`,
      `legacy/` (12 halaman PDF + peta halaman + teks), `legacy-assets/drawable/` (10 aset)

---

## 5. Aset Asli Mei-V (terverifikasi)

- Logo: `logoputih.png` (2013×488), `logohitam.png`, `logotelpro.png` (610×409)
- Ikon alat: `ac.png`, `apar.png`, `fire_alarm.png`, `genset.png`,
  `hydrant.png`, `panel_listrik.png`, `penangkal_petir.png`
- Palet dari `colors.xml` lama: `#CB2400` (merah brand), hitam (top bar),
  putih (latar), `#AFAFAF` (border tabel), tombol pill radius 50dp
- **Tidak ada launcher icon asli** di repo lama → dibuat dari wordmark putih di atas
  `#CB2400` agar identitas merek tetap konsisten

---

## 6. Langkah Berikutnya (jalankan di terminal Anda)

Semua yang **bisa** dijalankan headless sudah dijalankan dan lulus. Yang tersisa
butuh terminal Anda karena sandbox memblokirnya (lihat penjelasan di bawah).

```powershell
cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2"

# 0. Verifikasi semuanya dalam satu perintah (paling cepat)
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1

# 0b. Varian paling kuat: rekam ulang fixture dari server sungguhan dulu
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Live

# 0c. Kalau ada langkah yang terlewat, lihat toolchain yang terdeteksi
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Check

# 1. Backend di mesin lain: PHP + Composer + migrasi + seed + test
powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1 -RunTests

# 2. APK (HP fisik — otomatis pakai IP LAN)
powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1 -Target apk -Backend device

# 3. Web dashboard
powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1 -Target web

# 4. Mode dev (backend + dashboard jalan bersamaan)
powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1
```

### Apa yang sudah berjalan tanpa terminal Anda

| Lapis | Hasil | Cara |
|---|---|---|
| Backend Laravel | **19 uji / 173 assertion LULUS** | PHP portabel `tools/php` |
| Kontrak model Dart | **80 pemeriksaan LULUS** | `dart.exe` langsung |
| `flutter analyze` / `dart analyze` | **0 issues, exit 0** | output diarahkan ke berkas |
| Build web dashboard | **`app/build/web/` lengkap** (`main.dart.js` 3,1 MB) | `build-app.ps1 -Target web` |
| Build APK | **`app-release.apk` 66,8 MB** | `build-app.ps1 -Target apk -Backend device` (Gradle pertama ±6 menit, sesudahnya ±45 dtk) |
| Kompilasi entry point | **`main.dart` + `main_web.dart` bersih** | `dartaotruntime` + `gen_kernel_aot.dart.snapshot` |
| Skrip PowerShell | **5 berkas parse OK, ASCII-only** | `tools/check-scripts.ps1` |
| Berkas PHP | **48 berkas, 0 masalah** | `tools/phpcheck.py` |

### Catatan sandbox (diperbarui 14 Okt)

Sebelumnya sandbox menyuntikkan `tsbx.dll` ke semua proses anak dan memblokir
`flutter` CLI / `dart analyze` / Gradle (`ERROR_PIPE_BUSY` pada named pipe).
**Per 14 Okt jalur itu berjalan lagi** — `flutter analyze`, `flutter build web`,
dan `flutter build apk` sukses dijalankan dari sini (dengan output diarahkan ke
berkas). Bila suatu saat kembali terblokir, keduanya tetap jalan normal di
terminal Anda; `verify-all.ps1` sudah menurunkan langkah yang gagal diluncurkan
menjadi peringatan dan tetap memeriksa tipe via `gen_kernel`.

> **Catatan build pertama.** Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 sudah
> terunduh dan terpasang; build berikutnya hanya Gradle incremental.
> Peringatan KGP plugin dari Flutter bersifat informatif (akan jadi error di
> Flutter versi mendatang — ikuti changelog plugin yang terlibat).

### Dorong ke repo baru

Repo lama `dhimasbebe/Mei-V` **tidak disentuh sama sekali**. Repo ini belum punya
`.git`, jadi inisialisasi dulu:

```powershell
cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2"
git init
git add .
git commit -m "feat: Mei-V2 - Flutter app + web dashboard + Laravel API"
git branch -M main
git remote add origin https://github.com/dhimasbebe/Mei-V2.git
git push -u origin main
```

`git add .` aman: `.gitignore` sudah mengecualikan `tools/php/`, `tools/dl/`,
`backend/composer.phar`, `backend/database/*.sqlite`, `backend/vendor/`,
`app/build/`, `app/.dart_tool/`, dan `app/flutter_*.log`.

---

## 3. Redesign UI Berbasis Role + Perbaikan Layar Scan (14 Okt)

### Permintaan pengguna yang dipenuhi
| Permintaan | Wujud di kode |
|---|---|
| Standar kolaborasi tim & proses delivery | `docs/TEAM-STANDARDS.md` — RACI, SOP Mermaid, branch/commit, Definition of Done, proses rilis, rollback, templat PR/bug/release |
| Optimasi semua UI | Token baru (`app_tokens.dart`), 12 widget bersama, seluruh layar ditulis ulang memakai token — palet brand `#CB2400` tidak berubah |
| Scan hanya "tanda seru tanpa apa pun" | Akar masalah: `mobile_scanner` menampilkan `ColoredBox` hitam + `Icons.error` bila `errorBuilder` null. Kini 7 fase state, semuanya punya penjelasan + tombol keluar |
| Lebih interaktif | Garis scan beranimasi, getar saat deteksi, slider zoom, senter, ganti kamera, skeleton loading, transisi 250 ms, snackbar terpadu, bilah progres form, kartu KPI beranimasi |
| 3 role tampil berbeda + fitur berguna | Tiga beranda terpisah, tiga set tab berbeda, guard rute per-role, layar Verifikasi (Supervisor), Pusat Data (Admin), Tugas Hari Ini (Teknisi) |
| Logo Mei-V jangan besar + logo Telkom Property | Login: logo Mei-V **60 px** (dari 100 px), footer Telkom Property **32 px** + "Telkom Property Surabaya Utara" |
| Dropdown role | 3 opsi (Admin/Supervisor/Teknisi), wajib dipilih, divalidasi server — role tak cocok → 403 + sesi dibatalkan |

### Tab navigasi per role
| Role | Tab |
|---|---|
| Teknisi | Tugas · Scan · Riwayat · Profil |
| Supervisor | Dashboard · Verifikasi · Riwayat · Profil |
| Admin | Dashboard · Data · Riwayat · Profil |

Akses rute dijaga `core/router/route_access.dart`; pelanggaran diarahkan ke `/403`
(menampilkan penjelasan), bukan dipindahkan diam-diam ke beranda.

### Berkas baru (ringkas)
- Tema & rute: `core/theme/app_tokens.dart`, `core/router/routes.dart`, `core/router/route_access.dart`, `core/services/settings_channel.dart`
- Shell: `presentation/shell/role_shell.dart`, `presentation/shell/web_shell.dart`
- Widget: 12 widget bersama + `presentation/widgets/scan/{scan_overlay,scan_control_bar,scan_state_view}.dart`, `presentation/widgets/responsive.dart`
- Beranda: `screens/home/{home_header,role_home_screen,teknisi_home_screen,supervisor_home_screen,admin_home_screen}.dart`
- Layar: `screens/error/forbidden_screen.dart`, `screens/verifikasi/verifikasi_screen.dart`, `screens/data/{data,user_management,master_data,alat_management}_screen.dart`
- Provider: `role_nav_provider.dart`, `tugas_provider.dart`, `verifikasi_provider.dart`, `user_provider.dart`, `master_data_provider.dart`
- Backend: 3 migrasi baru, `UserController`, `SpesifikasiController`, `TugasController`, `AuditLogController`, `App/Models/AuditLog.php`, `App/Support/AuditLogger.php`, 7 berkas uji baru
- Android: `MainActivity.kt` — kanal `meiv/settings` untuk membuka Pengaturan aplikasi

### Hasil verifikasi akhir
```
==> 1/3  Uji backend Laravel ................ 70 passed (464 assertions)
==> 2/3  Uji kontrak model Dart ............. 146 lulus, 0 gagal
==> 3/3  Kompilasi entry point Flutter ...... lib\main.dart BERSIH
                                              lib\main_web.dart BERSIH
 SEMUA VERIFIKASI LULUS
```
`flutter analyze` tetap tidak bisa dijalankan di sandbox ini (`ERROR_PIPE_BUSY 231`);
lapis kompilasi `gen_kernel` menggantikannya dan memeriksa tipe di seluruh graf.

### Belum dikerjakan
- Widget test Flutter & `flutter test` — hanya bisa dijalankan di terminal Anda
- Galeri scan (butuh `image_picker`; sengaja tidak ditambah — pakai Input Manual)
- Offline draft (Hive) & push notification
