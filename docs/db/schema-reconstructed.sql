-- ============================================================
-- Mei-V — Rekonstruksi Skema Database (HASIL DUGAAAN, WAJIB DIVERIFIKASI)
-- ============================================================
-- Sumber rekonstruksi: endpoint Retrofit2 pada aplikasi Android lama
--   app/src/main/java/com/example/mei_v/api/AntarmukaApi.java
--   (login.php, cari_id_alat.php, detail_alat.php, get_lokasi.php,
--    input_data_ac|petir|panel|apar|alarm|hydrant.php,
--    history_maintenance.php, download_report.php)
--
-- ⚠️ PERINGATAN
-- 1. Nama tabel/kolom di bawah ini DITURUNKAN dari nama parameter API,
--    bukan dari dump asli. Nama bisa berbeda (mis. `tbl_alat`, `alat_2`).
-- 2. Tipe data, panjang kolom, index, dan relasi bersifat ASUMSI.
-- 3. Isi data lama TIDAK bisa direkonstruksi — hanya strukturnya.
--    Kalau dump asli ditemukan, PAKAI DUMP ASLI dan hapus file ini.
-- 4. Setelah dump asli didapat, jalankan `SHOW TABLES;` lalu `SHOW CREATE TABLE x;`
--    untuk mengoreksi file ini.
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- ASUMSI A1: 6 jenis maintenance disimpan di 6 tabel terpisah
-- (karena aplikasi memanggil endpoint input_data_*.php yang berbeda).
-- Alternatif yang mungkin: satu tabel `maintenance` dengan banyak kolom
-- nullable + kolom `tipe`. Cek saat dump ditemukan.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 1. users
--    Sumber: login.php (role, username, password),
--            formregistrasi.php (nama, email, role, username, password),
--            updatepassword.php (username, old_password, password)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nama`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(100) NOT NULL,
  -- ASUMSI A2: nilai role belum dikonfirmasi (bisa huruf besar/kecil, bisa juga ada role lain)
  `role`       ENUM('teknisi','supervisor','admin') NOT NULL DEFAULT 'teknisi',
  `username`   VARCHAR(50)  NOT NULL,
  -- ASUMSI A3: panjang 255 mengantisipasi hash (bcrypt/argon).
  -- Kalau dump asli menunjukkan panjang 32/40, berarti MD5/SHA1 — dan perlu di-reset saat migrasi.
  `password`   VARCHAR(255) NOT NULL,
  `created_at` DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_username` (`username`),
  UNIQUE KEY `uq_users_email` (`email`),
  KEY `idx_users_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. lokasi
--    Sumber: get_lokasi.php → id_lokasi dipakai semua endpoint input_data_*
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `lokasi` (
  `id_lokasi`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nama_lokasi` VARCHAR(100) NOT NULL,
  `keterangan`  VARCHAR(255) NULL,
  PRIMARY KEY (`id_lokasi`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. alat (peralatan)
--    Sumber: cari_id_alat.php (barcode) → getAlat(),
--            detail_alat.php?nama= → getDetailAlat(),
--            history_maintenance.php?barcode= → getHistoryMaintenance()
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `alat` (
  `id_alat`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `barcode`           VARCHAR(50)  NOT NULL,          -- dipindai via CaptureAct (QR/barcode)
  `nama`              VARCHAR(100) NOT NULL,          -- dipakai sebagai key di detail_alat.php
  -- ASUMSI A4: `tipe` menentukan form mana yang tampil.
  -- Nilai diduga: AC, Penangkal Petir, Panel Listrik, APAR, Alarm, Hydrant
  `tipe`              VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `tanggal_pemasangan` DATE         NULL,             -- ASUMSI A5: mungkin tidak ada di skema asli
  `keterangan`        VARCHAR(255) NULL,
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_alat`),
  UNIQUE KEY `uq_alat_barcode` (`barcode`),
  KEY `idx_alat_tipe` (`tipe`),
  KEY `idx_alat_lokasi` (`id_lokasi`),
  CONSTRAINT `fk_alat_lokasi` FOREIGN KEY (`id_lokasi`) REFERENCES `lokasi` (`id_lokasi`)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. maintenance_ac  (input_data_ac.php)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_ac` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `suhu_ac`           VARCHAR(20)  NULL,   -- dikirim sebagai string dari aplikasi
  `tekanan_ac`        VARCHAR(20)  NULL,
  `ampere_ac`         VARCHAR(20)  NULL,
  `kondisi_ac`        VARCHAR(50)  NULL,   -- ASUMSI A6: nilai seperti "Baik"/"Rusak"
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ac_barcode_waktu` (`barcode`, `waktu_maintenance`),
  KEY `idx_ac_username` (`username`),
  KEY `idx_ac_lokasi` (`id_lokasi`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. maintenance_penangkal_petir  (input_data_petir.php)
--    perhatikan: nama asli memakai `kondisi_Baut` (B kapital) dan `grouding_test` (salah tulis dari grounding)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_penangkal_petir` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `kondisi_baut`      VARCHAR(50)  NULL,   -- asli: kondisi_Baut
  `grouding_test`     VARCHAR(50)  NULL,   -- asli: grouding_test
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_petir_barcode_waktu` (`barcode`, `waktu_maintenance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. maintenance_panel_listrik  (input_data_panel.php)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_panel_listrik` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `voltage_rs`        VARCHAR(20)  NULL,
  `voltage_rt`        VARCHAR(20)  NULL,
  `voltage_st`        VARCHAR(20)  NULL,
  `ampere_rs`         VARCHAR(20)  NULL,
  `ampere_rt`         VARCHAR(20)  NULL,
  `ampere_st`         VARCHAR(20)  NULL,
  `kondisi_baut`      VARCHAR(50)  NULL,
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_panel_barcode_waktu` (`barcode`, `waktu_maintenance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. maintenance_apar  (input_data_apar.php)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_apar` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `tekanan`           VARCHAR(20)  NULL,
  `selang`            VARCHAR(50)  NULL,
  `nossel`            VARCHAR(50)  NULL,   -- asli: nossel (dari nozzle)
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_apar_barcode_waktu` (`barcode`, `waktu_maintenance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 8. maintenance_alarm  (input_data_alarm.php)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_alarm` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `smoke_test`        VARCHAR(50)  NULL,
  `heat_test`         VARCHAR(50)  NULL,
  `cek_batre`         VARCHAR(50)  NULL,   -- asli: cek_batre (dari baterai)
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_alarm_barcode_waktu` (`barcode`, `waktu_maintenance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 9. maintenance_hydrant  (input_data_hydrant.php)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `maintenance_hydrant` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `waktu_maintenance` DATETIME     NOT NULL,
  `barcode`           VARCHAR(50)  NOT NULL,
  `username`          VARCHAR(50)  NOT NULL,
  `id_lokasi`         INT UNSIGNED NULL,
  `catatan`           TEXT         NULL,
  `tekanan`           VARCHAR(20)  NULL,
  `fungsi`            VARCHAR(50)  NULL,
  `created_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_hydrant_barcode_waktu` (`barcode`, `waktu_maintenance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- CATATAN UNTUK ENDPOINT AGREGAT (P0, lihat BACKEND-RECOMMENDATION.md)
-- ============================================================
-- 1. history_maintenance.php?barcode=  → UNION dari 6 tabel maintenance
--    atau VIEW berikut supaya query dashboard tidak UNION manual:
CREATE OR REPLACE VIEW `v_maintenance_all` AS
SELECT 'AC'              AS tipe, m.* FROM `maintenance_ac`              m
UNION ALL SELECT 'Penangkal Petir' AS tipe, m.* FROM `maintenance_penangkal_petir` m
UNION ALL SELECT 'Panel Listrik'   AS tipe, m.* FROM `maintenance_panel_listrik`   m
UNION ALL SELECT 'APAR'            AS tipe, m.* FROM `maintenance_apar`            m
UNION ALL SELECT 'Alarm'           AS tipe, m.* FROM `maintenance_alarm`           m
UNION ALL SELECT 'Hydrant'         AS tipe, m.* FROM `maintenance_hydrant`         m;

-- 2. Untuk Q6 (overdue / completion rate) perlu kolom siklus per tipe:
--    ALTER TABLE `alat` ADD COLUMN `maintenance_cycle_days` INT NOT NULL DEFAULT 30;
--    (nilai default 30 hari = ASUMSI, tunggu keputusan bisnis)

-- ============================================================
-- ASUMSI YANG HARUS DIVERIFIKASI SAAT DUMP ASLI DITEMUKAN
-- ============================================================
-- A1  Enam tabel maintenance terpisah (vs satu tabel dengan kolom `tipe`)
-- A2  Nilai & penulisan role pada kolom users.role
-- A3  Algoritma hash password (bcrypt/argon vs MD5/SHA1)
-- A4  Nilai pasti kolom `tipe` pada tabel alat
-- A5  Ada/tidaknya kolom tanggal_pemasangan pada alat
-- A6  Nilai domain untuk kolom kondisi_* (Baik/Rusak/Normal/dll)
-- A7  Nama tabel asli (bisa berawalan prefix, mis. `meiv_alat`)
-- A8  Tipe data angka: aplikasi mengirim semuanya sebagai string,
--     jadi kolom asli mungkin VARCHAR walau isinya angka
