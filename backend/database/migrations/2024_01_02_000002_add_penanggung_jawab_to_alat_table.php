<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * M3 — Kolom penugasan alat ke teknisi (ADITIF).
 *
 * `penanggung_jawab` menunjuk ke `users.username` (null bila belum ditugaskan)
 * sehingga Supervisor dapat menandai alat pada papan overdue.
 *
 * PORTABILITAS: jalur SQLite memakai ADD COLUMN native (lihat catatan pada
 * migrasi M1) karena `alat` dirujuk oleh `view_maintenance`.
 */
return new class extends Migration
{
    public function up(): void
    {
        if ($this->isSqlite()) {
            $this->upSqlite();
            return;
        }

        Schema::table('alat', function (Blueprint $table) {
            $table->string('penanggung_jawab', 50)->nullable()->index();
            $table->dateTime('ditugaskan_pada')->nullable();
        });

        Schema::table('alat', function (Blueprint $table) {
            $table->foreign('penanggung_jawab')
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

        Schema::table('alat', function (Blueprint $table) {
            $table->dropForeign(['penanggung_jawab']);
        });

        Schema::table('alat', function (Blueprint $table) {
            $table->dropIndex(['penanggung_jawab']);
            $table->dropColumn(['penanggung_jawab', 'ditugaskan_pada']);
        });
    }

    private function isSqlite(): bool
    {
        return DB::connection()->getDriverName() === 'sqlite';
    }

    private function upSqlite(): void
    {
        DB::statement(
            'ALTER TABLE alat ADD COLUMN penanggung_jawab '
            .'varchar(50) null references users(username) on delete set null'
        );
        DB::statement('ALTER TABLE alat ADD COLUMN ditugaskan_pada datetime null');

        DB::statement('CREATE INDEX alat_penanggung_jawab_index ON alat (penanggung_jawab)');
    }

    private function downSqlite(): void
    {
        DB::statement('DROP INDEX IF EXISTS alat_penanggung_jawab_index');
        DB::statement('ALTER TABLE alat DROP COLUMN ditugaskan_pada');
        DB::statement('ALTER TABLE alat DROP COLUMN penanggung_jawab');
    }
};
