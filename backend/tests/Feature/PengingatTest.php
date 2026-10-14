<?php

namespace Tests\Feature;

use App\Models\Maintenance;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Pengingat — AC-B1…AC-B3 (`docs/DESIGN-FEATURES-V3.md` §10.2–10.3).
 */
class PengingatTest extends TestCase
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

    // ---------------------------------------------------------------- AC-B1

    public function test_pengingat_teknisi_mengembalikan_bentuk_benar(): void
    {
        $token = $this->token('67890');

        $response = $this->withToken($token)
            ->getJson('/api/v1/pengingat')
            ->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonStructure(['data' => [
                'ringkasan' => ['jatuh_tempo', 'terlambat', 'menunggu_verifikasi'],
                'daftar',
            ]]);

        $ringkasan = $response->json('data.ringkasan');
        $daftar = $response->json('data.daftar');

        // Jumlah daftar == total ringkasan (lencana dapat dihitung tanpa query ulang).
        $this->assertSame(
            $ringkasan['jatuh_tempo'] + $ringkasan['terlambat'] + $ringkasan['menunggu_verifikasi'],
            count($daftar),
        );

        // Teknisi tidak pernah punya item "menunggu verifikasi".
        $this->assertSame(0, $ringkasan['menunggu_verifikasi']);
    }

    // ---------------------------------------------------------------- AC-B2

    public function test_pengingat_supervisor_menunggu_verifikasi_sesuai_pending_count(): void
    {
        $supervisor = $this->token('11111');
        $expected = Maintenance::where('status_verifikasi', 'menunggu')->count();

        $this->withToken($supervisor)
            ->getJson('/api/v1/pengingat')
            ->assertOk()
            ->assertJsonPath('data.ringkasan.menunggu_verifikasi', $expected)
            ->assertJsonCount($expected, 'data.daftar');

        // Konsisten dengan endpoint pending/count yang sudah ada.
        $this->withToken($supervisor)
            ->getJson('/api/v1/maintenance/pending/count')
            ->assertOk()
            ->assertJsonPath('data.menunggu', $expected);
    }

    public function test_pengingat_admin_ok(): void
    {
        $admin = $this->token('12345');
        $expected = Maintenance::where('status_verifikasi', 'menunggu')->count();

        $this->withToken($admin)
            ->getJson('/api/v1/pengingat')
            ->assertOk()
            ->assertJsonPath('data.ringkasan.menunggu_verifikasi', $expected);
    }

    // ---------------------------------------------------------------- AC-B3

    public function test_teknisi_tidak_boleh_pending_count_403(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->getJson('/api/v1/maintenance/pending/count')
            ->assertStatus(403);
    }

    public function test_supervisor_tidak_boleh_tugas_hari_ini_403(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/tugas-hari-ini')
            ->assertStatus(403);
    }
}
