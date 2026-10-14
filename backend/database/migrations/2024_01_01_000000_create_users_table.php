<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabel users kustom Mei-V (menggantikan users bawaan Laravel).
 *
 * PENTING: HAPUS migrasi bawaan Laravel
 * `0001_01_01_000000_create_users_table.php` sebelum menjalankan
 * `php artisan migrate`, karena migrasi ini menggantikannya.
 *
 * PK = username (NIP), tanpa kolom id/email wajib.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->string('username', 50)->primary(); // NIP
            $table->string('nama_users', 100);
            $table->string('role_users', 20)->default('Teknisi'); // Admin | Teknisi | Supervisor
            $table->string('email_users', 100)->nullable();
            $table->string('password');
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('user_id', 50)->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('users');
    }
};
