<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fitur Tahap 3 (WS O) — tabel `share_links` (ADITIF, tabel baru).
 *
 * Tautan bagikan read-only per laporan pemeliharaan untuk pihak eksternal.
 * Tidak ada perubahan pada tabel lama. Lihat
 * `docs/DESIGN-FEATURES-V3.md` §C.2.2 dan `docs/PRD-FEATURES-V3.md` §O.
 *
 * Catatan desain:
 * - `token` acak >= 32 karakter (Str::random(40)), unique index.
 * - Pencabutan BERSIFAT SOFT: `revoked_at` diisi, baris dipertahankan
 *   untuk jejak audit (R12).
 * - `expires_at` opsional (null = tanpa kedaluwarsa).
 * - Hanya `created_at` (append-only, tidak pernah diupdate).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('share_links', function (Blueprint $table) {
            $table->bigIncrements('id_share');
            $table->unsignedBigInteger('id_maintenance');
            $table->string('token', 64)->unique();
            $table->string('created_by', 50);       // username pembuat
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('id_maintenance')
                ->references('id_maintenance')->on('maintenance')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('share_links');
    }
};
