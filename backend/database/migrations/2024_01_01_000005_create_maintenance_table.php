<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('maintenance', function (Blueprint $table) {
            $table->id('id_maintenance');
            $table->dateTime('waktu_maintenance');
            $table->string('barcode_alat', 100);
            $table->string('username', 50);
            $table->foreignId('id_lokasi')->constrained('lokasi', 'id_lokasi');
            $table->foreignId('id_kategori')->nullable()->constrained('kategori', 'id_kategori')->nullOnDelete();
            $table->text('catatan')->nullable();
            $table->enum('kondisi_keseluruhan', ['baik', 'kurang_baik', 'rusak'])->nullable();
            $table->string('client_uuid', 64)->unique(); // idempotency
            $table->timestamps();

            $table->foreign('barcode_alat')->references('barcode_alat')->on('alat')->cascadeOnDelete();
            $table->foreign('username')->references('username')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('maintenance');
    }
};
