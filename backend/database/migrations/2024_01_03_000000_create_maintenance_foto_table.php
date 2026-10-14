<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fitur Tahap 3 — tabel `maintenance_foto` (ADITIF, tabel baru).
 *
 * Foto lampiran per sesi pemeliharaan. Tidak ada perubahan pada tabel lama
 * (`maintenance`, `users`, `alat`, `kategori`, `lokasi`, `spesifikasi`,
 * `audit_log`). Lihat `docs/DESIGN-FEATURES-V3.md` §10.1.
 *
 * Hanya menyimpan `created_at` (append-only); baris tidak pernah diubah.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('maintenance_foto', function (Blueprint $table) {
            $table->bigIncrements('id_foto');
            $table->unsignedBigInteger('id_maintenance');
            $table->string('path');                 // relatif thd disk 'public'
            $table->string('mime', 50);
            $table->unsignedBigInteger('ukuran');   // byte
            $table->string('username', 50);         // pengunggah (hak akses kepemilikan)
            $table->timestamp('created_at')->useCurrent();

            $table->index('id_maintenance');
            $table->foreign('id_maintenance')
                ->references('id_maintenance')->on('maintenance')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('maintenance_foto');
    }
};
