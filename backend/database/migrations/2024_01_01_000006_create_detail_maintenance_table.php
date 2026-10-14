<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('detail_maintenance', function (Blueprint $table) {
            $table->id();
            $table->foreignId('id_maintenance')->constrained('maintenance', 'id_maintenance')->cascadeOnDelete();
            $table->foreignId('id_spesifikasi')->constrained('spesifikasi', 'id_spesifikasi')->cascadeOnDelete();
            $table->string('status', 255);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('detail_maintenance');
    }
};
