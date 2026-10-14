<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Lokasi;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Impor massal alat dari CSV (WS M, Fitur Tahap 3) — Admin.
 * `docs/DESIGN-FEATURES-V3.md` §C.2.5, `docs/PRD-FEATURES-V3.md` §M.
 *
 * | Metode | Endpoint                    | Role  |
 * |--------|-----------------------------|-------|
 * | POST   | /api/v1/alat/impor/preview  | Admin | validasi per baris, TANPA menulis DB (AC-M1)
 * | POST   | /api/v1/alat/impor/commit   | Admin | impor hanya baris valid (AC-M2)
 *
 * Dua sumber input didukung (AC-M9):
 * - multipart field `file`  → berkas CSV (web, pola unggah foto)
 * - field teks `csv`        → isi CSV ditempel langsung (ponsel)
 *
 * Parsing memakai `fgetcsv` bawaan PHP — tanpa paket composer.
 * Kolom CSV (berheader, urutan tetap): barcode_alat, merk_alat, nama_kategori, nama_lokasi.
 */
class AlatImportController extends Controller
{
    /** Header kolom CSV yang diharapkan (baris pertama, bila ada). */
    private const HEADER = ['barcode_alat', 'merk_alat', 'nama_kategori', 'nama_lokasi'];

    /** Batas jumlah baris data yang diproses per permintaan. */
    public const MAX_BARIS = 1000;

    /**
     * POST /api/v1/alat/impor/preview  (Admin)
     *
     * Memvalidasi CSV per baris TANPA menulis DB (AC-M1).
     * Respons 200: data = { total, jumlah_valid, error: [{baris, pesan}] }.
     */
    public function preview(Request $request): JsonResponse
    {
        [$rows, $errors] = $this->parseDanValidasi($this->ambilIsiCsv($request));

        return $this->ok([
            'total' => count($rows),
            'jumlah_valid' => count($rows) - count($errors),
            'error' => $errors,
        ]);
    }

    /**
     * POST /api/v1/alat/impor/commit  (Admin)
     *
     * Menulis HANYA baris valid dalam satu transaksi (AC-M2).
     * 0 baris valid → 422 (AC-M3). Baris duplikat ditolak dan dilaporkan.
     * Aksi tercatat di audit log aksi `import`, entitas `alat` (AC-M5).
     */
    public function commit(Request $request): JsonResponse
    {
        [$rows, $errors] = $this->parseDanValidasi($this->ambilIsiCsv($request));

        $indeksGagal = array_column($errors, 'baris', 'baris');
        $valid = array_filter($rows, fn (array $r) => ! isset($indeksGagal[$r['baris']]));

        if ($valid === []) {
            throw ValidationException::withMessages([
                'csv' => ['Tidak ada baris valid untuk diimpor.'],
            ]);
        }

        $diimpor = DB::transaction(function () use ($valid) {
            $n = 0;

            foreach ($valid as $r) {
                Alat::create([
                    'barcode_alat' => $r['barcode_alat'],
                    'merk_alat' => $r['merk_alat'],
                    'id_kategori' => $r['id_kategori'],
                    'id_lokasi' => $r['id_lokasi'],
                ]);
                $n++;
            }

            return $n;
        });

        $total = count($rows);
        $gagal = $total - $diimpor;

        AuditLogger::log('import', 'alat', 'csv', [
            'total' => $total,
            'valid' => $diimpor,
            'gagal' => $gagal,
        ]);

        return $this->ok([
            'total' => $total,
            'diimpor' => $diimpor,
            'gagal' => $gagal,
            'error' => $errors,
        ], "$diimpor alat berhasil diimpor.", 201);
    }

    // ------------------------------------------------------------------
    // Parsing & validasi
    // ------------------------------------------------------------------

    /**
     * Ambil isi CSV dari unggahan (`file`) atau teks tempelan (`csv`).
     */
    private function ambilIsiCsv(Request $request): string
    {
        if ($request->hasFile('file')) {
            $request->validate([
                'file' => 'required|file|mimes:csv,txt|max:1024',
            ]);

            /** @var UploadedFile $file */
            $file = $request->file('file');

            return (string) $file->getContent();
        }

        $request->validate([
            'csv' => 'required|string|max:200000',
        ]);

        return (string) $request->input('csv');
    }

