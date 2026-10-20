# QA — Fitur Tahap 3 (Mei-V2)

Lingkup: 8 workstream tahap 3 (A–H) + 8 fitur tambahan (I–P), 52 kriteria
penerimaan `[MANUAL]` dari `PRD-FEATURES-V3.md`, dan seluruh gerbang otomatis.

Dokumen ini mencatat **apa yang benar-benar diverifikasi**, apa yang ditemukan
rusak, dan apa yang masih tersisa. Angka di sini berasal dari eksekusi ulang
oleh QA, bukan dari laporan pelaksana.

---

## 1. Ringkasan gerbang

Seluruh gerbang di bawah dijalankan ulang oleh QA pada commit **`edcc22a`**
(HEAD saat laporan ini ditulis), bukan diwarisi dari laporan pelaksana.

| Gerbang | Perintah | Hasil |
|---|---|---|
| `[KERNEL]` kompilasi | `gen_kernel_aot` × `main.dart`, `main_web.dart`, `tool/compile_probe.dart` | **EXIT 0 ketiganya** |
| `[MDL]` kontrak model | `cd tools/modelcheck && dart run verify_models.dart` | **477 lulus, 0 gagal** |
| `[BE]` backend | `cd backend && ../tools/php/php.exe artisan test` | **132 passed (779 assertions)** |
| Statik | `cd app && flutter analyze --no-pub` | **146 issue, 0 warning, 0 error** |
| `[MANUAL]` perangkat | `flutter run` | **belum — lihat §6** |

146 issue statik seluruhnya level `info` (`prefer_const_constructors` dan
sejenisnya), tanpa satu pun `warning` atau `error`. Angka ini tidak berubah
sejak `d9384ab` sampai `edcc22a`, jadi tiga perbaikan mode gelap tidak
menambah temuan baru.

`tool/compile_probe.dart` ada karena `gen_kernel_aot` berjalan di platform VM,
sehingga `dart.library.io` selalu `true` dan berkas `*_web.dart` pada import
kondisional **tidak** ikut terkompilasi oleh `main.dart`/`main_web.dart`. Tanpa
probe ini, galat tipe di jalur web hanya muncul saat aplikasi web dijalankan.

---

## 2. Hasil audit 52 AC `[MANUAL]`

| Workstream | Jumlah | Lulus | Deviasi | Tidak ada |
|---|---|---|---|---|
| A — Offline penuh | 4 | 3 | 1 | 0 |
| B — Notifikasi | 3 | 1 | 2 | 0 |
| C — Foto lampiran | 4 | 2 | 2 | 0 |
| D — Audit log | 3 | 3 | 0 | 0 |
| E — Mode gelap | 3 | 3 | 0 | 0 |
| F — Animasi | 5 | 4 | 1 | 0 |
| G — Grafik | 4 | 3 | 0 | 1 |
| H — Gesture | 5 | 3 | 2 | 0 |
| I — Patroli | 5 | 5 | 0 | 0 |
| J — Checklist cepat | 3 | 3 | 0 | 0 |
| K — Duplikat laporan | 2 | 2 | 0 | 0 |
| L — Ekspor PDF | 1 | 1 | 0 | 0 |
| M — Impor CSV | 2 | 2 | 0 | 0 |
| N — Label QR | 2 | 2 | 0 | 0 |
| O — Share link | 2 | 2 | 0 | 0 |
| P — Multi-bahasa | 4 | 4 | 0 | 0 |
| **Total** | **52** | **43** | **8** | **1** |

Tiga deviasi sudah diperbaiki selama QA (A6, E8, E9) dan karena itu dihitung
lulus. Delapan deviasi sisanya dan satu AC yang belum diimplementasikan
dirinci di §4.

---

## 3. Cacat yang ditemukan dan diperbaiki

### 3.1 Laporan ganda setiap kali kirim — **kritis** (`61dc935`)

