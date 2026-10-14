<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lokasi;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LokasiController extends Controller
{
    /**
     * GET /api/v1/lokasi
     *
     * withCount('alat') dipakai accessor Lokasi::getJumlahAlatAttribute
     * sehingga tidak ada query N+1.
     */
    public function index(): JsonResponse
    {
        return $this->ok(
            Lokasi::withCount('alat')->orderBy('lantai')->orderBy('nama_lokasi')->get()
        );
    }

    /**
     * POST /api/v1/lokasi  (Admin)
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'nama_lokasi' => 'required|string|max:100',
            'lantai' => 'nullable|integer',
            'keterangan' => 'nullable|string',
        ]);

        $lokasi = Lokasi::create($validated);

        AuditLogger::log('create', 'lokasi', (string) $lokasi->id_lokasi, [
            'nama_lokasi' => $lokasi->nama_lokasi,
        ]);

        return $this->ok($lokasi->loadCount('alat'), 'Lokasi dibuat.', 201);
    }

    /**
     * PUT /api/v1/lokasi/{id}  (Admin)
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $lokasi = Lokasi::findOrFail($id);

        $validated = $request->validate([
            'nama_lokasi' => 'required|string|max:100',
            'lantai' => 'nullable|integer',
            'keterangan' => 'nullable|string',
        ]);

        $lokasi->update($validated);

        AuditLogger::log('update', 'lokasi', (string) $lokasi->id_lokasi, $validated);

        return $this->ok($lokasi->loadCount('alat'), 'Lokasi diperbarui.');
    }

    /**
     * DELETE /api/v1/lokasi/{id}  (Admin)
     */
    public function destroy(int $id): JsonResponse
    {
        $lokasi = Lokasi::withCount('alat')->findOrFail($id);

        if ((int) $lokasi->alat_count > 0) {
            return $this->error('Lokasi masih dipakai oleh '.$lokasi->alat_count.' alat.', 422);
        }

        $lokasi->delete();

        AuditLogger::log('delete', 'lokasi', (string) $id);

        return $this->ok(null, 'Lokasi dihapus.');
    }
}
