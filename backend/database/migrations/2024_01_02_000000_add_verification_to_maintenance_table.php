<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * M1 — Kolom verifikasi pada tabel `maintenance` (ADITIF).
 *
 * Menambahkan empat kolom untuk alur verifikasi Supervisor tanpa tabel baru
 * dan tanpa mengubah skema lama. Baris lama otomatis bernilai 'menunggu'
 * sehingga antrean verifikasi langsung berfungsi.
 *
 * PORTABILITAS
 * ------------
 * SQLite tidak dapat menambah FOREIGN KEY lewat ALTER TABLE biasa; Laravel
 * mengatasinya dengan REBUILD tabel, namun rebuild gagal bila ada VIEW yang
 * merujuk `maintenance` (proyek ini punya `view_maintenance`). Karena itu jalur
 * SQLite memakai `ALTER TABLE ... ADD COLUMN` native (REFERENCES inline),
 * sedangkan MySQL/PostgreSQL memakai Schema::table.
 */
return new class extends Migration
{
    public function up(): void
    {
        if ($this->isSqlite()) {
            $this->upSqlite();
            return;
        }

        Schema::table('maintenance', function (Blueprint $table) {
            $table->enum('status_verifikasi', ['menunggu', 'disetujui', 'ditolak'])
                ->default('menunggu')
                ->index();
            $table->string('diverifikasi_oleh', 50)->nullable();
            $table->dateTime('waktu_verifikasi')->nullable();
            $table->text('komentar_verifikasi')->nullable();
        });

        Schema::table('maintenance', function (Blueprint $table) {
            $table->foreign('diverifikasi_oleh')
                ->references('username')
                ->on('users')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        if ($this->isSqlite()) {
            $this->downSqlite();
            return;
        }

        Schema::table('maintenance', function (Blueprint $table) {
            $table->dropForeign(['diverifikasi_oleh']);
        });

        Schema::table('maintenance', function (Blueprint $table) {
            $table->dropIndex(['status_verifikasi']);
            $table->dropColumn([
                'status_verifikasi',
                'diverifikasi_oleh',
                'waktu_verifikasi',
                'komentar_verifikasi',
            ]);
        });
    }

    private function isSqlite(): bool
    {
        return DB::connection()->getDriverName() === 'sqlite';
    }

    private function upSqlite(): void
    {
        DB::statement(
            'ALTER TABLE maintenance ADD COLUMN status_verifikasi '
            ."varchar check (\"status_verifikasi\" in ('menunggu', 'disetujui', 'ditolak')) "
            ."not null default 'menunggu'"
        );
        DB::statement(
            'ALTER TABLE maintenance ADD COLUMN diverifikasi_oleh '
            .'varchar(50) null references users(username) on delete set null'
        );
        DB::statement('ALTER TABLE maintenance ADD COLUMN waktu_verifikasi datetime null');
        DB::statement('ALTER TABLE maintenance ADD COLUMN komentar_verifikasi text null');

        DB::statement('CREATE INDEX maintenance_status_verifikasi_index ON maintenance (status_verifikasi)');
    }

    private function downSqlite(): void
    {
        DB::statement('DROP INDEX IF EXISTS maintenance_status_verifikasi_index');

        foreach (['komentar_verifikasi', 'waktu_verifikasi', 'diverifikasi_oleh', 'status_verifikasi'] as $column) {
            DB::statement("ALTER TABLE maintenance DROP COLUMN {$column}");
        }
    }
};
