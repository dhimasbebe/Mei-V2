<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Maintenance;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class MaintenanceController extends Controller
{
    /** Relasi yang selalu di-eager-load agar accessor tidak N+1. */
    private const WITH = ['detail.spesifikasi', 'alat.kategori', 'lokasi', 'user'];

    /**
     * GET /api/v1/maintenance?page=&per_page=&barcode_alat=&id_kategori=&username=&status_verifikasi=&dari=&sampai=
     *
     * Respons: envelope { code, data, message } dengan `data` = objek paginator
     * Laravel (data, current_page, last_page, per_page, total) — sesuai
     * `PagedResult` pada klien Flutter.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Maintenance::with(self::WITH)
            ->orderByDesc('waktu_maintenance');

        if ($request->filled('barcode_alat')) {
            $query->where('barcode_alat', $request->input('barcode_alat'));
        }

        if ($request->filled('id_kategori')) {
            $query->where('id_kategori', $request->input('id_kategori'));
        }

        // Privasi: Teknisi dibatasi pada laporannya sendiri (dua lapis dengan
        // penyaringan `username` di klien — AC-K5). Untuk peran ini parameter
        // `username` dari klien DIABAIKAN, bukan digabung dengan syarat lain:        // memintanya sebagai teknisi lain tidak boleh menghasilkan apa pun,
        // termasuk tidak boleh membocorkan keberadaan data lewat beda respons.
        if ($this->hanyaLaporanSendiri($request)) {
            $query->where('username', $request->user()->username);
        } elseif ($request->filled('username')) {
            $query->where('username', $request->input('username'));
        }

        if ($request->filled('status_verifikasi')) {
            $query->where('status_verifikasi', $request->input('status_verifikasi'));
        }

        if ($request->filled('dari')) {
            $query->whereDate('waktu_maintenance', '>=', $request->input('dari'));
        }

        if ($request->filled('sampai')) {
            $query->whereDate('waktu_maintenance', '<=', $request->input('sampai'));
        }

        $perPage = max(1, min(100, (int) $request->input('per_page', 20)));

        return $this->ok($query->paginate($perPage));
    }

    /**
     * POST /api/v1/maintenance
     *
     * Idempoten berdasarkan `client_uuid`: pengiriman ulang dari antrean
     * offline mengembalikan data yang SUDAH ada (200), bukan error 422.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'client_uuid' => 'required|string|max:64',
            'barcode_alat' => 'required|string|exists:alat,barcode_alat',
            'id_lokasi' => 'required|integer|exists:lokasi,id_lokasi',
            'waktu_maintenance' => 'required|date',
            'catatan' => 'nullable|string',
            'kondisi_keseluruhan' => 'nullable|in:baik,kurang_baik,rusak',
            'detail' => 'required|array|min:1',
            'detail.*.id_spesifikasi' => 'required|integer|exists:spesifikasi,id_spesifikasi',
            'detail.*.status' => 'required|string|max:255',
        ]);

        // --- Idempotency: sudah pernah tersimpan? kembalikan yang lama. ---
        $existing = Maintenance::with(self::WITH)
            ->where('client_uuid', $validated['client_uuid'])
            ->first();

        if ($existing !== null) {
            return $this->ok($existing, 'Maintenance sudah tersimpan sebelumnya.');
        }

        $maintenance = DB::transaction(function () use ($validated, $request) {
            $alat = Alat::find($validated['barcode_alat']);

            $maintenance = Maintenance::create([
                'client_uuid' => $validated['client_uuid'],
                'barcode_alat' => $validated['barcode_alat'],
                'username' => $request->user()->username,
                'id_lokasi' => $validated['id_lokasi'],
                'id_kategori' => $alat?->id_kategori,
                'waktu_maintenance' => $validated['waktu_maintenance'],
                'catatan' => $validated['catatan'] ?? null,
                'kondisi_keseluruhan' => $validated['kondisi_keseluruhan'] ?? null,
                'status_verifikasi' => 'menunggu',
            ]);

            foreach ($validated['detail'] as $item) {
                $maintenance->detail()->create([
                    'id_spesifikasi' => $item['id_spesifikasi'],
                    'status' => $item['status'],
                ]);
            }

            return $maintenance;
        });

        return $this->ok(
            $maintenance->load(self::WITH),
            'Maintenance tersimpan.',
            201,
        );
    }

    /**
     * GET /api/v1/maintenance/{id}
     *
     * Menyertakan array `foto` (fitur Tahap 3) — `[]` bila belum ada lampiran.
     * Teknisi hanya boleh membuka laporannya sendiri (403 bila bukan).
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $maintenance = Maintenance::with(self::WITH)->with('foto')->findOrFail($id);

        // Teknisi tidak boleh membaca laporan teknisi lain, termasuk lewat
        // enumerasi id berurutan. Supervisor/Admin tetap boleh membuka semua.
        if ($this->hanyaLaporanSendiri($request)
            && $maintenance->username !== $request->user()->username) {
            return response()->json([
                'code' => 403,
                'data' => null,
                'message' => 'Laporan ini bukan milik Anda.',
            ], 403);
        }

        return $this->ok($maintenance);
    }

    /**
     * Apakah peminta dibatasi pada laporan miliknya sendiri?
     *
     * Sama seperti `FotoController::index`, peran Teknisi hanya boleh melihat
     * laporannya sendiri; Supervisor dan Admin melihat semua.
     */
    private function hanyaLaporanSendiri(Request $request): bool
    {
        $user = $request->user();

        if ($user === null) {
            return false;
        }

        return strcasecmp((string) $user->role_users, 'Teknisi') === 0;
    }

    /**
     * GET /api/v1/maintenance/pending?page=&per_page=  (Supervisor/Admin)
     *
     * Daftar sesi yang menunggu verifikasi.
     */
    public function pending(Request $request): JsonResponse
    {
        $query = Maintenance::with(self::WITH)
            ->withCount(['foto as jumlah_foto'])
            ->where('status_verifikasi', 'menunggu')
            ->orderByDesc('waktu_maintenance');

        if ($request->filled('barcode_alat')) {
            $query->where('barcode_alat', $request->input('barcode_alat'));
        }

        if ($request->filled('id_kategori')) {
            $query->where('id_kategori', $request->input('id_kategori'));
        }

        $perPage = max(1, min(100, (int) $request->input('per_page', 20)));

        return $this->ok($query->paginate($perPage));
    }

    /**
     * GET /api/v1/maintenance/pending/count  (Supervisor/Admin)
     */
    public function pendingCount(): JsonResponse
    {
        return $this->ok([
            'menunggu' => Maintenance::where('status_verifikasi', 'menunggu')->count(),
        ]);
    }

    /**
     * POST /api/v1/maintenance/{id}/verify  (Supervisor/Admin)
     *
     * body: { "status": "disetujui|ditolak", "komentar": "..." }
     */
    public function verify(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'status' => 'required|in:disetujui,ditolak',
            'komentar' => 'nullable|string|max:500',
        ]);

        $maintenance = Maintenance::findOrFail($id);

        $maintenance->status_verifikasi = $validated['status'];
        $maintenance->diverifikasi_oleh = $request->user()->username;
        $maintenance->waktu_verifikasi = now();
        $maintenance->komentar_verifikasi = $validated['komentar'] ?? null;
        $maintenance->save();

        AuditLogger::log('verify', 'maintenance', (string) $maintenance->id_maintenance, [
            'status' => $validated['status'],
        ]);

        return $this->ok([
            'id_maintenance' => $maintenance->id_maintenance,
            'status_verifikasi' => $maintenance->status_verifikasi,
            'diverifikasi_oleh' => $maintenance->diverifikasi_oleh,
            'waktu_verifikasi' => $maintenance->waktu_verifikasi?->format('Y-m-d H:i:s'),
            'komentar_verifikasi' => $maintenance->komentar_verifikasi,
        ], 'Verifikasi tersimpan.');
    }

    /**
     * GET /api/v1/maintenance/overdue?limit=  (Supervisor/Admin)
     *
     * Papan overdue: alat yang melewati siklus pemeliharaan kategorinya.
     * Alat yang belum pernah dipelihara dihitung terlambat satu siklus penuh.
     * Perhitungan dilakukan di PHP agar portabel (SQLite/MySQL/PostgreSQL).
     */
    public function overdue(Request $request): JsonResponse
    {
        $limit = max(1, min(200, (int) $request->input('limit', 20)));

        $cycles = Kategori::pluck('maintenance_cycle_days', 'id_kategori');
        $terakhir = $this->lastMaintenancePerAlat();

        $items = Alat::with(['kategori', 'lokasi', 'penanggungJawab'])
            ->get()
            ->map(function (Alat $alat) use ($cycles, $terakhir) {
                $cycle = (int) ($cycles[$alat->id_kategori] ?? 30);
                $waktu = $terakhir[$alat->barcode_alat] ?? null;

                $umur = $waktu === null
                    ? null
                    : (int) abs(now()->startOfDay()->diffInDays(Carbon::parse($waktu)->startOfDay()));

                $terlambat = $umur === null ? $cycle : $umur - $cycle;

                if ($terlambat <= 0) {
                    return null;
                }

                return [
                    'barcode_alat' => $alat->barcode_alat,
                    'merk_alat' => $alat->merk_alat,
                    'nama_kategori' => $alat->kategori?->nama,
                    'nama_lokasi' => $alat->lokasi?->nama_lokasi,
                    'lantai' => $alat->lokasi?->lantai,
                    'terlambat_hari' => $terlambat,
                    'penanggung_jawab' => $alat->penanggung_jawab,
                    'nama_penanggung_jawab' => $alat->nama_penanggung_jawab,
                ];
            })
            ->filter()
            ->sortByDesc('terlambat_hari')
            ->take($limit)
            ->values();

        return $this->ok($items);
    }

    /**
     * Waktu maintenance terakhir per barcode — SATU query.
     *
     * @return Collection<string, Carbon>
     */
    private function lastMaintenancePerAlat(): Collection
    {
        return Maintenance::query()
            ->orderByDesc('waktu_maintenance')
            ->get(['barcode_alat', 'waktu_maintenance'])
            ->groupBy('barcode_alat')
            ->map(fn (Collection $rows) => $rows->first()->waktu_maintenance);
    }
}
