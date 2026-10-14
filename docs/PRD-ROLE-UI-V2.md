# PRD — Mei-V2: Redesign UI Berbasis Role + Interaktivitas

> Versi: v2.0 ｜ Penulis: 许清楚 (Xu) — Product Manager ｜ Status: Siap implementasi
> Proyek: `mei-v2/` (Flutter 3.44 mobile + web dashboard, Laravel 13 API)
> Bahasa dokumen: Indonesia ｜ Terminologi domain tetap dalam bahasa Indonesia asli

---

## 1. Ringkasan Eksekutif & Tujuan Produk

Mei-V adalah aplikasi pemeliharaan peralatan (maintenance equipment) untuk **Telkom Property Surabaya Utara**. Versi 2 sudah berjalan secara teknis (Flutter app + web dashboard + Laravel API), namun kualitas UI/UX jauh di bawah ekspektasi pengguna dan tiga role (Admin, Supervisor, Teknisi) memakai tampilan yang **identik** — hanya berbeda label kecil. Selain itu layar Scan menampilkan "hanya tanda seru tanpa apa pun" ketika kamera tidak tersedia atau izin ditolak, tanpa jalan keluar bagi pengguna.

Tujuan produk versi ini:

| # | Tujuan | Ukuran keberhasilan |
|---|---|---|
| G1 | **Pembedaan peran yang nyata** — tiap role punya beranda, navigasi, dan fitur yang benar-benar berbeda, bukan sekadar ganti label | 3 beranda berbeda terpasang; tiap role hanya melihat rute yang diizinkan; guard router per-role aktif |
| G2 | **Interaktivitas & keandalan layar Scan** — hilangkan dead-end "tanda seru" | 100% state kamera (izin/ketersediaan/gagal) punya tampilan + minimal satu jalur keluar; input manual & galeri selalu tersedia |
| G3 | **Identitas visual konsisten & rapi** — memperbaiki proporsi logo, ko-branding Telkom Property, dan konsistensi komponen | Logo Mei-V kompak (60px); logo Telkom Property terlihat jelas; seluruh warna/tipe dari `AppColors`/`AppTheme`; target sentuh >= 48dp |

**Masalah inti yang diselesaikan:** aplikasi terasa "kurang bagus" (proporsi, jarak, animasi, umpan balik kurang), pengalaman rusak saat kamera gagal, dan tiga role tidak dibedakan sehingga alur kerja tiap peran tidak efisien.

---

## 2. Asumsi

Ditulis eksplisit karena sebagian keputusan bisnis belum dikonfirmasi:

