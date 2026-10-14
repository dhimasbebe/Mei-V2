<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Kategori;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class KategoriController extends Controller
{
    public function index(): JsonResponse
    {
        $kategori = Kategori::withCount('alat')->get();
        return $this->ok($kategori);
    }

    public function spesifikasi(int $id): JsonResponse
    {
        $kategori = Kategori::findOrFail($id);
        return $this->ok($kategori->spesifikasi()->orderBy('urutan')->get());
    }

    /**
     * POST /api/v1/kategori  (Admin)
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:100|unique:kategori,nama',
            'deskripsi' => 'nullable|string',
            'maintenance_cycle_days' => 'nullable|integer|min:1|max:3650',
            'icon_asset' => 'nullable|string|max:255',
        ]);

        $kategori = Kategori::create([
            'nama' => $validated['nama'],
            'deskripsi' => $validated['deskripsi'] ?? null,
            'maintenance_cycle_days' => $validated['maintenance_cycle_days'] ?? 30,
            'icon_asset' => $validated['icon_asset'] ?? null,
        ]);

        AuditLogger::log('create', 'kategori', (string) $kategori->id_kategori, [
            'nama' => $kategori->nama,
        ]);

        return $this->ok($kategori->loadCount('alat'), 'Kategori dibuat.', 201);
    }

    /**
     * PUT /api/v1/kategori/{id}  (Admin)
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $kategori = Kategori::findOrFail($id);

        $validated = $request->validate([
            'nama' => ['required', 'string', 'max:100', Rule::unique('kategori', 'nama')->ignore($id, 'id_kategori')],
            'deskripsi' => 'nullable|string',
            'maintenance_cycle_days' => 'nullable|integer|min:1|max:3650',
            'icon_asset' => 'nullable|string|max:255',
        ]);

        $kategori->update($validated);

        AuditLogger::log('update', 'kategori', (string) $kategori->id_kategori, $validated);

        return $this->ok($kategori->loadCount('alat'), 'Kategori diperbarui.');
    }

    /**
     * DELETE /api/v1/kategori/{id}  (Admin)
     */
    public function destroy(int $id): JsonResponse
    {
        $kategori = Kategori::withCount('alat')->findOrFail($id);

        if ((int) $kategori->alat_count > 0) {
            return $this->error('Kategori masih dipakai oleh '.$kategori->alat_count.' alat.', 422);
        }

        $kategori->delete();

        AuditLogger::log('delete', 'kategori', (string) $id);

        return $this->ok(null, 'Kategori dihapus.');
    }

    /**
     * PUT /api/v1/kategori/{id}/cycle  (Admin)
     */
    public function updateCycle(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'maintenance_cycle_days' => 'required|integer|min:1|max:3650',
        ]);

        $kategori = Kategori::findOrFail($id);
        $kategori->maintenance_cycle_days = $validated['maintenance_cycle_days'];
        $kategori->save();

        AuditLogger::log('update', 'kategori', (string) $kategori->id_kategori, [
            'maintenance_cycle_days' => $kategori->maintenance_cycle_days,
        ]);

        return $this->ok($kategori->loadCount('alat'), 'Siklus kategori diperbarui.');
    }
}
