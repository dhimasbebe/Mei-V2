<?php

use App\Http\Controllers\Api\ShareController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
| Mei-V2 hanya menyediakan REST API (lihat routes/api.php). Route ini
| dipakai untuk health-check sederhana di root.
|
| Halaman publik share link (WS O, Fitur Tahap 3) sengaja berada DI SINI —
| di LUAR prefix /api/v1 dan middleware group api (tanpa Sanctum), sehingga
| bisa dibuka tanpa token (AC-O2) dan TIDAK dibungkus envelope JSON
| (lihat docs/DESIGN-FEATURES-V3.md §C.2.1). Respons berupa HTML.
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

// --- Halaman publik tautan bagikan laporan (tanpa auth, HTML) ---
// 404 token salah/cabut/kedaluwarsa ditangani manual di controller
// (response()->view('share.invalid', [], 404)) — BUKAN firstOrFail().
Route::get('/share/{token}', [ShareController::class, 'show']);
