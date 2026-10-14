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
 * "Tugas Hari Ini" untuk Teknisi (dihitung di server, tanpa tabel baru).
 *
 * Sumber: `maintenance` (waktu terakhir) + `kategori.maintenance_cycle_days`.
 * Status tiap alat: overdue | jatuh_tempo | terjadwal.
 */
class TugasController extends Controller
{
    public function today(Request $request): JsonResponse
    {
        $username = $request->user()->username;

        $cycles = Kategori::pluck('maintenance_cycle_days', 'id_kategori');

        $terakhir = Maintenance::query()
            ->orderByDesc('waktu_maintenance')
            ->get(['barcode_alat', 'waktu_maintenance'])
            ->groupBy('barcode_alat')
            ->map(fn (Collection $rows) => $rows->first()->waktu_maintenance);

        $query = Alat::with(['kategori', 'lokasi']);

        // Alat yang ditugaskan ke teknisi ini; bila belum ada penugasan sama
        // sekali, tampilkan seluruh alat agar beranda tidak kosong.
        if (Alat::where('penanggung_jawab', $username)->exists()) {
            $query->where('penanggung_jawab', $username);
        }

        $daftar = $query->get()->map(function (Alat $alat) use ($cycles, $terakhir) {
            $cycle = (int) ($cycles[$alat->id_kategori] ?? 30);
            $waktu = $terakhir[$alat->barcode_alat] ?? null;

            if ($waktu === null) {
                $status = 'overdue';
                $terlambat = $cycle;
            } else {
                $umur = (int) abs(now()->startOfDay()->diffInDays(Carbon::parse($waktu)->startOfDay()));
                $sisa = $cycle - $umur;

                $status = $sisa < 0 ? 'overdue' : ($sisa === 0 ? 'jatuh_tempo' : 'terjadwal');
                $terlambat = max(0, -$sisa);
            }

            return [
                'barcode_alat' => $alat->barcode_alat,
                'merk_alat' => $alat->merk_alat,
                'nama_kategori' => $alat->kategori?->nama,
                'nama_lokasi' => $alat->lokasi?->nama_lokasi,
                'lantai' => $alat->lokasi?->lantai,
                'terlambat_hari' => $terlambat,
                'status' => $status,
                'terakhir_maintenance' => $waktu === null
                    ? null
                    : Carbon::parse($waktu)->format('Y-m-d H:i:s'),
            ];
        });

        $prioritas = ['overdue' => 0, 'jatuh_tempo' => 1, 'terjadwal' => 2];

        $daftar = $daftar
            ->sortBy(fn (array $item) => sprintf(
                '%d-%06d',
                $prioritas[$item['status']],
                999999 - $item['terlambat_hari'],
            ))
            ->values();

        return $this->ok([
            'ringkasan' => [
                'total' => $daftar->count(),
                'overdue' => $daftar->where('status', 'overdue')->count(),
                'jatuh_tempo_hari_ini' => $daftar->where('status', 'jatuh_tempo')->count(),
            ],
            'daftar' => $daftar,
        ]);
    }
}
