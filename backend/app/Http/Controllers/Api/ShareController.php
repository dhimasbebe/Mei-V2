<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Maintenance;
use App\Models\ShareLink;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Tautan bagikan laporan (WS O, Fitur Tahap 3) — `docs/DESIGN-FEATURES-V3.md` §C.2.1–C.2.2.
 *
 * | Metode | Endpoint                      | Role             | Respons |
 * |--------|-------------------------------|------------------|---------|
 * | POST   | /api/v1/maintenance/{id}/share| Supervisor, Admin| envelope 201 |
 * | DELETE | /api/v1/share/{token}         | Supervisor, Admin| envelope 200 |
 * | GET    | /share/{token}                | publik (tanpa auth) | HTML, BUKAN envelope |
 *
 * PENTING (§C.2.1): `show` terdaftar di `routes/web.php` — DI LUAR prefix
 * `/api/v1` dan middleware Sanctum. JANGAN memakai `firstOrFail()`/`abort()`
 * di sini: 404 khusus "Tautan tidak berlaku" dibangun lewat
 * `response()->view('share.invalid', [], 404)`.
 */
class ShareController extends Controller
{
    /** Panjang token acak (syarat PRD O.2: >= 32 karakter). */
    public const PANJANG_TOKEN = 40;

    /**
     * POST /api/v1/maintenance/{id}/share  (Supervisor, Admin)
     *
     * Body opsional: { "expires_at": "Y-m-d H:i:s" }.
     * Dua permintaan pada laporan yang sama = dua token berbeda (AC-O1).
     */
    public function store(Request $request, int $id): JsonResponse
    {
        $maintenance = Maintenance::find($id);

        if ($maintenance === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        $validated = $request->validate([
            'expires_at' => 'nullable|date|after:now',
        ]);

        // Token unik dengan retry terhadap unique index (probabilitas
        // tumbukan 40 karakter acak nyaris nol, tetap dijaga).
        do {
            $token = Str::random(self::PANJANG_TOKEN);
        } while (ShareLink::where('token', $token)->exists());

        $link = ShareLink::create([
            'id_maintenance' => $id,
            'token' => $token,
            'created_by' => (string) $request->user()?->username,
            'expires_at' => $validated['expires_at'] ?? null,
            'created_at' => now(),
        ]);

        AuditLogger::log('create', 'share_link', $token, [
            'id_maintenance' => $id,
            'token' => $token,
            'expires_at' => $validated['expires_at'] ?? null,
        ]);

        return $this->ok([
            'id_share' => $link->id_share,
            'id_maintenance' => $id,
            'token' => $token,
            'url' => url('/share/'.$token),
            'expires_at' => $link->expires_at?->format('Y-m-d H:i:s'),
            'created_at' => $link->created_at?->format('Y-m-d H:i:s'),
        ], 'Tautan bagikan dibuat.', 201);
    }

    /**
     * DELETE /api/v1/share/{token}  (Supervisor, Admin)
     *
     * Pencabutan SOFT: set `revoked_at = now()`, baris dipertahankan untuk
     * jejak audit (R12). Idempoten: token yang sudah dicabut tetap 200.
     */
    public function destroy(string $token): JsonResponse
    {
        $link = ShareLink::where('token', $token)->first();

        if ($link === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        if ($link->revoked_at === null) {
            $link->revoked_at = now();
            $link->save();

            AuditLogger::log('delete', 'share_link', $token, [
                'token' => $token,
            ]);
        }

        return $this->ok([
            'id_share' => $link->id_share,
            'token' => $token,
            'revoked_at' => $link->revoked_at?->format('Y-m-d H:i:s'),
        ], 'Tautan dicabut.');
    }

    /**
     * GET /share/{token}  (PUBLIK — routes/web.php, tanpa auth)
     *
     * Halaman HTML ringkas read-only. TIDAK mengembalikan envelope JSON:
     * respons web berdiri sendiri (AC-O2). Token salah / dicabut /
     * kedaluwarsa → 404 halaman "Tautan tidak berlaku" (AC-O3).
     *
     * Halaman TIDAK menampilkan email/NIP pengguna — hanya `nama_users`
     * (PRD O.2).
     */
    public function show(string $token)
    {
        // §C.2.1 — JANGAN firstOrFail(): token tak dikenal, dicabut, dan
        // kedaluwarsa semuanya jatuh ke halaman 404 khusus yang sama.
        $link = ShareLink::with([
            'maintenance.alat.kategori',
            'maintenance.lokasi',
            'maintenance.user',
            'maintenance.detail.spesifikasi',
            'maintenance.foto',
        ])->where('token', $token)->first();

        if ($link === null || ! $link->masihBerlaku()) {
            return response()->view('share.invalid', [], 404);
        }

        return response()->view('share.maintenance', [
            'm' => $link->maintenance,
        ]);
    }
}
