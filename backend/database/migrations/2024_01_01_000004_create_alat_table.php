<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alat', function (Blueprint $table) {
            $table->string('barcode_alat', 100)->primary();
            $table->string('merk_alat', 100);
            $table->foreignId('id_kategori')->constrained('kategori', 'id_kategori');
            $table->foreignId('id_lokasi')->nullable()->constrained('lokasi', 'id_lokasi')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alat');
    }
};