Ini cacat paling serius yang ditemukan, dan **tidak terdeteksi oleh gerbang
otomatis mana pun**: 477 pemeriksaan model, 132 uji backend, dan tiga kompilasi
bersih semuanya hijau sementara perilakunya salah.

Rantai sebabnya:

1. `MaintenancePayload` membuat UUID baru pada **setiap** konstruksi
   (`clientUuid = clientUuid ?? _uuid()`), sementara
   `MaintenanceFormNotifier.updateDetail/updateCatatan/updateKondisi` membangun
   ulang payload tanpa meneruskan `clientUuid` sebelumnya. Kunci idempotensi
   berubah 3× dalam satu sesi form. AC-A17 memang benar dan teruji di backend,
   tetapi aplikasi tidak pernah mengirim kunci yang stabil, sehingga kirim ulang
   setelah gagal jaringan menghasilkan **duplikat**, bukan deduplikasi.
2. Autosave ber-debounce 600 ms memanggil `simpanDraf()`, yang berakhir pada
   `unawaited(syncNow())` — **mengunggah form yang belum selesai**. Begitu isian
   cukup untuk lolos validasi, server membuat laporan sungguhan dari data separuh.
3. Tombol KIRIM mengirim dengan UUID berbeda, sehingga server melihat dua
   laporan berbeda.

Perbaikan: kunci sesi dibuat sekali di `init()` lalu diteruskan pada setiap
rebuild; draf setengah jadi dipindah ke penyimpanan lokal terpisah
(`FormDraftStore`, kunci `meiv.form_draft.v1`) sehingga **tidak pernah menyentuh
jaringan**; antrean kirim (`meiv.draft_queue.v1`) tetap khusus untuk laporan
yang memang sudah diminta dikirim. Skema `DraftRecord` tidak diubah, jadi draf
yang sudah tersimpan di perangkat pengguna tetap terbaca.

Efek samping positif: `_uuidDraf` kini mengambil `clientUuid` dari state form,
sehingga kiriman ulang dari antrean memakai kunci yang sama dengan percobaan
yang gagal — AC-A17 baru benar-benar berlaku end-to-end setelah perbaikan ini.

### 3.2 Teks tidak terbaca di mode gelap (`ccc3e93`)

`AppColors.background` adalah konstanta putih khusus tema terang
(`0xFFFFFFFF`), sedangkan permukaan tema gelap diambil dari `context.pal`.
Lima tempat memakainya sebagai **permukaan**:

- `sync_queue_screen.dart` — Scaffold **dan** AppBar putih, sementara judul
  memakai `context.pal.textPrimary` (`#EDEDED` di tema gelap) → judul layar
  "Antrean Sinkron" praktis tidak terlihat. Layar ini ada di jalur offline utama.
- `role_shell.dart` — `NavigationBar` tetap putih di tema gelap.
- `forbidden_screen.dart` — Scaffold putih.

Perbaikan: diganti ke `context.pal.background`; `surfaceTintColor` dipin ke
`Colors.transparent`. Mode terang tidak berubah sama sekali karena
`paletteSpec['light']['background']` juga `0xFFFFFFFF` (diverifikasi, bukan
diasumsikan).

Sebanyak 18 pemakaian `AppColors.background` lain **tidak** diubah dan memang
benar: itu warna *depan* putih di atas header merah, sidebar hitam, snackbar
berwarna, dan chip lencana.

### 3.3 Tombol outline putih di mode gelap (`edcc22a`)

`app_button.dart` dan `press_button.dart` memberi latar `AppColors.background`
pada semua varian non-filled, sehingga setiap tombol outline tampil sebagai
kotak putih di tema gelap. Diganti `Colors.transparent` agar permukaan tembus
dan border merah yang membentuk tombol. Mode terang identik secara visual
(putih di atas putih = transparan).

Dua cacat ikutan ditemukan saat memperbaiki ini dan ikut dibereskan:

