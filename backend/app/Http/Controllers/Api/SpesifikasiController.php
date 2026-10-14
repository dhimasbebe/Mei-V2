<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Spesifikasi;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Master checklist spesifikasi per kategori (Admin).
 */
class SpesifikasiController extends Controller
{
    /**
     * GET /api/v1/spesifikasi?id_kategori=
     */
    public function index(Request $request): JsonResponse
    {
        $query = Spesifikasi::query();

        if ($request->filled('id_kategori')) {
            $query->where('id_kategori', $request->input('id_kategori'));
        }

        $items = $query->orderBy('id_kategori')->orderBy('urutan')->get();

        return $this->ok($items);
    }

    /**
     * POST /api/v1/spesifikasi  (Admin)
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $this->validatePayload($request);

        $spesifikasi = Spesifikasi::create($validated);

        AuditLogger::log('create', 'spesifikasi', (string) $spesifikasi->id_spesifikasi, [
            'nama_spesifikasi' => $spesifikasi->nama_spesifikasi,
        ]);

        return $this->ok($spesifikasi, 'Spesifikasi dibuat.', 201);
    }

    /**
     * PUT /api/v1/spesifikasi/{id}  (Admin)
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $spesifikasi = Spesifikasi::findOrFail($id);

        $validated = $this->validatePayload($request);
        $spesifikasi->update($validated);

        AuditLogger::log('update', 'spesifikasi', (string) $spesifikasi->id_spesifikasi, $validated);

        return $this->ok($spesifikasi, 'Spesifikasi diperbarui.');
    }

    /**
     * DELETE /api/v1/spesifikasi/{id}  (Admin)
     */
    public function destroy(int $id): JsonResponse
    {
        $spesifikasi = Spesifikasi::findOrFail($id);
        $spesifikasi->delete();

        AuditLogger::log('delete', 'spesifikasi', (string) $id);

        return $this->ok(null, 'Spesifikasi dihapus.');
    }

    /**
     * PUT /api/v1/spesifikasi/reorder  (Admin)
     *
     * body: { "id_kategori": 1, "items": [ { "id_spesifikasi": 3, "urutan": 1 }, ... ] }
     * Alias `urutan` juga diterima sebagai ganti `items`.
     */
    public function reorder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_kategori' => 'required|integer|exists:kategori,id_kategori',
            'items' => 'required_without:urutan|array',
            'items.*.id_spesifikasi' => 'required|integer|exists:spesifikasi,id_spesifikasi',
            'items.*.urutan' => 'nullable|integer|min:0',
            'urutan' => 'required_without:items|array',
            'urutan.*.id_spesifikasi' => 'required|integer|exists:spesifikasi,id_spesifikasi',
            'urutan.*.urutan' => 'nullable|integer|min:0',
        ]);

        $items = $validated['items'] ?? $validated['urutan'] ?? [];

        foreach ($items as $index => $item) {
            Spesifikasi::where('id_spesifikasi', $item['id_spesifikasi'])
                ->where('id_kategori', $validated['id_kategori'])
                ->update(['urutan' => $item['urutan'] ?? $index + 1]);
        }

        AuditLogger::log('update', 'spesifikasi', (string) $validated['id_kategori'], [
            'aksi' => 'reorder',
            'jumlah' => count($items),
        ]);

        return $this->ok(
            Spesifikasi::where('id_kategori', $validated['id_kategori'])->orderBy('urutan')->get(),
            'Urutan spesifikasi diperbarui.'
        );
    }

    /**
     * Validasi payload store/update yang sama.
     */
    private function validatePayload(Request $request): array
    {
        return $request->validate([
            'id_kategori' => 'required|integer|exists:kategori,id_kategori',
            'nama_spesifikasi' => 'required|string|max:100',
            'tipe_input' => 'required|in:text,number,select',
            'satuan' => 'nullable|string|max:50',
            'opsi' => 'nullable|string',
            'urutan' => 'nullable|integer|min:0',
        ]);
    }
}
