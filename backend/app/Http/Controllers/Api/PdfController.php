<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Maintenance;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Ekspor PDF laporan (WS L, Fitur Tahap 3) — Supervisor/Admin.
 * `docs/DESIGN-FEATURES-V3.md` §C.2.4, `docs/PRD-FEATURES-V3.md` §L.
 *
 * | Metode | Endpoint                          | Role             |
 * |--------|-----------------------------------|------------------|
 * | GET    | /api/v1/maintenance/{id}/pdf      | Supervisor, Admin|
 * | GET    | /api/v1/dashboard/export/pdf      | Supervisor, Admin|
 *
 * Respons BINER MURNI (application/pdf, body diawali %PDF) — TANPA envelope
 * JSON, pola sama dengan ekspor CSV `DashboardController::export`. Klien
 * Flutter memakai Dio `ResponseType.bytes` seperti `exportLaporan()`.
 *
 * Pengaman dompdf di shared hosting (R11): rentang PDF periode dibatasi
 * MAKSIMUM 90 hari DAN maksimum 500 baris → 422 bila melebihi.
 */
class PdfController extends Controller
{
    /** Batas rentang PDF periode (hari) — R11. */
    public const MAX_HARI = 90;

    /** Batas jumlah baris laporan dalam satu PDF periode — R11. */
    public const MAX_BARIS = 500;

    /**
     * GET /api/v1/maintenance/{id}/pdf  (Supervisor, Admin)
     *
     * PDF resmi SATU laporan: identitas, kondisi, tabel checklist lengkap,
     * status verifikasi, logo Mei-V (AC-L4). Tanpa batas rentang (satu
     * laporan saja — §C.2.4).
     */
    public function show(int $id): Response|JsonResponse
    {
        $m = Maintenance::with([
            'alat.kategori',
            'lokasi',
            'user',
            'detail.spesifikasi',
        ])->find($id);

        if ($m === null) {
            return $this->error('Data tidak ditemukan.', 404);
        }

        return Pdf::loadView('pdf.maintenance', ['m' => $m])
            ->download("meiv-laporan-{$id}.pdf");
    }

    /**
     * GET /api/v1/dashboard/export/pdf?dari=&sampai=  (Supervisor, Admin)
     *
     * PDF ringkasan periode. Validasi: tanggal wajib, `sampai >= dari`,
     * rentang maksimum 90 hari, maksimum 500 baris → 422 bila melanggar
     * (AC-L3, R11).
     */
    public function periode(Request $request): Response
    {
        $validated = $request->validate([
            'dari' => 'required|date',
            'sampai' => 'required|date|after_or_equal:dari',
        ]);

        $dari = Carbon::parse($validated['dari'])->startOfDay();
        $sampai = Carbon::parse($validated['sampai'])->endOfDay();

        // Pengaman R11 #1: rentang maksimum 90 hari.
        if ((int) $dari->diffInDays($sampai) + 1 > self::MAX_HARI) {
            throw ValidationException::withMessages([
                'sampai' => ['Rentang maksimal '.self::MAX_HARI.' hari.'],
            ]);
        }

        $rows = Maintenance::with(['alat.kategori', 'lokasi', 'user'])
            ->whereBetween('waktu_maintenance', [$dari, $sampai])
            ->orderBy('waktu_maintenance')
            ->get();

        // Pengaman R11 #2: maksimum 500 baris.
        if ($rows->count() > self::MAX_BARIS) {
            throw ValidationException::withMessages([
                'sampai' => ['Jumlah laporan melebihi '.self::MAX_BARIS.' baris.'],
            ]);
        }

        return Pdf::loadView('pdf.periode', [
            'dari' => $dari,
            'sampai' => $sampai,
            'rows' => $rows,
        ])->download("meiv-ringkasan-{$dari->toDateString()}_{$sampai->toDateString()}.pdf");
    }
}
