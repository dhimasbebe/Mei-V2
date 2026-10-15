<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use SimpleSoftwareIO\QrCode\Facades\QrCode;
use Symfony\Component\HttpFoundation\Response;

/**
 * Cetak label QR massal (WS N, Fitur Tahap 3) — Supervisor/Admin.
 * `docs/DESIGN-FEATURES-V3.md` §C.2.4, `docs/PRD-FEATURES-V3.md` §N.
 *
 * | Metode | Endpoint                             | Role             |
 * |--------|--------------------------------------|------------------|
 * | POST   | /api/v1/dashboard/export/qr-labels   | Supervisor, Admin|
 *
 * Body: { "barcode": ["AC-001", ...] } → PDF grid label (tiap label:
 * QR + teks barcode + merk + kategori + lokasi), grid 2x4 per halaman A4.
 *
 * Catatan render QR: imagick TIDAK tersedia di lingkungan ini sehingga
 * `format('png')` (butuh Imagick) tidak dapat dipakai — QR dibangkitkan
 * `format('svg')` (tanpa ekstensi) dan ditanam sebagai data-URI di blade.
 * Hasil pindai tetap sama (AC-N5, verifikasi manual).
 */
class QrLabelController extends Controller
{
    /** Ukuran QR dalam piksel SVG. */
    public const UKURAN_QR = 220;

    /**
     * POST /api/v1/dashboard/export/qr-labels  (Supervisor, Admin)
     *
     * 422 bila: daftar kosong/tanpa field (AC-N3) atau ada barcode yang
     * tidak dikenal (AC-N2, dilaporkan daftarnya). 403 untuk Teknisi (AC-N4).
     */
    public function store(Request $request): Response
    {
        $validated = $request->validate([
            'barcode' => 'required|array|min:1',
            'barcode.*' => 'required|string|max:100',
        ]);

        // Unik + pertahankan urutan permintaan.
        $diminta = array_values(array_unique($validated['barcode']));

        $ditemukan = Alat::with(['kategori', 'lokasi'])
            ->whereIn('barcode_alat', $diminta)
            ->get()
            ->keyBy('barcode_alat');

        $takDikenal = array_values(array_filter(
            $diminta,
            fn (string $b) => ! $ditemukan->has($b),
        ));

        if ($takDikenal !== []) {
            throw ValidationException::withMessages([
                'barcode' => ['Barcode tidak dikenal: '.implode(', ', $takDikenal)],
            ]);
        }

        $labels = $ditemukan->sortBy('barcode_alat')->values()->map(function (Alat $alat) {
            $svg = QrCode::format('svg')
                ->size(self::UKURAN_QR)
                ->generate($alat->barcode_alat);

            return [
                'barcode_alat' => $alat->barcode_alat,
                'merk_alat' => $alat->merk_alat,
                'nama_kategori' => $alat->nama_kategori,
                'nama_lokasi' => $alat->nama_lokasi,
                'lantai' => $alat->lantai,
                'qr' => 'data:image/svg+xml;base64,'.base64_encode((string) $svg),
            ];
        })->all();

        return Pdf::loadView('pdf.qr-labels', ['labels' => $labels])
            ->download('meiv-label-qr.pdf');
    }
}
