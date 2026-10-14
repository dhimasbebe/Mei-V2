<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Maintenance;
use App\Models\MaintenanceFoto;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Foto lampiran pemeliharaan — `docs/DESIGN-FEATURES-V3.md` §10.2.
 *
 * | Metode | Endpoint                        | Role             |
 * |--------|---------------------------------|------------------|
 * | POST   | /maintenance/{id}/foto          | Teknisi, Admin   |
 * | GET    | /maintenance/{id}/foto          | semua (kepemilikan) |
 * | DELETE | /maintenance/foto/{id_foto}     | Supervisor, Admin |
 *
 * Berkas disimpan di disk `public` (folder `foto/`), URL lewat `Storage::url()`.
 */
class FotoController extends Controller
{
    /** Batas jumlah foto per laporan (selaras `PhotoPolicy.maxFotos`). */
    public const MAX_FOTO = 5;

    /**
     * POST /api/v1/maintenance/{id}/foto  (Teknisi, Admin)
     *
     * multipart field `foto`; `mimes:jpg,jpeg,png`; `max:5120` (5 MB).
     * 404 bila id tidak ada, 403 bila Teknisi bukan pemiliknya, 201 bila sukses.
     */
    public function store(Request $request, int $id): JsonResponse
    {
        $maintenance = Maintenance::find($id);

        if ($maintenance === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        $user = $request->user();

        // Teknisi hanya boleh mengunggah ke laporannya sendiri.
        if ($this->adalahTeknisi($user?->role_users) && $maintenance->username !== $user->username) {
            return $this->error('Tidak berhak.', 403);
        }

        $request->validate([
            'foto' => 'required|file|mimes:jpg,jpeg,png|max:5120',
        ]);

        if (MaintenanceFoto::where('id_maintenance', $id)->count() >= self::MAX_FOTO) {
            throw ValidationException::withMessages([
                'foto' => ['maksimum '.self::MAX_FOTO.' foto'],
            ]);
        }

        $file = $request->file('foto');
        $path = $file->store('foto', 'public');

        $foto = MaintenanceFoto::create([
            'id_maintenance' => $id,
            'path' => $path,
            'mime' => $file->getClientMimeType() ?: 'application/octet-stream',
            'ukuran' => $file->getSize(),
            'username' => $user->username,
            'created_at' => now(),
        ]);

        return $this->ok([
            'id_foto' => $foto->id_foto,
            'url' => $foto->url,
            'mime' => $foto->mime,
            'ukuran' => (int) $foto->ukuran,
        ], 'Foto tersimpan.', 201);
    }

    /**
     * GET /api/v1/maintenance/{id}/foto  (semua peran, cek kepemilikan)
     */
    public function index(Request $request, int $id): JsonResponse
    {
        $maintenance = Maintenance::find($id);

        if ($maintenance === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        $user = $request->user();

        if ($this->adalahTeknisi($user?->role_users) && $maintenance->username !== $user->username) {
            return $this->error('Tidak berhak.', 403);
        }

        return $this->ok(
            MaintenanceFoto::where('id_maintenance', $id)
                ->orderBy('id_foto')
                ->get()
        );
    }

    /**
     * DELETE /api/v1/maintenance/foto/{id_foto}  (Supervisor, Admin)
     *
     * Menghapus baris + berkas fisik.
     */
    public function destroy(int $idFoto): JsonResponse
    {
        $foto = MaintenanceFoto::find($idFoto);

        if ($foto === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        Storage::disk('public')->delete($foto->path);
        $foto->delete();

        return $this->ok(null, 'Foto dihapus.');
    }

    private function adalahTeknisi(?string $role): bool
    {
        return $role !== null && strcasecmp($role, 'Teknisi') === 0;
    }
}
