<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
| Mei-V2 hanya menyediakan REST API (lihat routes/api.php). Route ini
| dipakai untuk health-check sederhana di root dan tidak dipakai aplikasi.
|
*/

Route::get('/', function () {
    return response()->json([
        'code' => 200,
        'data' => [
            'name' => 'Mei-V2 API',
            'version' => 'v1',
            'docs' => url('/api/v1'),
        ],
        'message' => 'Mei-V2 API aktif.',
    ]);
});
