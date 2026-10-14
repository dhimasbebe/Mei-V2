<?php

namespace Tests\Feature;

use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * "Tugas Hari Ini" (Teknisi) — dihitung di server dari maintenance + siklus.
 */
class TugasTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function token(string $username): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    public function test_teknisi_mendapat_tugas_hari_ini(): void
    {
        $token = $this->token('67890');

        $response = $this->withToken($token)
            ->getJson('/api/v1/tugas-hari-ini')
            ->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonStructure(['data' => [
                'ringkasan' => ['total', 'overdue', 'jatuh_tempo_hari_ini'],
                'daftar' => [[
                    'barcode_alat',
                    'merk_alat',
                    'nama_kategori',
                    'nama_lokasi',
                    'lantai',
                    'terlambat_hari',
                    'status',
                    'terakhir_maintenance',
                ]],
            ]]);

        $this->assertGreaterThanOrEqual(1, (int) $response->json('data.ringkasan.total'));

        foreach ($response->json('data.daftar') as $item) {
            $this->assertContains($item['status'], ['overdue', 'jatuh_tempo', 'terjadwal']);
        }
    }

    public function test_supervisor_tidak_boleh_mengakses_tugas_hari_ini(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/tugas-hari-ini')
            ->assertStatus(403);
    }

    public function test_admin_tidak_boleh_mengakses_tugas_hari_ini(): void
    {
        $token = $this->token('12345');

        $this->withToken($token)
            ->getJson('/api/v1/tugas-hari-ini')
            ->assertStatus(403);
    }
}