1. **Role dropdown bukan autentikasi.** Login tetap NIP + password; backend tetap sumber kebenaran role. Dropdown hanya untuk disambiguasi UX. Bila role yang dipilih tidak cocok dengan role akun di server, login ditolak dengan pesan jelas.
2. **Verifikasi maintenance oleh Supervisor** dianggap fitur baru yang diminta tersirat ("berikan fitur yang berguna"); bila backend belum punya endpoint, fitur ini masuk P1 dan hanya menampilkan status "menunggu verifikasi" tanpa aksi sampai endpoint tersedia (lihat `TEAM-STANDARDS.md` untuk jalur koordinasi).
3. **Manajemen user (CRUD) oleh Admin** diasumsikan ada di backend (endpoint `eng-api` task #6). Bila belum, Admin memakai tampilan read-only dulu.
4. **Offline draft** (kirim ulang saat jaringan kembali) mengandalkan `client_uuid` idempoten yang sudah ada di backend; UI hanya menambah lapisan antrian lokal.
5. **Logo Telkom Property** (`logotelpro.png`) ditempatkan sebagai co-branding di footer login dan header kecil di dashboard web; ini pilihan desain, bukan permintaan eksplisit penempatan.
6. Perangkat target minimum Android 8.0; sebagian perangkat lapangan mungkin **tanpa kamera** atau kamera bermasalah — ditangani sebagai state pertama kelas (first-class state).

---

## 3. Persona & Matriks Fitur per Role

### 3.1 Teknisi — "pelaksana lapangan"

- **Tujuan utama:** menyelesaikan pemeliharaan alat di lokasi secepat mungkin, dengan sesedikit mungkin ketikan.
- **Pekerjaan harian:** datang ke lokasi, scan barcode alat, isi checklist per kategori, kirim; ulangi untuk puluhan alat; kadang di ruang tanpa sinyal.
- **Konteks perangkat:** HP, satu tangan, sering di tempat gelap/ruang mesin.

| # | Fitur | Nilai |
|---|---|---|
| T1 | **Scan barcode** dengan senter, zoom, getar, ganti kamera, input manual, ambil dari galeri | Jalur utama masuk ke alat; tahan terhadap kamera/izin gagal |
| T2 | **Tugas Hari Ini** — daftar alat overdue/terjadwal untuk teknisi tsb, urut jarak/waktu | Menghilangkan kebingungan "mau kerja apa hari ini" |
| T3 | **Form maintenance dinamis** per kategori (checklist dari tabel `spesifikasi`) dengan progres pengisian | Memastikan kelengkapan data |
| T4 | **Draft offline + kirim ulang otomatis** | Data tidak hilang saat sinyal putus |
| T5 | **Riwayat saya** — hanya maintenance milik sendiri, filter tanggal/alat | Koreksi & bukti kerja |
| T6 | **Detail alat** (merk, kategori, lokasi, status overdue, sisa hari) | Konteks sebelum mengisi |
| T7 | **Input manual barcode** sebagai jalur alternatif permanen | Selalu ada jalan bila label rusak |
| T8 | **Profil & ganti password** | Akuntabilitas |

- **Tidak boleh diakses:** dashboard web (KPI/analitik), verifikasi maintenance, manajemen user, master data, data maintenance teknisi lain.

### 3.2 Supervisor — "pengawas eksekusi"

- **Tujuan utama:** memastikan semua alat terpelihara tepat waktu dan kualitas pengisian teknisi dapat dipercaya.
- **Pekerjaan harian:** cek dashboard pagi, tindak lanjuti alat overdue, verifikasi laporan teknisi, buat laporan periode.

| # | Fitur | Nilai |
|---|---|---|
| S1 | **Dashboard KPI** (total alat, maintenance bulan ini, overdue, teknisi aktif) | Gambaran cepat |
| S2 | **Verifikasi maintenance** — setujui/tolak + komentar | Jaminan mutu data |
| S3 | **Papan overdue** dengan aksi tindak lanjut (tandai ditugaskan) | Menutup celah pemeliharaan |
| S4 | **Riwayat seluruh teknisi** dengan filter teknisi/kategori/lokasi/tanggal | Audit |
| S5 | **Analitik tren + distribusi** dengan pemilih periode (7/30/90 hari) | Analisis |
| S6 | **Ekspor laporan** periode (CSV/PDF) | Pelaporan ke manajemen |
| S7 | **Sorotan parameter abnormal** (mis. voltage tiga fasa tidak seimbang) | Prioritisasi risiko |
| S8 | **Profil** | — |

- **Tidak boleh diakses:** manajemen user (buat/hapus/reset), master data (kategori/lokasi/spesifikasi), konfigurasi siklus maintenance.

### 3.3 Admin — "pengelola sistem"

- **Tujuan utama:** menjaga master data, akun, dan konfigurasi tetap benar agar teknisi & supervisor lancar.
- **Pekerjaan harian:** menambah alat/user baru, memperbaiki data, memantau keseluruhan.

| # | Fitur | Nilai |
|---|---|---|
| A1 | **Manajemen user** — CRUD, assign role, reset password | Kontrol akses |
| A2 | **Master data** — kategori, lokasi, spesifikasi/checklist per kategori | Sumber kebenaran data |
| A3 | **Manajemen alat** — CRUD alat + barcode + kaitkan ke kategori/lokasi | Data alat akurat |
| A4 | **Konfigurasi siklus maintenance** per kategori (hari) | Dasar perhitungan overdue |
| A5 | **Dashboard penuh** (KPI, analitik, rekap) | Monitoring menyeluruh |
| A6 | **Riwayat + log audit** (siapa mengubah apa) | Akuntabilitas |
| A7 | **Ekspor laporan** | Pelaporan |
| A8 | **Profil** | — |

- **Tidak boleh diakses:** tidak ada pembatasan fitur; namun aksi destruktif (hapus user/alat) wajib konfirmasi ganda.

### 3.4 Matriks ringkas

| Kemampuan | Teknisi | Supervisor | Admin |
|---|---|---|---|
| Scan & input maintenance | Ya | Lihat saja | Ya |
| Riwayat maintenance | Milik sendiri | Semua | Semua |
| Verifikasi maintenance | Tidak | Ya | Ya |
| Dashboard web (KPI/analitik) | Tidak | Ya | Ya |
| Ekspor laporan | Tidak | Ya | Ya |
| Manajemen user | Tidak | Tidak | Ya |
| Master data & alat | Tidak | Tidak | Ya |
| Konfigurasi siklus | Tidak | Tidak | Ya |

---

## 4. Spesifikasi Redesign per Layar

Format: **Masalah saat ini → Target UX → Elemen wajib → Kriteria penerimaan (rujuk AC).**

### 4.1 Login (`login_screen.dart`, 118 baris)

- **Masalah:** logo Mei-V 100px terlalu besar; logo Telkom Property 28px terlalu kecil; tidak ada dropdown role; tidak ada toggle lihat password; jarak tidak seimbang.
- **Target UX:** komposisi vertikal rapi dan ringan, dua logo berhierarki jelas, form di tengah, aksi jelas.
- **Elemen wajib:** lihat §6.
- **AC:** AC-01 … AC-08.

### 4.2 Beranda per Role (menggantikan satu `home_screen.dart`)

- **Masalah:** satu layar identik untuk semua role; tidak ada navigasi per-role; FAB scan selalu tampil walau tidak relevan.
- **Target UX:** tiga beranda terpisah di balik satu shell navigasi dengan **tab berbeda per role**.
  - **Teknisi:** tab `Tugas Hari Ini` (default), `Scan`, `Riwayat`, `Profil`. FAB scan besar di tengah. Kartu ringkas: jumlah tugas, jumlah overdue miliknya.
  - **Supervisor:** tab `Dashboard`, `Verifikasi` (badge jumlah menunggu), `Riwayat`, `Profil`. FAB tidak ada; aksi utama = meninjau.
  - **Admin:** tab `Dashboard`, `Data` (user/alat/master), `Riwayat`, `Profil`.
- **Elemen wajib:** header sapaan + chip role; kartu ringkas (KPI mikro); skeleton loading; pull-to-refresh; empty state informatif.
- **AC:** AC-09 … AC-16.

### 4.3 Scan (`scan_screen.dart`, 105 baris) — **prioritas utama**

- **Masalah:** hanya `MobileScanner` + kotak + teks; tidak ada penanganan izin/kamera gagal; widget error bawaan MobileScanner memunculkan "tanda seru tanpa apa pun"; tidak ada senter, galeri, input manual, getar, zoom.
- **Target UX:** layar kamera fungsional dengan kontrol lengkap **dan** fallback yang selalu memberi jalan keluar.
- **Elemen wajib:** lihat §5.
- **AC:** AC-17 … AC-28.

### 4.4 Detail Alat (`detail_alat_screen.dart`, 204 baris)

- **Masalah:** kartu info datar dan monoton; tombol aksi kurang hierarki; status overdue sudah ada tapi kurang menonjol; error hanya teks.
- **Target UX:** header hero alat (barcode besar + kategori), kartu status overdue berwarna, ringkasan riwayat terakhir (3 entri) di bawah, tombol aksi jelas.
- **Elemen wajib:** badge status (tepat waktu/terlambat) dengan ikon + warna; tombol primer `ISI FORM MAINTENANCE`, sekunder `LIHAT RIWAYAT`; tombol `Scan Ulang` pada error; skeleton saat memuat.
- **AC:** AC-29 … AC-32.

### 4.5 Form Maintenance (`maintenance_form_screen.dart`, 324 baris)

- **Masalah:** indikator progres tidak ada; validasi hanya via snackbar; tidak ada konfirmasi sebelum kirim; tidak ada penanganan offline.
- **Target UX:** form dengan **progres pengisian** di atas (mis. "5/8 item terisi"), penanda item wajib, tombol kirim nonaktif sampai lengkap, konfirmasi sebelum kirim, status kirim (sukses/gagal/draft tersimpan).
- **Elemen wajib:** progress bar; field per `spesifikasi` (text/number/select); pemilih kondisi keseluruhan (Baik/Kurang Baik/Rusak) dengan warna status; catatan; dialog konfirmasi; snackbar hasil dengan aksi "Lihat Riwayat".
- **AC:** AC-33 … AC-37.

### 4.6 Riwayat (`riwayat_screen.dart`, 182 baris)

- **Masalah:** daftar kartu panjang tanpa filter; tidak ada pemisahan per role; empty state hanya teks; tidak ada pencarian.
- **Target UX:** daftar dengan **filter bar** (teknisi [khusus Supervisor/Admin], kategori, lokasi, rentang tanggal) + pencarian barcode; kartu ringkas; paginasi "Muat lebih banyak"; skeleton; empty state dengan ilustrasi + aksi.
- **Elemen wajib:** filter chip/panel; pull-to-refresh; status verifikasi tampil (bila fitur S2 aktif).
- **AC:** AC-38 … AC-41.

### 4.7 Profil (`profile_screen.dart`, 120 baris)

- **Masalah:** hanya avatar + data + tombol keluar; tidak ada ganti password; tidak ada info versi/instansi.
- **Target UX:** kartu identitas (avatar, nama, role, NIP, email), daftar aksi (ganti password, kebijakan privasi), tombol keluar dengan konfirmasi, footer instansi + logo Telkom Property kecil + versi aplikasi.
- **Elemen wajib:** konfirmasi keluar; tampilan versi dari package info; role sebagai chip berwarna.
- **AC:** AC-42 … AC-44.

### 4.8 Dashboard Web — Overview / Analytics / Records

- **Masalah:** ketiga layar tidak punya navigasi bersama; tidak ada logo/branding konsisten; tidak ada state kosong/error yang ramah; tidak ada responsivitas.
- **Target UX:** **satu shell web** (sidebar navigasi: Overview, Analytics, Records, [Admin: Users, Master Data]) dengan header berlogo Mei-V + Telkom Property.
  - **Overview:** grid KPI (responsif), grafik tren 30 hari, pie distribusi, daftar overdue.
  - **Analytics:** pemilih periode (7/30/90), grafik batang, kartu ringkasan, ekspor.
  - **Records:** tabel dengan filter + pencarian + paginasi + ekspor; kolom kondisi berwarna.
- **Elemen wajib:** skeleton per kartu; empty/error state dengan tombol "Coba Lagi"; sidebar menyesuaikan role; tata letak responsif (>= 1200 / 768–1199 / < 768).
- **AC:** AC-45 … AC-50.

---

## 5. Spesifikasi Khusus Layar Scan

Keluhan utama pengguna: "Saat masuk ke scan barcode juga hanya tanda seru tanpa ada apapun."

### 5.1 Daftar state wajib & perilakunya

| # | State | Pemicu | Perilaku UI | Jalur keluar |
|---|---|---|---|---|
| SC-1 | Izin belum diminta | Pertama kali buka | Layar penjelasan: mengapa kamera dibutuhkan + ilustrasi; tombol `Izinkan Kamera` | `Izinkan` (minta izin), `Input Manual` |
| SC-2 | Izin ditolak (sekali) | User menolak | Pesan: kamera tidak diizinkan; tombol `Coba Lagi` memicu permintaan ulang | `Coba Lagi`, `Input Manual`, `Buka Pengaturan` |
| SC-3 | Izin ditolak permanen | "Jangan tanya lagi" / OS blokir | Pesan: aktifkan kamera di Pengaturan sistem; tombol `Buka Pengaturan` (deep link app settings) | `Buka Pengaturan`, `Input Manual`, `Kembali` |
| SC-4 | Kamera tidak tersedia / tidak ada | Perangkat tanpa kamera, kamera dipakai proses lain | Pesan: kamera tidak tersedia di perangkat ini; arahkan ke input manual | `Input Manual`, `Ambil dari Galeri`, `Kembali` |
| SC-5 | Kamera gagal start | Error `MobileScanner` saat inisialisasi | Tampilkan kartu error (bukan widget default), tombol `Coba Lagi` + `Input Manual` | `Coba Lagi`, `Input Manual`, `Galeri` |
| SC-6 | Barcode tidak dikenali | Frame tidak mengandung barcode valid (timeout ~10 dtk) | Overlay tetap; muncul kartu petunjuk: dekatkan/perjelas cahaya; tombol `Input Manual` | `Input Manual`, `Senter`, `Galeri` |
| SC-7 | Barcode terbaca tapi tidak terdaftar | API `alat/{barcode}` mengembalikan 404 | Dialog: barcode `XXXX` tidak ditemukan; opsi scan ulang / input manual | `Scan Ulang`, `Input Manual` |
| SC-8 | Offline / jaringan gagal | Tidak ada koneksi saat validasi barcode | Banner offline; tawarkan simpan untuk validasi nanti atau input manual | `Coba Lagi`, `Input Manual` |

**Aturan mutlak:** **setiap** state di atas menampilkan teks penjelasan + minimal satu tombol yang dapat ditekan. Tidak boleh ada layar tanpa aksi.

### 5.2 Interaktivitas kamera yang wajib

- **Senter (flash/torch):** tombol toggle, ikon berubah saat aktif.
- **Ganti kamera (depan/belakang):** bila perangkat punya > 1 kamera; sembunyikan bila tidak.
- **Zoom:** slider atau pinch-to-zoom (1x–4x).
- **Garis animasi:** garis scan horizontal bergerak di dalam kotak overlay (animasi loop halus).
- **Getar (haptic):** umpan balik saat barcode terdeteksi (ambang getar pendek).
- **Bunyi (opsional, P1):** beep singkat saat deteksi.
- **Input manual:** selalu tersedia sebagai tombol di app bar dan pada tiap state error.
- **Ambil dari galeri:** pilih gambar dari galeri lalu decode barcode darinya.

### 5.3 Alur sukses

Deteksi -> getar -> overlay dim + spinner -> validasi ke server -> sukses: navigasi ke Detail Alat (animasi transisi) -> gagal (SC-7/SC-8): dialog dengan jalur keluar.

---

## 6. Spesifikasi Login

### 6.1 Hierarki visual

1. **Logo Mei-V** (`logohitam.png` di latar putih): tinggi **60px**, `BoxFit.contain`, horizontal center, margin atas 32px. (Rentang wajar 56–64px; dipilih 60px agar kompak namun terbaca.)
2. **Tagline** di bawah logo: "Maintenance Equipment Information", 13px, `AppColors.textSecondary`.
3. **Form:** field NIP, field Password, dropdown Role, tombol `MASUK`.
4. **Footer ko-branding:** pemisah, lalu **logo Telkom Property** (`logotelpro.png`) tinggi **32px**, diikuti teks "Telkom Property Surabaya Utara", lalu versi aplikasi kecil.

### 6.2 Dropdown Role

- **Opsi:** `Admin`, `Supervisor`, `Teknisi` (3 opsi).
- **Default:** tidak ada seleksi; menampilkan hint `Pilih Role`.
- **Wajib:** validasi sebelum kirim; bila kosong -> pesan `Role wajib dipilih.`
- **Perilaku validasi:** setelah autentikasi berhasil, bandingkan role terpilih dengan `user.roleUsers` dari server.
  - **Cocok:** lanjut ke beranda role tsb.
  - **Tidak cocok:** batalkan sesi, tampilkan error `Role yang dipilih tidak sesuai dengan akun ini.` di banner error, kembali ke login dengan dropdown ter-reset.
- **Catatan:** backend tetap sumber kebenaran; dropdown tidak boleh dipakai untuk menaikkan hak akses.

### 6.3 Field & error

- **Password:** toggle lihat/sembunyikan (ikon mata); `obscureText` awal true.
- **Validasi lokal:** NIP wajib; password minimal 4 karakter.
- **Error server:** banner merah berisi pesan (mis. kredensial salah), dengan ikon; hilang saat input berubah.

### 6.4 Keadaan memuat

- Tombol `MASUK` menampilkan spinner inline, teks tombol nonaktif, seluruh field & dropdown di-`enabled: false` selama proses; mencegah kirim ganda.

---

## 7. Kebutuhan Interaktivitas Menyeluruh

| # | Kebutuhan | Detail |
|---|---|---|
| I1 | Animasi transisi halaman | Transisi geser/fade konsisten antar rute; durasi 200–300 ms |
| I2 | Umpan balik sentuh | `InkWell`/`InkRipple` pada semua elemen interaktif; skala halus pada tombol utama |
| I3 | Skeleton loading | Skeleton (shimmer) menggantikan spinner polos pada daftar/kartu/dashboard |
| I4 | Pull-to-refresh | Pada beranda, riwayat, dashboard |
| I5 | Snackbar | Untuk hasil aksi (sukses/gagal) dengan aksi lanjutan bila relevan |
| I6 | Empty state informatif | Ikon/ilustrasi + penjelasan + tombol aksi, bukan teks polos |
| I7 | Error state dengan aksi | Selalu ada tombol `Coba Lagi` |
| I8 | Umpan balik haptic | Deteksi scan, aksi destruktif, submit sukses |
| I9 | Dialog konfirmasi | Aksi destruktif (hapus, keluar) & submit form |
| I10 | Animasi angka | Kartu KPI beranimasi saat nilai berubah (opsional P1) |

---

## 8. Non-Fungsional

| Kategori | Persyaratan |
|---|---|
| Performa | Beranda tampil < 2 dtk setelah login (jaringan normal); dashboard web first paint < 3 dtk; daftar >= 20 item tetap 60 fps |
| Aksesibilitas | Target sentuh minimal **48dp**; kontras teks memenuhi WCAG AA; dukung pembesaran font sistem; semua ikon punya `semanticLabel` |
| Kompatibilitas | Android 8.0+, iOS 13+, browser modern 2 versi terakhir; perangkat tanpa kamera tetap dapat memakai input manual |
| Ketahanan | Setiap layar wajib punya state loading/error/empty; tidak ada dead-end |
| Konsistensi | Warna & tipografi wajib dari `AppColors`/`AppTheme`; larangan hardcode warna brand; radius tombol pil 50dp |
| Lokalisasi | Teks UI bahasa Indonesia; terminologi domain (alat, lokasi, barcode, catatan) tetap |

---

## 9. Kriteria Penerimaan (testable checklist)

**Login**
- AC-01 Logo Mei-V di login tinggi 60px (toleransi ±2px) dan tidak memenuhi layar.
- AC-02 Logo Telkom Property tampil di footer login dengan tinggi 32px dan teks "Telkom Property Surabaya Utara".
- AC-03 Terdapat dropdown role dengan tepat 3 opsi: Admin, Supervisor, Teknisi.
- AC-04 Dropdown role kosong saat pertama kali; submit tanpa memilih menampilkan `Role wajib dipilih.`
- AC-05 Login dengan role tidak cocok ditolak dengan pesan `Role yang dipilih tidak sesuai dengan akun ini.`
- AC-06 Terdapat toggle lihat/sembunyikan password.
- AC-07 Saat memuat, tombol MASUK menampilkan spinner dan semua input nonaktif.
- AC-08 Kredensial salah menampilkan banner error dan tidak berpindah layar.

**Beranda per role**
- AC-09 Tiga role menghasilkan beranda dengan set tab yang berbeda (Teknisi: Tugas/Scan/Riwayat/Profil; Supervisor: Dashboard/Verifikasi/Riwayat/Profil; Admin: Dashboard/Data/Riwayat/Profil).
- AC-10 Teknisi membuka rute dashboard web -> dialihkan/ditolak (guard per-role).
- AC-11 Supervisor membuka rute manajemen user -> ditolak.
- AC-12 Teknisi hanya melihat riwayat maintenance miliknya sendiri.
- AC-13 Beranda menampilkan skeleton saat memuat data.
- AC-14 Beranda mendukung pull-to-refresh.
- AC-15 Empty state beranda menampilkan penjelasan + tombol aksi.
- AC-16 Badge jumlah "menunggu verifikasi" tampil untuk Supervisor (bila fitur aktif).

**Scan**
- AC-17 Izin belum diminta -> tampil layar penjelasan + tombol `Izinkan Kamera` + `Input Manual`.
- AC-18 Izin ditolak -> tampil penjelasan + `Coba Lagi` + `Buka Pengaturan` + `Input Manual`.
- AC-19 Izin ditolak permanen -> tombol `Buka Pengaturan` membuka pengaturan aplikasi OS.
- AC-20 Perangkat tanpa kamera -> tampil pesan "kamera tidak tersedia" + `Input Manual` + `Ambil dari Galeri`.
- AC-21 Kamera gagal start -> tampil kartu error kustom (bukan widget bawaan) + `Coba Lagi` + `Input Manual`.
- AC-22 Barcode tidak dikenali setelah ~10 dtk -> tampil petunjuk perbaikan + `Input Manual`.
- AC-23 Barcode terbaca tapi tidak terdaftar (404) -> dialog dengan `Scan Ulang` + `Input Manual`.
- AC-24 Mode offline saat validasi -> banner offline + `Coba Lagi` + `Input Manual`.
- AC-25 Tersedia toggle senter dan berfungsi.
- AC-26 Tersedia tombol ganti kamera (disembunyikan bila perangkat berkamera tunggal).
- AC-27 Terdapat garis animasi di dalam kotak scan dan getar saat deteksi.
- AC-28 Tombol `Input Manual` dan `Ambil dari Galeri` selalu dapat dijangkau dari layar scan.

**Detail Alat**
- AC-29 Status overdue/tepat waktu tampil dengan ikon + warna + teks sisa/terlambat hari.
- AC-30 Barcode tidak ditemukan menampilkan tombol `Scan Ulang`.
- AC-31 Saat memuat tampil skeleton.
- AC-32 Tombol `ISI FORM MAINTENANCE` dan `LIHAT RIWAYAT` punya hierarki visual jelas.

**Form Maintenance**
- AC-33 Progres pengisian (mis. "5/8 item terisi") tampil dan terbarui saat mengisi.
- AC-34 Tombol `KIRIM` nonaktif sampai semua item wajib terisi dan kondisi keseluruhan dipilih.
- AC-35 Submit memunculkan dialog konfirmasi sebelum mengirim.
- AC-36 Hasil kirim sukses/gagal ditampilkan via snackbar; sukses menawarkan "Lihat Riwayat".
- AC-37 Saat jaringan gagal, draft disimpan lokal dan dapat dikirim ulang.

**Riwayat**
- AC-38 Terdapat filter (kategori/lokasi/tanggal; teknisi hanya untuk Supervisor/Admin) dan pencarian barcode.
- AC-39 Empty state menampilkan ilustrasi + tombol aksi.
- AC-40 Paginasi "Muat Lebih Banyak" berfungsi.
- AC-41 Skeleton tampil saat pemuatan pertama.

**Profil**
- AC-42 Tombol `KELUAR` memunculkan dialog konfirmasi.
- AC-43 Role pengguna tampil sebagai chip berwarna; versi aplikasi tampil di footer.
- AC-44 Tersedia entri ganti password.

**Dashboard Web**
- AC-45 Shell web menampilkan sidebar dengan item sesuai role.
- AC-46 Header web menampilkan logo Mei-V dan Telkom Property.
- AC-47 Setiap kartu dashboard punya skeleton saat memuat dan tombol `Coba Lagi` saat error.
- AC-48 Tabel Records mendukung filter + pencarian + paginasi.
- AC-49 Tata letak responsif pada lebar >= 1200, 768–1199, dan < 768.
- AC-50 Ekspor laporan periode tersedia untuk Supervisor/Admin.

**Lintas**
- AC-51 Tidak ada warna brand yang di-hardcode di luar `AppColors` (diverifikasi via review/`flutter analyze` bersih).
- AC-52 Semua target sentuh >= 48dp.
- AC-53 `flutter analyze` menghasilkan 0 issue.

---

## 10. Di Luar Lingkup

- Perubahan skema database & endpoint backend di luar kebutuhan role/verifikasi/user management (ditangani task `eng-api`, bukan PRD ini).
- Push notification (P2, belum masuk versi ini).
- Multi-bahasa (P2).
- Unggah foto alat/lampiran maintenance (P2).
- Audit log lengkap dengan UI riwayat perubahan (hanya dicatat sebagai P1 bila backend siap).
- Rilis ke App Store iOS & publikasi toko (di luar lingkup versi ini).
- Redesain aset logo (logo Mei-V & Telkom Property tetap asli, tidak diubah).