    /**
     * Parse CSV dengan fgetcsv dan validasi setiap baris.
     *
     * Mengembalikan [daftar baris terurai, daftar error {baris, pesan}].
     * Metode ini TIDAK pernah menulis DB — dipakai bersama oleh preview
     * dan commit sehingga himpunan "baris valid" identik di kedua tahap.
     *
     * Validasi per baris (PRD M.2):
     * - kolom wajib kosong;
     * - barcode duplikat di DB dan di dalam berkas;
     * - nama_kategori / nama_lokasi tak dikenal.
     *
     * Nomor `baris` adalah nomor baris fisik berkas (1-based, baris header
     * tetap dihitung) agar admin dapat menemukannya langsung di berkas.
     *
     * SEMUA baris data (valid maupun gagal) masuk daftar pertama sehingga
     * `total` = jumlah baris CSV; baris gagal memiliki kolom terurai null
     * dan penjelasannya ada di daftar kedua.
     *
     * @return array{0: list<array{baris:int, barcode_alat:?string, merk_alat:?string, nama_kategori:?string, nama_lokasi:?string, id_kategori:?int, id_lokasi:?int}>, 1: list<array{baris:int, pesan:string}>}
     */
    private function parseDanValidasi(string $isi): array
    {
        $rows = [];
        $errors = [];

        // PHP 8.4+ menandai $escape bawaan sebagai deprecated; parameter
        // eksplisit membuat perilaku identik di semua versi.
        $stream = fopen('php://temp', 'r+');
        fwrite($stream, $isi);
        rewind($stream);

        $barcodeDiBerkas = [];
        $nomorBaris = 0;

        while (($kolom = fgetcsv($stream, 0, ',', '"', '\\')) !== false) {
            $nomorBaris++;

            if ($nomorBaris > self::MAX_BARIS + 1) {
                $errors[] = [
                    'baris' => $nomorBaris,
                    'pesan' => 'Jumlah baris melebihi batas '.self::MAX_BARIS.' — sisa berkas diabaikan',
                ];

                break;
            }

            // Baris kosong (hanya spasi/null) dilewati tanpa error.
            if (implode('', array_map('trim', array_map('strval', $kolom))) === '') {
                continue;
            }

            // Baris header (di mana pun posisinya) dilewati.
            if (array_map('strtolower', array_map('trim', $kolom)) === self::HEADER) {
                continue;
            }

            $barcode = trim((string) ($kolom[0] ?? ''));
            $merk = trim((string) ($kolom[1] ?? ''));
            $namaKategori = trim((string) ($kolom[2] ?? ''));
            $namaLokasi = trim((string) ($kolom[3] ?? ''));

            $row = [
                'baris' => $nomorBaris,
                'barcode_alat' => $barcode !== '' ? $barcode : null,
                'merk_alat' => $merk !== '' ? $merk : null,
                'nama_kategori' => $namaKategori !== '' ? $namaKategori : null,
                'nama_lokasi' => $namaLokasi !== '' ? $namaLokasi : null,
                'id_kategori' => null,
                'id_lokasi' => null,
            ];

            $pesan = $this->validasiBaris($barcode, $merk, $namaKategori, $namaLokasi, $barcodeDiBerkas);

            if ($pesan !== null) {
                $errors[] = ['baris' => $nomorBaris, 'pesan' => $pesan];
                $rows[] = $row;

                continue;
            }

            // Resolve nama -> id SEKARANG (sekali per baris), dipakai ulang
            // di commit tanpa query ulang.
            $row['id_kategori'] = (int) Kategori::where('nama', $namaKategori)->value('id_kategori');
            $row['id_lokasi'] = (int) Lokasi::where('nama_lokasi', $namaLokasi)->value('id_lokasi');
            $barcodeDiBerkas[mb_strtolower($barcode)] = $nomorBaris;

            $rows[] = $row;
        }

        fclose($stream);

        return [$rows, $errors];
    }

    /**
     * Validasi satu baris. Mengembalikan null bila valid, atau pesan error.
     *
     * @param  array<string, int>  $barcodeDiBerkas  barcode (lowercase) => nomor baris asal
     */
    private function validasiBaris(
        string $barcode,
        string $merk,
        string $namaKategori,
        string $namaLokasi,
        array $barcodeDiBerkas,
    ): ?string {
        // --- kolom wajib kosong ---
        if ($barcode === '' || $merk === '' || $namaKategori === '' || $namaLokasi === '') {
            $kosong = [];
            if ($barcode === '') $kosong[] = 'barcode_alat';
            if ($merk === '') $kosong[] = 'merk_alat';
            if ($namaKategori === '') $kosong[] = 'nama_kategori';
            if ($namaLokasi === '') $kosong[] = 'nama_lokasi';

            return 'Kolom wajib kosong: '.implode(', ', $kosong);
        }

        // --- duplikat di dalam berkas ---
        $kunci = mb_strtolower($barcode);
        if (isset($barcodeDiBerkas[$kunci])) {
            return "Barcode '$barcode' duplikat di dalam berkas (baris {$barcodeDiBerkas[$kunci]})";
        }

        // --- duplikat di DB ---
        if (Alat::where('barcode_alat', $barcode)->exists()) {
            return "Barcode '$barcode' sudah terdaftar di database";
        }

        // --- kategori tak dikenal ---
        if (! Kategori::where('nama', $namaKategori)->exists()) {
            return "Kategori '$namaKategori' tidak dikenal";
        }

        // --- lokasi tak dikenal ---
        if (! Lokasi::where('nama_lokasi', $namaLokasi)->exists()) {
            return "Lokasi '$namaLokasi' tidak dikenal";
        }

        return null;
    }
}
