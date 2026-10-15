<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\Maintenance;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Ekspor PDF laporan (WS L, Fitur Tahap 3) — AC-L1…AC-L5
 * (`docs/PRD-FEATURES-V3.md` §L.3, `docs/DESIGN-FEATURES-V3.md` §C.2.4).
 */
class PdfExportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function token(string $username = '11111'): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    private function assertPdf($response): void
    {
        $response->assertStatus(200);
        $this->assertStringContainsString('application/pdf', (string) $response->headers->get('Content-Type'));
        $this->assertStringStartsWith('%PDF', (string) $response->getContent());
    }

    // ---------------------------------------------------------------- AC-L1

    public function test_pdf_per_laporan_mengembalikan_biner_pdf(): void
    {
        $m = Maintenance::firstOrFail();

        $this->assertPdf(
            $this->withToken($this->token())
                ->get("/api/v1/maintenance/{$m->id_maintenance}/pdf")
        );
    }

    public function test_pdf_periode_mengembalikan_biner_pdf(): void
    {
        $this->assertPdf(
            $this->withToken($this->token())
                ->get('/api/v1/dashboard/export/pdf?dari='.now()->subDays(7)->toDateString().'&sampai='.now()->toDateString())
        );
    }

    public function test_pdf_per_laporan_tidak_ditemukan_menghasilkan_404(): void
    {
        $this->withToken($this->token())
            ->getJson('/api/v1/maintenance/999999/pdf')
            ->assertStatus(404)
            ->assertJsonPath('code', 404);
    }

    // ---------------------------------------------------------------- AC-L2

    public function test_teknisi_ditolak_403_dan_tanpa_token_401(): void
    {
        // Cek 401 DULU: `withToken` menyetel header bawaan yang bertahan
        // sepanjang test (lihat catatan FotoTest) — setelah token teknisi
        // dipasang, request berikutnya tidak lagi "tanpa token".
        $this->getJson('/api/v1/maintenance/999999/pdf')
            ->assertStatus(401)
            ->assertJsonPath('code', 401);

        $this->getJson('/api/v1/dashboard/export/pdf?dari=2026-01-01&sampai=2026-01-31')
            ->assertStatus(401)
            ->assertJsonPath('code', 401);

        $m = Maintenance::firstOrFail();

        $this->withToken($this->token('67890'))
            ->getJson("/api/v1/maintenance/{$m->id_maintenance}/pdf")
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->getJson('/api/v1/dashboard/export/pdf?dari=2026-01-01&sampai=2026-01-31')
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }

    // ---------------------------------------------------------------- AC-L3

    public function test_pdf_periode_sampai_sebelum_dari_menghasilkan_422(): void
    {
        $this->withToken($this->token())
            ->getJson('/api/v1/dashboard/export/pdf?dari=2026-02-10&sampai=2026-02-01')
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    public function test_pdf_periode_tanggal_wajib(): void
    {
        $this->withToken($this->token())
            ->getJson('/api/v1/dashboard/export/pdf')
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    // ------------------------------------------------- pengaman R11

    public function test_pdf_periode_lebih_dari_90_hari_menghasilkan_422(): void
    {
        $dari = now()->subDays(91)->toDateString();
        $sampai = now()->toDateString();

        $this->withToken($this->token())
            ->getJson("/api/v1/dashboard/export/pdf?dari={$dari}&sampai={$sampai}")
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    public function test_pdf_periode_lebih_dari_500_baris_menghasilkan_422(): void
    {
        $alat = Alat::firstOrFail();

        // 501 laporan dalam rentang 10 hari (di bawah batas hari).
        for ($i = 0; $i < 501; $i++) {
            Maintenance::create([
                'client_uuid' => "test-pdf-r11-{$i}",
                'barcode_alat' => $alat->barcode_alat,
                'username' => '67890',
                'id_lokasi' => $alat->id_lokasi,
                'id_kategori' => $alat->id_kategori,
                'waktu_maintenance' => now()->subDays($i % 10),
                'kondisi_keseluruhan' => 'baik',
                'status_verifikasi' => 'menunggu',
            ]);
        }

        $this->withToken($this->token())
            ->getJson('/api/v1/dashboard/export/pdf?dari='.now()->subDays(10)->toDateString().'&sampai='.now()->toDateString())
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    // ---------------------------------------------------------------- AC-L5

    public function test_ekspor_csv_lama_tetap_berjalan(): void
    {
        $response = $this->withToken($this->token())
            ->get('/api/v1/dashboard/export?format=csv');

        $response->assertStatus(200);
        $this->assertStringContainsString('text/csv', (string) $response->headers->get('Content-Type'));
    }

    // ------------------------------------------------- akses role

    public function test_admin_dan_supervisor_diizinkan(): void
    {
        $m = Maintenance::firstOrFail();

        $this->withToken($this->token('12345'))
            ->get("/api/v1/maintenance/{$m->id_maintenance}/pdf")
            ->assertStatus(200);

        $this->withToken($this->token('11111'))
            ->get("/api/v1/maintenance/{$m->id_maintenance}/pdf")
            ->assertStatus(200);
    }
}
