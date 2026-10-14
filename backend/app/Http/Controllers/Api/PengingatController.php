<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Maintenance;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Pengingat (jatuh tempo / terlambat / menunggu verifikasi) —
 * `docs/DESIGN-FEATURES-V3.md` §10.2.
 *
 * GET /api/v1/pengingat  (Teknisi, Supervisor, Admin)
 *   - Teknisi          → tugas miliknya (jatuh tempo + terlambat)
 *   - Supervisor/Admin → jumlah & daftar laporan menunggu verifikasi
 *
 * Bentuk respons:
 *   { ringkasan: {jatuh_tempo, terlambat, menunggu_verifikasi}, daftar: [...] }
 * Selalu `jumlah daftar == jumlah ringkasan` (jatuh_tempo + terlambat +
 * menunggu_verifikasi) agar klien dapat menampilkan lencana tanpa hitung ulang.
 */
class PengingatController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        if (strcasecmp((string) $user->role_users, 'Teknisi') === 0) {
            return $this->ok($this->untukTeknisi($user->username));
        }

        return $this->ok($this->untukPengawas());
    }

    /**
     * Pengingat untuk Teknisi: alat yang overdue / jatuh tempo pada siklusnya.
     *
     * @return array{ringkasan: array<string,int>, daftar: Collection<int,array<string,mixed>>}
     */
    private function untukTeknisi(string $username): array
    {
        $cycles = Kategori::pluck('maintenance_cycle_days', 'id_kategori');

        $terakhir = Maintenance::query()
            ->orderByDesc('waktu_maintenance')
            ->get(['barcode_alat', 'waktu_maintenance'])
            ->groupBy('barcode_alat')
            ->map(fn (Collection $rows) => $rows->first()->waktu_maintenance);

        $query = Alat::with(['kategori', 'lokasi']);

        // Selaras TugasController: bila ada penugasan, batasi ke alat teknisi.
        if (Alat::where('penanggung_jawab', $username)->exists()) {
            $query->where('penanggung_jawab', $username);
        }

        $daftar = $query->get()
            ->map(function (Alat $alat) use ($cycles, $terakhir) {
                $cycle = (int) ($cycles[$alat->id_kategori] ?? 30);
                $waktu = $terakhir[$alat->barcode_alat] ?? null;
                $hariIni = now()->startOfDay();

                if ($waktu === null) {
                    // Belum pernah dipelihara -> terlambat satu siklus penuh.
                    return [
                        'tipe' => 'terlambat',
                        'barcode_alat' => $alat->barcode_alat,
                        'nama_kategori' => $alat->kategori?->nama,
                        'nama_lokasi' => $alat->lokasi?->nama_lokasi,
                        'jatuh_tempo' => null,
                        'terlambat_hari' => $cycle,
                    ];
                }

                $akhir = Carbon::parse($waktu)->startOfDay()->addDays($cycle);

                // Arah ditentukan perbandingan tanggal (portabel antar versi
                // Carbon); besarannya pakai diffInDays absolut.
                if ($akhir->greaterThan($hariIni)) {
                    return null; // belum waktunya -> bukan pengingat
                }

                $terlambat = $akhir->lessThan($hariIni)
                    ? (int) $akhir->diffInDays($hariIni)
                    : 0;

                return [
                    'tipe' => $terlambat > 0 ? 'terlambat' : 'jatuh_tempo',
                    'barcode_alat' => $alat->barcode_alat,
                    'nama_kategori' => $alat->kategori?->nama,
                    'nama_lokasi' => $alat->lokasi?->nama_lokasi,
                    'jatuh_tempo' => $akhir->format('Y-m-d'),
                    'terlambat_hari' => $terlambat,
                ];
            })
            ->filter()
            ->sortByDesc('terlambat_hari')
            ->values();

        return [
            'ringkasan' => [
                'jatuh_tempo' => $daftar->where('tipe', 'jatuh_tempo')->count(),
                'terlambat' => $daftar->where('tipe', 'terlambat')->count(),
                'menunggu_verifikasi' => 0,
            ],
            'daftar' => $daftar,
        ];
    }

    /**
     * Pengingat untuk Supervisor/Admin: laporan menunggu verifikasi.
     *
     * @return array{ringkasan: array<string,int>, daftar: Collection<int,array<string,mixed>>}
     */
    private function untukPengawas(): array
    {
        $menunggu = Maintenance::with(['alat.kategori', 'lokasi'])
            ->where('status_verifikasi', 'menunggu')
            ->orderByDesc('waktu_maintenance')
            ->get()
            ->map(fn (Maintenance $m) => [
                'tipe' => 'menunggu_verifikasi',
                'barcode_alat' => $m->barcode_alat,
                'nama_kategori' => $m->alat?->kategori?->nama,
                'nama_lokasi' => $m->lokasi?->nama_lokasi,
                'jatuh_tempo' => null,
                'terlambat_hari' => 0,
            ])
            ->values();

        return [
            'ringkasan' => [
                'jatuh_tempo' => 0,
                'terlambat' => 0,
                'menunggu_verifikasi' => $menunggu->count(),
            ],
            'daftar' => $menunggu,
        ];
    }
}
