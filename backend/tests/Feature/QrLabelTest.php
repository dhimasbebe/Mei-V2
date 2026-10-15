<?php

namespace Tests\Feature;

use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Cetak label QR massal (WS N, Fitur Tahap 3) — AC-N1…AC-N4
 * (`docs/PRD-FEATURES-V3.md` §N.3, `docs/DESIGN-FEATURES-V3.md` §C.2.4).
 */
class QrLabelTest extends TestCase
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

    // ---------------------------------------------------------------- AC-N1

    public function test_label_qr_mengembalikan_pdf_dengan_semua_barcode_valid(): void
    {
        $response = $this->withToken($this->token())
            ->postJson('/api/v1/dashboard/export/qr-labels', [
                'barcode' => ['AC-001', 'AC-002', 'GS-001'],
            ]);

        $response->assertStatus(200);
        $this->assertStringContainsString('application/pdf', (string) $response->headers->get('Content-Type'));
        $this->assertStringStartsWith('%PDF', (string) $response->getContent());
    }

    public function test_admin_juga_diizinkan(): void
    {
        $this->withToken($this->token('12345'))
            ->postJson('/api/v1/dashboard/export/qr-labels', ['barcode' => ['AC-001']])
            ->assertStatus(200);
    }

    // ---------------------------------------------------------------- AC-N2

    public function test_barcode_tidak_dikenal_menghasilkan_422_dengan_daftar(): void
    {
        $response = $this->withToken($this->token())
            ->postJson('/api/v1/dashboard/export/qr-labels', [
                'barcode' => ['AC-001', 'XX-999', 'YY-888'],
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('code', 422);

        // Daftar barcode tidak valid dilaporkan.
        $pesan = json_encode($response->json());
        $this->assertStringContainsString('XX-999', (string) $pesan);
        $this->assertStringContainsString('YY-888', (string) $pesan);
    }

    public function test_barcode_duplikat_dalam_daftar_diterima_sekali(): void
    {
        $this->withToken($this->token())
            ->postJson('/api/v1/dashboard/export/qr-labels', [
                'barcode' => ['AC-001', 'AC-001'],
            ])
            ->assertStatus(200);
    }

    // ---------------------------------------------------------------- AC-N3

    public function test_daftar_kosong_menghasilkan_422(): void
    {
        $this->withToken($this->token())
            ->postJson('/api/v1/dashboard/export/qr-labels', ['barcode' => []])
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    public function test_tanpa_field_barcode_menghasilkan_422(): void
    {
        $this->withToken($this->token())
            ->postJson('/api/v1/dashboard/export/qr-labels', [])
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    // ---------------------------------------------------------------- AC-N4

    public function test_teknisi_ditolak_403(): void
    {
        $this->withToken($this->token('67890'))
            ->postJson('/api/v1/dashboard/export/qr-labels', ['barcode' => ['AC-001']])
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }
}
