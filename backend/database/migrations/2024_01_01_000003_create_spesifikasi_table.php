<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('spesifikasi', function (Blueprint $table) {
            $table->id('id_spesifikasi');
            $table->foreignId('id_kategori')->constrained('kategori', 'id_kategori')->cascadeOnDelete();
            $table->string('nama_spesifikasi', 100);
            $table->enum('tipe_input', ['text', 'number', 'select'])->default('text');
            $table->string('satuan', 50)->nullable();
            $table->text('opsi')->nullable(); // pipe-separated untuk select
            $table->unsignedInteger('urutan')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('spesifikasi');
    }
};
