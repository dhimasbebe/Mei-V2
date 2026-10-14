<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\Maintenance;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class AlatController extends Controller
{
    /**
     * GET /api/v1/alat?q=&id_kategori=&id_lokasi=&penanggung_jawab=&overdue=
     *
     * `q` mencari di barcode, merk, NAMA KATEGORI, dan NAMA LOKASI. Teknisi
     * di lapangan biasanya mengetik "genset" atau "basement", bukan
     * "GS-001" — tanpa pencarian kategori/lokasi hasilnya kosong.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Alat::with(['kategori', 'lokasi', 'penanggungJawab']);

        if ($request->filled('q')) {
            $this->applySearch($query, (string) $request->input('q'));
        }

        if ($request->filled('id_kategori')) {
            $query->where('alat.id_kategori', $request->input('id_kategori'));
        }

        if ($request->filled('id_lokasi')) {
            $query->where('alat.id_lokasi', $request->input('id_lokasi'));
        }

        if ($request->filled('penanggung_jawab')) {
            $query->where('alat.penanggung_jawab', $request->input('penanggung_jawab'));
        }

        $alat = $query->orderBy('barcode_alat')->get();

        $this->attachLastMaintenance($alat);

        if ($request->boolean('overdue')) {
            $alat = $this->onlyOverdue($alat);
        }

        return $this->ok($alat->values());
    }

    /**
     * Pencarian teks bebas yang portabel (SQLite / MySQL / PostgreSQL).
     *
     * LOWER(...) dipakai di KEDUA sisi karena LIKE bersifat case-insensitive
     * di SQLite & MySQL, tetapi CASE-SENSITIVE di PostgreSQL — tanpa ini
     * pencarian "Genset" akan gagal di PostgreSQL.
     */
    private function applySearch($query, string $q): void
    {
        $needle = '%'.mb_strtolower(trim($q)).'%';

        $query->where(function ($builder) use ($needle) {
            $builder
                ->whereRaw('LOWER(alat.barcode_alat) LIKE ?', [$needle])
                ->orWhereRaw('LOWER(alat.merk_alat) LIKE ?', [$needle])
                ->orWhereHas('kategori', function ($k) use ($needle) {
                    $k->whereRaw('LOWER(kategori.nama) LIKE ?', [$needle]);
                })
                ->orWhereHas('lokasi', function ($l) use ($needle) {
                    $l->whereRaw('LOWER(lokasi.nama_lokasi) LIKE ?', [$needle]);
                });
        });
    }

    /**
     * GET /api/v1/alat/{barcode}
     */
    public function show(string $barcode): JsonResponse
    {
        $alat = Alat::with(['kategori', 'lokasi', 'penanggungJawab'])->findOrFail($barcode);

        $this->attachLastMaintenance(collect([$alat]));

        return $this->ok($alat);
    }

    /**
     * POST /api/v1/alat  (Admin)
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'barcode_alat' => 'required|string|max:100|unique:alat,barcode_alat',
            'merk_alat' => 'required|string|max:100',
            'id_kategori' => 'required|integer|exists:kategori,id_kategori',
            'id_lokasi' => 'nullable|integer|exists:lokasi,id_lokasi',
        ]);

        $alat = Alat::create($validated);

        AuditLogger::log('create', 'alat', $alat->barcode_alat, [
            'merk_alat' => $alat->merk_alat,
        ]);

        return $this->ok($alat->load(['kategori', 'lokasi', 'penanggungJawab']), 'Alat dibuat.', 201);
    }

    /**
     * PUT /api/v1/alat/{barcode}  (Admin)
     */
    public function update(Request $request, string $barcode): JsonResponse
    {
        $alat = Alat::findOrFail($barcode);

        $validated = $request->validate([
            'merk_alat' => 'required|string|max:100',
            'id_kategori' => 'required|integer|exists:kategori,id_kategori',
            'id_lokasi' => 'nullable|integer|exists:lokasi,id_lokasi',
        ]);

        $alat->update($validated);

        AuditLogger::log('update', 'alat', $alat->barcode_alat, $validated);

        return $this->ok($alat->load(['kategori', 'lokasi', 'penanggungJawab']), 'Alat diperbarui.');
    }

    /**
     * DELETE /api/v1/alat/{barcode}  (Admin)
     */
    public function destroy(string $barcode): JsonResponse
    {
        $alat = Alat::findOrFail($barcode);

        $alat->delete();

        AuditLogger::log('delete', 'alat', $barcode);

        return $this->ok(null, 'Alat dihapus.');
    }

    /**
     * POST /api/v1/alat/{barcode}/assign  (Supervisor/Admin)
     *
     * body: { "username": "67890" }
     */
    public function assign(Request $request, string $barcode): JsonResponse
    {
        $validated = $request->validate([
            'username' => 'required|string|exists:users,username',
        ]);

        $alat = Alat::findOrFail($barcode);
        $alat->penanggung_jawab = $validated['username'];
        $alat->ditugaskan_pada = now();
        $alat->save();

        AuditLogger::log('assign', 'alat', $alat->barcode_alat, ['username' => $validated['username']]);

        $alat->load('penanggungJawab');

        return $this->ok([
            'barcode_alat' => $alat->barcode_alat,
            'penanggung_jawab' => $alat->penanggung_jawab,
            'nama_penanggung_jawab' => $alat->nama_penanggung_jawab,
            'ditugaskan_pada' => $alat->ditugaskan_pada?->format('Y-m-d H:i:s'),
        ], 'Alat ditugaskan.');
    }

    /**
     * Isi kolom turunan `terakhir_maintenance` untuk sekumpulan alat dengan
     * SATU query tambahan — menghindari N+1 saat daftar alat ditampilkan.
     */
    private function attachLastMaintenance(Collection $alat): void
    {
        if ($alat->isEmpty()) {
            return;
        }

        $terakhir = Maintenance::query()
            ->whereIn('barcode_alat', $alat->pluck('barcode_alat'))
            ->selectRaw('barcode_alat, MAX(waktu_maintenance) as terakhir')
            ->groupBy('barcode_alat')
            ->pluck('terakhir', 'barcode_alat');

        $alat->each(function (Alat $item) use ($terakhir) {
            $item->setAttribute('terakhir_maintenance', $terakhir[$item->barcode_alat] ?? null);
        });
    }

    /**
     * Saring hanya alat yang melewati siklus kategorinya.
     */
    private function onlyOverdue(Collection $alat): Collection
    {
        return $alat->filter(function (Alat $item) {
            $terakhir = $item->terakhir_maintenance;
            $cycle = $item->maintenance_cycle_days;

            if ($terakhir === null) {
                return true; // belum pernah dipelihara -> overdue
            }

            $umur = (int) abs(now()->startOfDay()->diffInDays(Carbon::parse($terakhir)->startOfDay()));

            return $umur > $cycle;
        })->values();
    }
}
