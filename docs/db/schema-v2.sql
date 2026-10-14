-- ============================================================
-- Mei-V2 — Skema Database (VERIFIED dari Buku TA + kode PHP lama)
-- ============================================================
-- Sumber verifikasi:
--   • Tabel 3.13–3.20 Buku TA  → struktur tabel & tipe data
--   • Gambar 3.14–3.16 (ERD/CDM/PDM) → relasi
--   • Kode Program 4.1–4.21 (PHP) → nama tabel/kolom yang BENAR-BENAR dipakai
--     (INSERT INTO maintenance / detail_maintenance, SELECT ... FROM view_maintenance / detail_view)
--
-- Status: struktur ASLI sudah terkonfirmasi. Yang DIPERBAIKI dari sistem lama
--         ditandai komentar "FIX:".
-- Catatan: database lama (hosting meivtelpro.my.id) sudah tidak dapat diakses,
--          file ini menjadi sumber kebenaran struktur saat membangun ulang.
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- 1. users
--    FIX: PK memakai id internal (username tetap UNIQUE, dipakai sebagai NIP)
--    FIX: password 255 untuk bcrypt (lama: Varchar(20) plaintext)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`    VARCHAR(10)  NOT NULL COMMENT 'NIP — dipakai login',
  `nama_users`  VARCHAR(200) NOT NULL,
  `role_users`  VARCHAR(20)  NOT NULL COMMENT 'Admin | Teknisi | Supervisor',
  `password`    VARCHAR(255) NOT NULL COMMENT 'FIX: bcrypt hash (lama: plaintext 20 char)',
  `email_users` VARCHAR(100) NULL,
  `created_at`  DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_username` (`username`),
  KEY `idx_users_role` (`role_users`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. kategori  (jenis alat)
--    FIX: tambah maintenance_cycle_days untuk hitungan OVERDUE (menjawab Q6)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `kategori` (
  `id_kategori`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nama`                   VARCHAR(25)  NOT NULL,
  `deskripsi`              TEXT         NULL COMMENT 'FIX: dipakai layar Detail Alat (deskripsi fungsi alat)',
  `maintenance_cycle_days` INT          NOT NULL DEFAULT 30 COMMENT 'FIX: siklus pemeliharaan (hari) — dasar status overdue',
  PRIMARY KEY (`id_kategori`),
  UNIQUE KEY `uq_kategori_nama` (`nama`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. spesifikasi  (item checklist per kategori → sumber FORM DINAMIS)
--    FIX PALING PENTING: id unik per kategori.
--    Di sistem lama terjadi tabrakan ID (AC & Hydrant sama-sama 1,2;
--    Alarm & APAR sama-sama 23,24,25) sehingga label laporan bisa salah.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `spesifikasi` (
  `id_spesifikasi`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_kategori`      INT UNSIGNED NOT NULL,
  `nama_spesifikasi` VARCHAR(50)  NOT NULL,
  `tipe_input`       ENUM('number','text','select') NOT NULL DEFAULT 'number' COMMENT 'FIX: penentu widget form di Flutter',
  `satuan`           VARCHAR(20)  NULL COMMENT 'FIX: mis. A, V, bar, °C',
  `opsi`             VARCHAR(255) NULL COMMENT 'FIX: pilihan untuk tipe select (mis. Kencang|Kendor)',
  `urutan`           INT          NOT NULL DEFAULT 0,
  `legacy_id`        INT          NULL COMMENT 'ID spesifikasi di sistem lama (untuk migrasi data lama)',
  PRIMARY KEY (`id_spesifikasi`),
  UNIQUE KEY `uq_spesifikasi_kategori_nama` (`id_kategori`, `nama_spesifikasi`),
  KEY `idx_spesifikasi_kategori` (`id_kategori`),
  CONSTRAINT `fk_spesifikasi_kategori` FOREIGN KEY (`id_kategori`) REFERENCES `kategori` (`id_kategori`)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. alat
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `alat` (
  `barcode_alat` VARCHAR(10)  NOT NULL COMMENT 'PK — hasil scan QR/barcode',
  `merk_alat`    VARCHAR(45)  NOT NULL,
  `id_kategori`  INT UNSIGNED NOT NULL,
  `id_lokasi`    INT UNSIGNED NULL COMMENT 'FIX: lokasi default alat (mempercepat form)',
  `aktif`        TINYINT(1)   NOT NULL DEFAULT 1 COMMENT 'FIX: soft status alat',
  `created_at`   DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`barcode_alat`),
  KEY `idx_alat_kategori` (`id_kategori`),
  KEY `idx_alat_lokasi` (`id_lokasi`),
  CONSTRAINT `fk_alat_kategori` FOREIGN KEY (`id_kategori`) REFERENCES `kategori` (`id_kategori`)
    ON UPDATE CASCADE,
  CONSTRAINT `fk_alat_lokasi` FOREIGN KEY (`id_lokasi`) REFERENCES `lokasi` (`id_lokasi`)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. lokasi
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `lokasi` (
  `id_lokasi`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lantai`      INT(3)       NULL,
  `nama_lokasi` VARCHAR(200) NOT NULL,
  PRIMARY KEY (`id_lokasi`),
  KEY `idx_lokasi_nama` (`nama_lokasi`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. maintenance  (header pemeliharaan)
--    FIX: + id_kategori (mempercepat query dashboard; lama hanya bisa
--         menurunkan kategori lewat alat)
--    FIX: + created_by/updated_at untuk audit
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance` (
  `id_maintenance`     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance`  DATETIME     NOT NULL,
  `barcode_alat`       VARCHAR(10)  NOT NULL,
  `username`           VARCHAR(10)  NOT NULL,
  `id_lokasi`          INT UNSIGNED NOT NULL,
  `id_kategori`        INT UNSIGNED NULL COMMENT 'FIX: denormalisasi untuk dashboard',
  `catatan`            VARCHAR(250) NULL,
  `kondisi_keseluruhan` ENUM('baik','kurang_baik','rusak') NULL COMMENT 'FIX: dipakai KPI dashboard',
  `created_at`         DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_maintenance`),
  KEY `idx_mt_waktu` (`waktu_maintenance`),
  KEY `idx_mt_barcode` (`barcode_alat`, `waktu_maintenance`),
  KEY `idx_mt_username` (`username`),
  KEY `idx_mt_lokasi` (`id_lokasi`),
  KEY `idx_mt_kategori` (`id_kategori`),
  CONSTRAINT `fk_mt_alat`     FOREIGN KEY (`barcode_alat`) REFERENCES `alat` (`barcode_alat`)     ON UPDATE CASCADE,
  CONSTRAINT `fk_mt_users`    FOREIGN KEY (`username`)     REFERENCES `users` (`username`)        ON UPDATE CASCADE,
  CONSTRAINT `fk_mt_lokasi`   FOREIGN KEY (`id_lokasi`)    REFERENCES `lokasi` (`id_lokasi`)      ON UPDATE CASCADE,
  CONSTRAINT `fk_mt_kategori` FOREIGN KEY (`id_kategori`)  REFERENCES `kategori` (`id_kategori`)  ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. detail_maintenance  (nilai per item checklist)
--    FIX: PK komposit (id_maintenance, id_spesifikasi) — lama tidak ada PK,
--         sehingga satu item bisa ter-insert ganda
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `detail_maintenance` (
  `id_maintenance` BIGINT UNSIGNED NOT NULL,
  `id_spesifikasi` INT UNSIGNED    NOT NULL,
  `status`         VARCHAR(25)     NOT NULL COMMENT 'nilai pengukuran / kondisi (mis. 12.5, Kencang)',
  PRIMARY KEY (`id_maintenance`, `id_spesifikasi`),
  KEY `idx_dm_spesifikasi` (`id_spesifikasi`),
  CONSTRAINT `fk_dm_maintenance` FOREIGN KEY (`id_maintenance`) REFERENCES `maintenance` (`id_maintenance`)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_dm_spesifikasi` FOREIGN KEY (`id_spesifikasi`) REFERENCES `spesifikasi` (`id_spesifikasi`)
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- VIEW — mempertahankan kontrak lama agar riwayat & laporan tetap kompatibel
-- ============================================================

-- Pengganti `view_maintenance` (dipakai history_maintenance.php?barcode=)
CREATE OR REPLACE VIEW `view_maintenance` AS
SELECT
  m.id_maintenance,
  m.waktu_maintenance,
  m.barcode_alat,
  a.merk_alat,
  k.id_kategori,
  k.nama            AS nama_kategori,
  m.username,
  u.nama_users,
  m.id_lokasi,
  l.nama_lokasi,
  l.lantai,
  m.catatan,
  s.id_spesifikasi,
  s.nama_spesifikasi,
  s.satuan,
  d.status
FROM maintenance m
JOIN alat         a ON a.barcode_alat  = m.barcode_alat
JOIN kategori     k ON k.id_kategori   = a.id_kategori
JOIN users        u ON u.username      = m.username
JOIN lokasi       l ON l.id_lokasi     = m.id_lokasi
LEFT JOIN detail_maintenance d ON d.id_maintenance = m.id_maintenance
LEFT JOIN spesifikasi        s ON s.id_spesifikasi = d.id_spesifikasi;

-- Pengganti `detail_view` (dipakai download_report.php periode awal–akhir)
-- Kolom dipertahankan persis seperti yang dibaca kode lama.
CREATE OR REPLACE VIEW `detail_view` AS
SELECT
  m.id_maintenance,
  m.waktu_maintenance,
  k.nama        AS nama_kategori,
  a.merk_alat,
  m.barcode_alat,
  u.nama_users,
  l.nama_lokasi,
  m.catatan,
  s.nama_spesifikasi,
  d.status
FROM maintenance m
JOIN alat     a ON a.barcode_alat = m.barcode_alat
JOIN kategori k ON k.id_kategori  = a.id_kategori
JOIN users    u ON u.username     = m.username
JOIN lokasi   l ON l.id_lokasi    = m.id_lokasi
LEFT JOIN detail_maintenance d ON d.id_maintenance = m.id_maintenance
LEFT JOIN spesifikasi        s ON s.id_spesifikasi = d.id_spesifikasi;

-- View bantu untuk endpoint agregat dashboard (P0)
CREATE OR REPLACE VIEW `v_maintenance_ringkas` AS
SELECT
  m.id_maintenance,
  m.waktu_maintenance,
  DATE(m.waktu_maintenance) AS tanggal,
  m.barcode_alat,
  a.merk_alat,
  k.id_kategori,
  k.nama        AS nama_kategori,
  k.maintenance_cycle_days,
  m.username,
  u.nama_users,
  m.id_lokasi,
  l.nama_lokasi,
  m.catatan,
  m.kondisi_keseluruhan
FROM maintenance m
JOIN alat     a ON a.barcode_alat = m.barcode_alat
JOIN kategori k ON k.id_kategori  = a.id_kategori
JOIN users    u ON u.username     = m.username
JOIN lokasi   l ON l.id_lokasi    = m.id_lokasi;

-- ============================================================
-- SEED — kategori (7, sesuai grid Menu Utama) & spesifikasi (checklist)
-- ============================================================

INSERT INTO `kategori` (`id_kategori`, `nama`, `deskripsi`, `maintenance_cycle_days`) VALUES
  (1, 'Hydrant',         'Sistem pemadam kebakaran bertekanan yang tersambung ke sumber air.', 30),
  (2, 'AC',              'Air conditioner — pendingin ruangan.',                              30),
  (3, 'APAR',            'Alat pemadam api ringan.',                                          30),
  (4, 'Genset',          'Generator set — sumber listrik cadangan. (ada di rancangan, belum diimplementasikan di aplikasi lama)', 30),
  (5, 'Panel Listrik',   'Membagi, menyalurkan, dan mendistribusikan energi listrik dari sumber (pusat) ke konsumen.', 30),
  (6, 'Fire Alarm',      'Sistem deteksi kebakaran (smoke/heat detector).',                    30),
  (7, 'Penangkal Petir', 'Sistem proteksi petir dan pentanahan (grounding).',                  30);

-- Checklist per kategori. `legacy_id` = ID di sistem lama (untuk migrasi data lama).
INSERT INTO `spesifikasi`
  (`id_kategori`, `nama_spesifikasi`, `tipe_input`, `satuan`, `opsi`, `urutan`, `legacy_id`) VALUES
  -- Hydrant (lama: id 1 & 2 — TABRAKAN dengan AC, kini dipisah)
  (1, 'Tekanan',        'number', 'bar', NULL, 1, 1),
  (1, 'Fungsi',         'select', NULL,  'Baik|Kurang Baik|Rusak', 2, 2),
  -- AC (lama: id 1–4)
  (2, 'Suhu AC',        'number', '°C',  NULL, 1, 1),
  (2, 'Tekanan AC',     'number', 'psi', NULL, 2, 2),
  (2, 'Ampere AC',      'number', 'A',   NULL, 3, 3),
  (2, 'Kondisi AC',     'select', NULL,  'Baik|Kurang Baik|Rusak', 4, 4),
  -- APAR (lama: id 23–25 — TABRAKAN dengan Fire Alarm, kini dipisah)
  (3, 'Tekanan',        'number', 'bar', NULL, 1, 23),
  (3, 'Selang',         'select', NULL,  'Baik|Retak|Rusak', 2, 24),
  (3, 'Nossel',         'select', NULL,  'Baik|Mampet|Rusak', 3, 25),
  -- Genset (BELUM ADA di sistem lama — usulan, perlu konfirmasi)
  (4, 'Level BBM',      'number', '%',   NULL, 1, NULL),
  (4, 'Kondisi Aki',    'select', NULL,  'Baik|Lemah|Rusak', 2, NULL),
  (4, 'Tekanan Oli',    'number', 'psi', NULL, 3, NULL),
  (4, 'Suhu Mesin',     'number', '°C',  NULL, 4, NULL),
  (4, 'Jam Operasi',    'number', 'jam', NULL, 5, NULL),
  -- Panel Listrik (lama: id 13–19)
  (5, 'Voltage R-S',    'number', 'V',   NULL, 1, 13),
  (5, 'Voltage R-T',    'number', 'V',   NULL, 2, 14),
  (5, 'Voltage S-T',    'number', 'V',   NULL, 3, 15),
  (5, 'Ampere R-S',     'number', 'A',   NULL, 4, 16),
  (5, 'Ampere R-T',     'number', 'A',   NULL, 5, 17),
  (5, 'Ampere S-T',     'number', 'A',   NULL, 6, 18),
  (5, 'Kondisi Baut',   'select', NULL,  'Kencang|Kendor|Lepas', 7, 19),
  -- Fire Alarm (lama: id 23–25)
  (6, 'Smoke Test',     'select', NULL,  'Normal|Tidak Berfungsi', 1, 23),
  (6, 'Heat Test',      'select', NULL,  'Normal|Tidak Berfungsi', 2, 24),
  (6, 'Cek Baterai',    'select', NULL,  'Baik|Lemah|Habis', 3, 25),
  -- Penangkal Petir (lama: id 11–12)
  (7, 'Kondisi Baut',   'select', NULL,  'Kencang|Kendor|Lepas', 1, 11),
  (7, 'Grounding Test', 'number', 'Ω',   NULL, 2, 12);

-- ============================================================
-- CATATAN MIGRASI DATA LAMA (kalau dump .sql ditemukan)
-- ============================================================
-- 1. users.password plaintext → WAJIB di-reset (bcrypt). Tidak bisa dikonversi otomatis.
-- 2. Idempotensi insert lama: satu detail bisa ter-insert ganda karena tidak ada PK
--    di detail_maintenance → bersihkan dengan GROUP BY saat impor.
-- 3. Perbaiki tabrakan id_spesifikasi: pakai kolom `legacy_id` untuk memetakan
--    ID lama → ID baru. Contoh:
--      UPDATE detail_maintenance d
--        JOIN maintenance m ON m.id_maintenance = d.id_maintenance
--        JOIN alat a        ON a.barcode_alat   = m.barcode_alat
--        JOIN spesifikasi s ON s.legacy_id = d.id_spesifikasi AND s.id_kategori = a.id_kategori
--      SET d.id_spesifikasi = s.id_spesifikasi;
-- 4. Isi `maintenance.id_kategori` dari alat:
--      UPDATE maintenance m JOIN alat a ON a.barcode_alat = m.barcode_alat
--      SET m.id_kategori = a.id_kategori WHERE m.id_kategori IS NULL;
-- 5. Isi `kondisi_keseluruhan` dari detail ber-tipe select, atau biarkan NULL
--    untuk data historis dan tandai sebagai "tidak diketahui" di dashboard.
-- 6. Alat & lokasi diimpor apa adanya (barcode_alat Varchar(10) tidak diubah
--    agar QR lama tetap terbaca).
