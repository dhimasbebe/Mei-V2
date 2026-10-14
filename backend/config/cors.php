<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS)
    |--------------------------------------------------------------------------
    | Dashboard web Mei-V2 dijalankan dari origin berbeda (mis. Flutter Web
    | dev server di http://localhost:8080). Autentikasi memakai Bearer token,
    | bukan cookie, sehingga `supports_credentials` tidak diperlukan.
    |
    | Untuk produksi, ganti `allowed_origins` dengan domain asli, mis.:
    |   'allowed_origins' => ['https://dashboard.meiv2.example'],
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'up'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
