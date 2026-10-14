<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\DetailMaintenance;
use App\Models\Kategori;
use App\Models\Maintenance;
use App\Models\Spesifikasi;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Endpoint dashboard monitoring (Mei-V2).
 *
 * CATATAN PORTABILITAS
 * --------------------
 * Versi sebelumnya memakai DATE_SUB()/DATEDIFF()/HAVING (khusus MySQL) dan
 * mereferensikan kolom maintenance_cycle_days pada tabel yang salah sehingga
 * query gagal. Semua perhitungan di sini dilakukan di PHP agar jalan di
 * SQLite (default), MySQL, maupun PostgreSQL.
 */
class DashboardController extends Controller
{
    /**
     * Nilai dropdown yang dianggap tidak normal (untuk sorotan parameter).
     */
    private const NILAI_TIDAK_NORMAL = [
        'rusak', 'tidak baik', 'tidak normal', 'tidak berbunyi',
        'kotor', 'lemah', 'kosong', 'kendor', 'tidak',
    ];

    /**
     * Maintenance terakhir per alat — SATU query, dipakai kpi() & overdue().
     *
     * @return Collection<string, Maintenance>
     */
    private function lastMaintenancePerAlat(): Collection
    {
        return Maintenance::with('user')
            ->orderByDesc('waktu_maintenance')
            ->get(['id_maintenance', 'barcode_alat', 'waktu_maintenance', 'username'])
            ->groupBy('barcode_alat')
            ->map(fn (Collection $rows) => $rows->first());
    }

    /**
     * Umur dalam hari (berbasis tanggal, sama seperti `umurHari` di klien Flutter).
     */
    private function umurHari(?Carbon $waktu): ?int
    {
        if ($waktu === null) {
            return null;
        }

        return (int) abs(now()->startOfDay()->diffInDays($waktu->copy()->startOfDay()));
    }

    /**
     * GET /api/v1/dashboard/kpi
     */
    public function kpi(): JsonResponse
    {
        $totalAlat = Alat::count();
        $totalKategori = Kategori::count();

        $now = now();
        $pemeliharaanBulanIni = Maintenance::whereYear('waktu_maintenance', $now->year)
            ->whereMonth('waktu_maintenance', $now->month)
            ->count();

        $cycles = Kategori::pluck('maintenance_cycle_days', 'id_kategori');
        $terakhir = $this->lastMaintenancePerAlat();

        $tepatWaktu = 0;
        $sampelInterval = [];

        foreach (Alat::get(['barcode_alat', 'id_kategori']) as $alat) {
            $cycle = (int) ($cycles[$alat->id_kategori] ?? 30);
            $row = $terakhir[$alat->barcode_alat] ?? null;
            $umur = $this->umurHari($row?->waktu_maintenance);

            if ($umur === null) {
                continue; // belum pernah dipelihara -> dihitung overdue
            }

            if ($umur <= $cycle) {
                $tepatWaktu++;
            }

            $sampelInterval[] = $umur;
        }

        $alatOverdue = max(0, $totalAlat - $tepatWaktu);
        $persenTepatWaktu = $totalAlat > 0
            ? round(($tepatWaktu / $totalAlat) * 100, 2)
            : 0.0;

        $rataRataInterval = $sampelInterval !== []
            ? round(array_sum($sampelInterval) / count($sampelInterval), 1)
            : null;

        return $this->ok([
            'total_alat' => $totalAlat,
            'total_kategori' => $totalKategori,
            'pemeliharaan_bulan_ini' => $pemeliharaanBulanIni,
            'pemeliharaan_tepat_waktu' => $tepatWaktu,
            'alat_overdue' => $alatOverdue,
            'teknisi_aktif' => User::where('role_users', 'Teknisi')->count(),
            'persen_tepat_waktu' => $persenTepatWaktu,
            'rata_rata_interval_hari' => $rataRataInterval,
        ]);
    }

