<?php

use Laravel\Sanctum\Sanctum;

return [

    /*
    | Domain yang dianggap "stateful" (memakai cookie SPA).
    | Aplikasi Flutter mobile & dashboard memakai Bearer token, sehingga
    | daftar ini boleh tetap default/kosong.
    */

    'stateful' => explode(',', env('SANCTUM_STATEFUL_DOMAINS', sprintf(
        '%s%s',
        'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000,::1',
        Sanctum::currentApplicationUrlWithPort(),
    ))),

    'guard' => ['web'],

    /*
    | Menit sampai token kedaluwarsa. `null` = tidak pernah kedaluwarsa
    | (cocok untuk perangkat lapangan yang jarang login ulang).
    */

    'expiration' => env('SANCTUM_TOKEN_EXPIRATION'),

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    'middleware' => [
        'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
        'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
        'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ],

];