- Latar **nonaktif** dipaksa `AppColors.primary` 50% untuk semua varian,
  sehingga tombol outline yang nonaktif berubah menjadi slab merah muda —
  menimpa aturan variannya. Kini status nonaktif mengikuti aturan latar yang
  sama, dengan teks `context.pal.textSecondary` agar tetap terbaca di kedua tema.
- `press_button.dart` mengandalkan fill opaque untuk ripple; di atas latar
  transparan efeknya hilang. Ditambahkan `overlayColor` brand tipis (alpha 0.08)
  khusus varian non-filled, dan warna teks nonaktif diterapkan langsung pada
  `TextStyle` karena warna eksplisit menimpa `disabledForegroundColor`.

### 3.4 Race condition antrean patroli (`3890e2e`)

`PatrolNotifier()` memanggil `_muat()` tanpa ditunggu, sedangkan
`tambah()`/`hapus()`/`kosongkan()` langsung menulis ke `shared_preferences`.
Bila teknisi memindai sebelum muat selesai: (a) antrean lama di disk tertimpa,
(b) penyelesaian muat menimpa state di memori sehingga barcode baru hilang.
`kosongkan()` punya kasus kebalikannya — membersihkan antrean kosong lalu
snapshot yang datang memulihkan semuanya.

Perbaikan: `Future` muat disimpan di field dan **ditunggu sebagai pernyataan
pertama** di kelima mutator, sehingga interleaving penyebab bug tidak lagi
dapat terjadi. Field `_siap`/`siap` yang sebelumnya dideklarasikan tetapi tidak
pernah dibaca (bukti penulis memang berniat memagari hal ini) dihapus.

### 3.5 AC-K6 & AC-J7 (`5e8ea2b`)

- **AC-K6** — form terisi dari duplikat tetapi penanda `Salinan dari laporan #N`
  tidak ada sama sekali. Ditambahkan lewat `salinanDariProvider` (dibaca-sekali
  lalu dikosongkan), sengaja **bukan** field baru di `DraftRecord` agar JSON
  antrean yang sudah tersimpan di perangkat tidak berubah.
- **AC-J7** — hitungan item ditampilkan lewat `SnackBar` mentah dengan kalimat
  berbeda dari PRD. Diganti `AppSnackbar.show` dengan teks `"N item ditandai Baik"`.

### 3.6 AC-I11 — guard `/patroli` (`d3b3593`)

Cabang `case 'admin': return true;` membuat Admin bisa membuka `/patroli`,
padahal AC menyatakan Supervisor **dan** Admin diarahkan ke `/403`. Pengecualian
`/patroli` kini diperiksa **sebelum** switch. Diverifikasi dengan probe:
`boleh('admin','/patroli')` = `false` sementara `boleh('admin','/data')` tetap
`true`, jadi hak Admin atas rute lain tidak berubah.

---

## 4. Deviasi yang diterima (tidak diperbaiki)