    /**
     * GET /api/v1/dashboard/trends?days=30
     *
     * Mengembalikan rangkaian lengkap (termasuk hari tanpa pemeliharaan = 0)
     * supaya grafik garis tidak berlubang.
     */
    public function trends(Request $request): JsonResponse
    {
        $days = max(1, min(365, (int) $request->input('days', 30)));
        $start = now()->subDays($days - 1)->startOfDay();

        $counts = Maintenance::where('waktu_maintenance', '>=', $start)
            ->get(['waktu_maintenance'])
            ->groupBy(fn (Maintenance $m) => $m->waktu_maintenance->toDateString())
            ->map(fn (Collection $rows) => $rows->count());

        $series = [];
        for ($i = 0; $i < $days; $i++) {
            $tanggal = $start->copy()->addDays($i)->toDateString();
            $series[] = [
                'label' => $tanggal,
                'tanggal' => $tanggal,
                'jumlah' => (int) ($counts[$tanggal] ?? 0),
            ];
        }

        return $this->ok($series);
    }

    /**
     * GET /api/v1/dashboard/distribution
     *
     * Jumlah alat per kategori (untuk pie chart).
     */
    public function distribution(): JsonResponse
    {
        $rows = Kategori::withCount('alat')
            ->orderBy('id_kategori')
            ->get()
            ->map(fn (Kategori $k) => [
                'label' => $k->nama,
                'jumlah' => (int) $k->alat_count,
                'icon_asset' => $k->icon_asset,
            ]);

        return $this->ok($rows);
    }

    /**
     * GET /api/v1/dashboard/overdue?limit=10
     *
     * Alat yang melewati siklus pemeliharaan kategorinya.
     * Alat yang belum pernah dipelihara dihitung terlambat satu siklus penuh.
     */
    public function overdue(Request $request): JsonResponse
    {
        $limit = max(1, min(100, (int) $request->input('limit', 10)));

        $cycles = Kategori::pluck('maintenance_cycle_days', 'id_kategori');
        $terakhir = $this->lastMaintenancePerAlat();

        $items = Alat::with(['kategori', 'lokasi'])
            ->get()
            ->map(function (Alat $alat) use ($cycles, $terakhir) {
                $cycle = (int) ($cycles[$alat->id_kategori] ?? 30);
                $row = $terakhir[$alat->barcode_alat] ?? null;
                $umur = $this->umurHari($row?->waktu_maintenance);

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
                    'nama_users' => $row?->user?->nama_users,
                ];
            })
            ->filter()
            ->sortByDesc('terlambat_hari')
            ->take($limit)
            ->values();

