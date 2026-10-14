<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * View kompatibilitas dengan sistem lama (view_maintenance, detail_view).
 *
 * CATATAN PORTABILITAS
 * --------------------
 * SQLite TIDAK mendukung `CREATE OR REPLACE VIEW` — hanya `CREATE VIEW`.
 * Karena itu perintah dibedakan per driver: MySQL/MariaDB/PostgreSQL memakai
 * CREATE OR REPLACE, sedangkan SQLite memakai DROP + CREATE.
 *
 * View ini hanya untuk pelaporan langsung di DB; aplikasi Mei-V2 sendiri
 * membaca lewat Eloquent (lihat accessor pada model Maintenance).
 */
return new class extends Migration
{
    private function driver(): string
    {
        return DB::connection()->getDriverName();
    }

    private function createView(string $name, string $select): void
    {
        $replaceable = in_array($this->driver(), ['mysql', 'mariadb', 'pgsql'], true);

        if ($replaceable) {
            DB::statement("CREATE OR REPLACE VIEW {$name} AS {$select}");
            return;
        }

        DB::statement("DROP VIEW IF EXISTS {$name}");
        DB::statement("CREATE VIEW {$name} AS {$select}");
    }

    public function up(): void
    {
        $this->createView('view_maintenance', "
            SELECT
                m.id_maintenance,
                m.waktu_maintenance,
                m.barcode_alat,
                m.username,
                m.id_lokasi,
                m.id_kategori,
                m.catatan,
                m.kondisi_keseluruhan,
                m.client_uuid,
                m.created_at,
                m.updated_at,
                a.merk_alat,
                k.nama AS nama_kategori,
                l.nama_lokasi,
                l.lantai,
                u.nama_users
            FROM maintenance m
            JOIN alat a ON m.barcode_alat = a.barcode_alat
            LEFT JOIN kategori k ON m.id_kategori = k.id_kategori
            LEFT JOIN lokasi l ON m.id_lokasi = l.id_lokasi
            LEFT JOIN users u ON m.username = u.username
        ");

        $this->createView('detail_view', "
            SELECT
                dm.id AS id_detail,
                dm.id_maintenance,
                dm.id_spesifikasi,
                dm.status,
                s.nama_spesifikasi,
                s.satuan,
                s.tipe_input,
                s.urutan
            FROM detail_maintenance dm
            JOIN spesifikasi s ON dm.id_spesifikasi = s.id_spesifikasi
        ");
    }

    public function down(): void
    {
        DB::statement('DROP VIEW IF EXISTS detail_view');
        DB::statement('DROP VIEW IF EXISTS view_maintenance');
    }
};
