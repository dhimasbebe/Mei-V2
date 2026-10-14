<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Aturan minimum password untuk pembuatan/ubah user.
        // Akun hasil seeder tetap memakai "password" (lihat MeiVSeeder).
        //
        // Catatan Laravel 13: `Password::defaults()` sudah TIDAK ada di
        // Illuminate\Support\Facades\Password. Gunakan rule class
        // Illuminate\Validation\Rules\Password (lihat framework
        // src/Illuminate/Validation/Rules/Password.php:148).
        Password::defaults(function () {
            return $this->app->isProduction()
                ? Password::min(8)->letters()->numbers()
                : Password::min(6);
        });
    }
}