        return $this->ok($items);
    }

    /**
     * GET /api/v1/dashboard/parameter-abnormal?limit=&days=  (Supervisor/Admin)
     *
     * Sorotan nilai checklist yang di luar ambang normal. Ambang diturunkan
     * dari nama spesifikasi (portabel, tanpa kolom ambang di DB).
     */
    public function parameterAbnormal(Request $request): JsonResponse
    {
        $limit = max(1, min(200, (int) $request->input('limit', 50)));
        $days = max(1, min(365, (int) $request->input('days', 90)));
        $batas = now()->subDays($days);

        $items = DetailMaintenance::with(['spesifikasi', 'maintenance'])
            ->whereHas('maintenance', fn ($q) => $q->where('waktu_maintenance', '>=', $batas))
            ->get()
            ->map(function (DetailMaintenance $detail) {
                $spec = $detail->spesifikasi;
                $maintenance = $detail->maintenance;

                if ($spec === null || $maintenance === null) {
                    return null;
                }

                $status = trim((string) $detail->status);
                $ambang = $this->ambangPelanggaran($spec, $status);

                if ($ambang === null) {
                    return null;
                }

                return [
                    'barcode_alat' => $maintenance->barcode_alat,
                    'nama_spesifikasi' => $spec->nama_spesifikasi,
                    'nilai' => $status,
                    'satuan' => $spec->satuan,
                    'ambang' => $ambang,
                    'waktu' => $maintenance->waktu_maintenance?->format('Y-m-d H:i:s'),
                ];
            })
            ->filter()
            ->sortByDesc('waktu')
            ->take($limit)
            ->values();

        return $this->ok($items);
    }

    /**
     * Tentukan apakah sebuah nilai checklist melanggar ambang; kembalikan
     * deskripsi ambang bila abnormal, atau null bila normal / tak dapat dinilai.
     */
    private function ambangPelanggaran(Spesifikasi $spec, string $status): ?string
    {
        if ($spec->tipe_input === 'number') {
            $rentang = $this->rentangNormal((string) $spec->nama_spesifikasi);

            if ($rentang === null || ! is_numeric($status)) {
                return null;
            }

            [$min, $max] = $rentang;
            $nilai = (float) $status;

            if ($nilai >= $min && $nilai <= $max) {
                return null;
            }

            return $nilai < $min ? ">={$min}" : "<={$max}";
        }

        if ($spec->tipe_input === 'select') {
            if (! in_array(mb_strtolower($status), self::NILAI_TIDAK_NORMAL, true)) {
                return null;
            }

            return 'nilai normal';
        }

        return null;
    }

    /**
     * Rentang normal per jenis pengukuran (mengikuti skala data contoh).
     *
     * @return array{0: float, 1: float}|null
     */
    private function rentangNormal(string $nama): ?array
    {
        $n = mb_strtolower($nama);

        return match (true) {
            str_contains($n, 'voltage'), str_contains($n, 'tegangan') => [215.0, 230.0],
            str_contains($n, 'ampere'), str_contains($n, 'arus') => [2.0, 15.0],
            str_contains($n, 'freon'), str_contains($n, 'tekanan') => [4.0, 9.0],
            str_contains($n, 'suhu') => [26.0, 38.0],
            str_contains($n, 'frekuensi') => [49.0, 51.0],
            str_contains($n, 'tahanan') => [1.0, 5.0],
            str_contains($n, 'tinggi') => [4.0, 8.0],
            str_contains($n, 'berat') => [3.0, 7.0],
            str_contains($n, 'jam') => [100.0, 900.0],
            default => null,
        };
    }

    /**
     * GET /api/v1/dashboard/export?format=csv&dari=&sampai=  (Supervisor/Admin)
     *
     * CSV dibangkitkan PHP tanpa pustaka. Respons BINER di luar envelope —
     * klien memakai `ResponseType.bytes` pada Dio.
     */
    public function export(Request $request): StreamedResponse
    {
        $dari = $request->input('dari') ?: now()->startOfMonth()->toDateString();
        $sampai = $request->input('sampai') ?: now()->toDateString();

        $rows = Maintenance::with(['alat.kategori', 'lokasi', 'user'])
            ->whereDate('waktu_maintenance', '>=', $dari)
            ->whereDate('waktu_maintenance', '<=', $sampai)
            ->orderBy('waktu_maintenance')
            ->get();

        $filename = "meiv-laporan-{$dari}_{$sampai}.csv";

        return response()->streamDownload(function () use ($rows) {
            $out = fopen('php://output', 'w');

            // Header ditulis manual, bukan lewat fputcsv: fputcsv otomatis
            // mengapit field yang mengandung spasi dengan tanda kutip sehingga
            // header keluar sebagai `"Status Verifikasi"`. Tidak ada nama kolom
            // yang mengandung koma, jadi menulis langsung tetap CSV yang sah
            // dan lebih mudah dibaca manusia.
            fwrite($out, "ID,Waktu,Teknisi,Barcode,Kategori,Lokasi,Kondisi,Status Verifikasi\n");

            foreach ($rows as $maintenance) {
                fputcsv($out, [
                    $maintenance->id_maintenance,
                    $maintenance->waktu_maintenance?->format('Y-m-d H:i:s'),
                    $maintenance->nama_users,
                    $maintenance->barcode_alat,
                    $maintenance->nama_kategori,
                    $maintenance->nama_lokasi,
                    $maintenance->kondisi_keseluruhan,
                    $maintenance->status_verifikasi,
                ], ',', '"', '');
            }

            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