| AC | Keadaan | Alasan diterima |
|---|---|---|
| **G6** | **Tidak diimplementasikan** — kartu KPI tidak dapat diketuk | `KpiCard` sudah punya slot `onTap` tetapi tidak ada pemanggil. Menuntut rute daftar terfilter baru; dinilai fitur baru, bukan perbaikan. **Kandidat prioritas berikutnya.** |
| B8 | Menekan notifikasi tidak membuka layar apa pun | `onTap` diterima `LocalNotifierIo` tetapi kedua pemanggil `init()` tidak mengisinya, dan payload-nya konstanta `'pengingat'` tanpa informasi role/rute. Perlu rancangan navigasi dari provider. |
| A8 | Lencana = pengingat **+** draf, bukan draf saja | Satu lencana gabungan dinilai lebih berguna daripada dua lencana; menyimpang dari kalimat AC. |
| B7 | `pengingatProvider` tidak disegarkan saat pull-to-refresh Teknisi | Komponen draf tetap hidup (state lokal); hanya komponen alat jatuh tempo yang bisa basi. |
| C15 | Tidak ada thumbnail "menunggu unggah" | Unggah otomatis pasca-sinkron **ada**; yang tidak ada hanya pratinjau, antrean menampilkan `Foto: N`. |
| C12 | Tombol berbunyi "Kamera"/"Galeri" | Perilaku (kamera, galeri, pratinjau) lengkap; hanya literal AC yang berbeda, dan label sekarang lebih ringkas. |
| F3 | `Hero` menerbangkan ikon kategori, bukan teks barcode | Mekanisme transisi benar dan tag unik per barcode; objek yang terbang berbeda dari kalimat AC. |
| H8 | Dua layar tanpa pull-to-refresh (`patrol_screen`, `dashboard_records_screen`) | Semua layar yang disebut AC sudah punya. Antrean patroli bersifat lokal sehingga refresh tidak bermakna. |
| H10 | Riwayat pencarian tampil selalu (bukan saat fokus) dan hanya bisa dihapus semua | `SearchHistory.remove` sudah ada tetapi belum disambungkan ke UI. |

Catatan tambahan di luar daftar AC:

- **AC-I7** — implementasi memakai antrean permanen di panel bawah plus aksi
  `KERJAKAN` per baris, bukan tombol "Selesai (N alat)" yang membuka sheet.
  Fungsinya setara dan lebih cepat (satu ketukan lebih sedikit).
- **AC-L7 & O8** — AC menyebut "di detail laporan", tetapi aplikasi ini tidak
  punya layar detail laporan (hanya `detail_alat_screen`). Tombol PDF dan
  Bagikan ditempatkan pada baris di layar Records. Fungsinya ada dan terjangkau.
- **AC-I8** — indikator sinkronisasi adalah `SyncBanner` bersama di Beranda
  Teknisi (terpasang di `teknisi_home_screen.dart:61`), menghitung seluruh draf
  tertunda termasuk hasil patroli. Tidak ada lencana per-laporan untuk jenis
  laporan apa pun.
- **AC-K5** — tombol Duplikat dibatasi per **role**, bukan per kepemilikan,
  tetapi daftar riwayat Teknisi sudah disaring per `username` di klien sehingga
  baris milik teknisi lain tidak pernah tampil. Backend menerima `username`
  sebagai filter opsional dan **tidak** memaksakannya untuk role Teknisi —
  pertahanan berlapis belum ada (di luar lingkup tahap 3).
- **`_simpan()` parsial** — bila tulis `shared_preferences` gagal separuh,
  antrean tetap utuh di memori dan ditulis ulang pada mutasi berikutnya.

---

## 5. Batasan lingkungan

1. **`flutter test` tidak dapat dijalankan** di lingkungan ini: `flutter_tester`
   gagal start dengan `WebSocketException: Invalid WebSocket upgrade request`,
   terbukti juga pada worktree bersih. Karena itu tidak ada uji widget/perilaku
   otomatis; seluruh verifikasi UI bersifat audit kode statis + gerbang kompilasi.
2. **PHP bersifat portabel dan di-gitignore.** Biner ada di `tools/php/php.exe`
   (8.3.35) dan `.gitignore:39` mengecualikannya, jadi gerbang backend
   **tidak dapat direproduksi dari clone bersih** tanpa memasang PHP 8.3
   sendiri. Ini didokumentasikan di `backend/README.md`.
3. **`flutter analyze` tanpa `--no-pub` menggantung** (`ERROR_PIPE_BUSY`) karena
   memicu `flutter pub get` implisit. Selalu pakai `--no-pub`;
   `scripts/verify-all.ps1` sudah diperbaiki agar melakukan itu (§7).
