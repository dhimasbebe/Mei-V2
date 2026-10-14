<?php

use App\Http\Controllers\Api\AlatController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\KategoriController;
use App\Http\Controllers\Api\LokasiController;
use App\Http\Controllers\Api\MaintenanceController;
use App\Http\Controllers\Api\SpesifikasiController;
use App\Http\Controllers\Api\TugasController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes Mei-V — prefix final: /api/v1/...
|--------------------------------------------------------------------------
| Laravel 11 otomatis memberi prefix "api" (lihat bootstrap/app.php).
| Di sini kita tambahkan "v1" sehingga URL menjadi /api/v1/...
| Semua endpoint mengembalikan envelope: { code, data, message }
|
| Catatan urutan rute: rute statis (mis. /maintenance/pending) HARUS
| didaftarkan sebelum rute dinamis (/maintenance/{id}) agar tidak tertelan.
|
| Alias middleware `role` sudah terdaftar di bootstrap/app.php
| (App\Http\Middleware\EnsureRole) — jangan diubah.
|
*/

Route::prefix('v1')->group(function () {
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        // --- Auth (semua peran) ---
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/change-password', [AuthController::class, 'changePassword']);

        // --- Master data (baca, semua peran) ---
        Route::get('/kategori', [KategoriController::class, 'index']);
        Route::get('/kategori/{id}/spesifikasi', [KategoriController::class, 'spesifikasi']);
        Route::get('/lokasi', [LokasiController::class, 'index']);

        // --- Alat (baca, semua peran) ---
        Route::get('/alat', [AlatController::class, 'index']);
        Route::get('/alat/{barcode}', [AlatController::class, 'show']);

        // --- Maintenance (baca/tulis dasar) ---
        Route::get('/maintenance', [MaintenanceController::class, 'index']);
        Route::post('/maintenance', [MaintenanceController::class, 'store']);

        // --- Supervisor + Admin: rute STATIS maintenance lebih dulu ---
        Route::middleware('role:Supervisor,Admin')->group(function () {
            Route::get('/maintenance/pending', [MaintenanceController::class, 'pending']);
            Route::get('/maintenance/pending/count', [MaintenanceController::class, 'pendingCount']);
            Route::get('/maintenance/overdue', [MaintenanceController::class, 'overdue']);
            Route::post('/maintenance/{id}/verify', [MaintenanceController::class, 'verify']);

            Route::post('/alat/{barcode}/assign', [AlatController::class, 'assign']);

            Route::get('/dashboard/export', [DashboardController::class, 'export']);
            Route::get('/dashboard/parameter-abnormal', [DashboardController::class, 'parameterAbnormal']);
        });

        // --- Maintenance dinamis ---
        Route::get('/maintenance/{id}', [MaintenanceController::class, 'show']);

        // --- Dashboard (Supervisor + Admin) ---
        Route::get('/dashboard/kpi', [DashboardController::class, 'kpi']);
        Route::get('/dashboard/trends', [DashboardController::class, 'trends']);
        Route::get('/dashboard/distribution', [DashboardController::class, 'distribution']);
        Route::get('/dashboard/overdue', [DashboardController::class, 'overdue']);

        // --- Teknisi ---
        Route::get('/tugas-hari-ini', [TugasController::class, 'today'])
            ->middleware('role:Teknisi');

        // --- Admin: manajemen user ---
        Route::middleware('role:Admin')->group(function () {
            Route::get('/users', [UserController::class, 'index']);
            Route::post('/users', [UserController::class, 'store']);
            Route::put('/users/{username}', [UserController::class, 'update']);
            Route::delete('/users/{username}', [UserController::class, 'destroy']);
            Route::post('/users/{username}/reset-password', [UserController::class, 'resetPassword']);

            // --- Admin: master data kategori ---
            Route::post('/kategori', [KategoriController::class, 'store']);
            Route::put('/kategori/{id}/cycle', [KategoriController::class, 'updateCycle']);
            Route::put('/kategori/{id}', [KategoriController::class, 'update']);
            Route::delete('/kategori/{id}', [KategoriController::class, 'destroy']);

            // --- Admin: master data lokasi ---
            Route::post('/lokasi', [LokasiController::class, 'store']);
            Route::put('/lokasi/{id}', [LokasiController::class, 'update']);
            Route::delete('/lokasi/{id}', [LokasiController::class, 'destroy']);

            // --- Admin: master data spesifikasi ---
            Route::get('/spesifikasi', [SpesifikasiController::class, 'index']);
            Route::post('/spesifikasi', [SpesifikasiController::class, 'store']);
            Route::put('/spesifikasi/reorder', [SpesifikasiController::class, 'reorder']);
            Route::put('/spesifikasi/{id}', [SpesifikasiController::class, 'update']);
            Route::delete('/spesifikasi/{id}', [SpesifikasiController::class, 'destroy']);

            // --- Admin: master data alat ---
            Route::post('/alat', [AlatController::class, 'store']);
            Route::put('/alat/{barcode}', [AlatController::class, 'update']);
            Route::delete('/alat/{barcode}', [AlatController::class, 'destroy']);

        });

        // --- Log audit: Admin (seluruhnya) + Supervisor (pengawasan) ---
        // Supervisor perlu membaca jejak verifikasi yang ia lakukan sendiri
        // (AuditLogTest::test_verifikasi_tercatat_di_log_audit), tetapi tidak
        // boleh mengubah apa pun. Teknisi tetap ditolak 403.
        Route::middleware('role:Admin,Supervisor')->group(function () {
            Route::get('/audit-log', [AuditLogController::class, 'index']);
        });
    });
});
