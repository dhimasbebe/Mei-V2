<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * M2 — Tabel `audit_log` untuk jejak aksi Admin (ADITIF, tabel baru).
 *
 * Hanya menyimpan kolom `created_at` (tanpa `updated_at`) karena baris audit
 * bersifat append-only.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_log', function (Blueprint $table) {
            $table->bigIncrements('id_audit');
            $table->string('actor_username', 50)->index();
            $table->string('aksi', 50);            // create|update|delete|verify|assign|login
            $table->string('entitas', 50);         // users|alat|kategori|lokasi|spesifikasi|maintenance
            $table->string('entitas_id', 100);
            $table->text('detail')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['entitas', 'entitas_id']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_log');
    }
};