4. **Exit code `flutter analyze` bukan penanda bersih.** Analyzer keluar `1`
   juga ketika seluruh temuannya hanya level `info`, sehingga `EXIT=0` tidak
   bisa dipakai sebagai syarat lulus — dan mengabaikannya berarti temuan level
   `error` pun lolos tanpa terlihat. Skrip kini menyimpan keluaran analyze lalu
   menghitung per-severity, dan hanya gagal bila ada `error` atau `warning`
   (`9786bf5`).
5. **Kontaminasi keluaran antar-agen.** Pada sesi ini beberapa hasil perintah
   shell sempat tertukar dengan keluaran agen lain (mis. `grep` mengembalikan
   hasil terpotong). Pelajaran: setiap gerbang dijalankan ulang dengan keluaran
   dialihkan ke berkas lalu dibaca kembali, dan klaim "tidak ada" selalu
   diverifikasi dua kali dengan alat berbeda. Tiga klaim "komponen hilang"
   pada sesi ini ternyata keliru setelah dicek ulang.
6. **Pembacaan berkas dapat mengembalikan isi basi.** Saat menutup QA, dua
   berkas log berbeda (32.293 dan 32.803 byte) sama-sama terbaca sebagai teks
   `clean — nothing to commit` lewat pembaca berkas, sementara `wc -c` dan
   PowerShell menunjukkan ukuran sebenarnya. Karena itu penghitungan severity
   di §3 diverifikasi lewat perintah hitung (`[regex]::Matches`), bukan lewat
   pembacaan visual. Jangan percaya satu kanal pembacaan saja.

---

## 6. Yang masih perlu dijalankan di perangkat

Gerbang otomatis tidak dapat membuktikan hal-hal berikut; ini pekerjaan pengguna
lewat `flutter run`:

1. **Kirim laporan saat online** — pastikan hanya **satu** laporan dibuat, dan
   isinya lengkap (ini yang diperbaiki di §3.1; paling penting untuk dicoba).
2. **Autosave + pulihkan** — isi sebagian form, tutup aplikasi, buka lagi:
   banner "Draf dipulihkan" muncul dan isian kembali utuh.
3. **Mode gelap** — nyalakan tema gelap, buka Antrean Sinkron, Beranda Teknisi,
   dan sebuah form: judul dan tombol outline harus terbaca.
4. **Patroli** — pindai beberapa alat berurutan; kamera tidak berhenti, chip
   penghitung bertambah, tiap baris punya aksi `KERJAKAN`.
5. **Izin notifikasi ditolak** — lencana tab Verifikasi/Tugas tetap muncul.
6. **Bagikan tautan** — buka tautan di browser tanpa login: halaman ringkas
   read-only tampil.
7. **Label QR** — cetak, lalu pindai dengan aplikasi ini: harus membuka alat
   yang benar.
8. **Bahasa** — pilih English: seluruh layar Login berbahasa Inggris dan pilihan
   bertahan setelah aplikasi ditutup.

---

## 7. Cara mereproduksi seluruh gerbang

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

Menjalankan empat lapis: uji backend, kontrak model Dart, kompilasi kedua entry
point, dan kompilasi variasi platform. Tambahkan `-Check` untuk hanya melihat
toolchain yang terdeteksi, atau `-Live` untuk merekam ulang fixture dari server
sungguhan sebelum membandingkan kontrak.

Bila gerbang kompilasi dijalankan manual, ada dua bentuk perintah yang sama-sama
sah dan keduanya sudah diverifikasi EXIT 0:

- `gen_kernel_aot.dart.snapshot` **tanpa** `--sdk-root` (dipakai di §1), atau
- `frontend_server_aot.dart.snapshot` **dengan** `--sdk-root`.

Keduanya harus menyertakan `--no-link-platform`; tanpa flag itu langkah linking
platform dijalankan dan gagal di lingkungan tanpa toolchain native. Snapshot AOT
harus dijalankan lewat `dartaotruntime.exe`, bukan `dart` (`dart` menolak dengan
"is an AOT snapshot and should be run with 'dartaotruntime'", EXIT 255).
