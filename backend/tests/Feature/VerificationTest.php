<?php

namespace Tests\Feature;

use App\Models\Maintenance;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Alur verifikasi maintenance oleh Supervisor (kolom pada tabel `maintenance`).
 */
class VerificationTest extends TestCase
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

    public function test_daftar_pending_hanya_menunggu_verifikasi(): void
    {
        $token = $this->token('11111');

        $response = $this->withToken($token)
            ->getJson('/api/v1/maintenance/pending?per_page=5')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'data',
                'current_page',
                'last_page',
                'per_page',
                'total',
            ]]);

        foreach ($response->json('data.data') as $row) {
            $this->assertSame('menunggu', $row['status_verifikasi']);
        }
    }

    public function test_hitung_pending(): void
    {
        $token = $this->token('11111');

        $expected = Maintenance::where('status_verifikasi', 'menunggu')->count();

        $this->withToken($token)
            ->getJson('/api/v1/maintenance/pending/count')
            ->assertOk()
            ->assertJsonPath('data.menunggu', $expected);
    }

    public function test_verifikasi_setujui_mengubah_status(): void
    {
        $token = $this->token('11111');
        $maintenance = Maintenance::where('status_verifikasi', 'menunggu')->firstOrFail();

        $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$maintenance->id_maintenance}/verify", [
                'status' => 'disetujui',
                'komentar' => 'Data lengkap.',
            ])
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'disetujui')
            ->assertJsonPath('data.diverifikasi_oleh', '11111')
            ->assertJsonPath('data.komentar_verifikasi', 'Data lengkap.');

        $fresh = $maintenance->fresh();

        $this->assertSame('disetujui', $fresh->status_verifikasi);
        $this->assertSame('11111', $fresh->diverifikasi_oleh);
        $this->assertNotNull($fresh->waktu_verifikasi);
    }

    public function test_verifikasi_tolak_mengubah_status(): void
    {
        $token = $this->token('11111');
        $maintenance = Maintenance::where('status_verifikasi', 'menunggu')->firstOrFail();

        $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$maintenance->id_maintenance}/verify", [
                'status' => 'ditolak',
                'komentar' => 'Foto kurang jelas.',
            ])
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'ditolak');

        $this->assertSame('ditolak', $maintenance->fresh()->status_verifikasi);
    }

    public function test_verifikasi_status_tidak_valid_ditolak_422(): void
    {
        $token = $this->token('11111');
        $maintenance = Maintenance::where('status_verifikasi', 'menunggu')->firstOrFail();

        $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$maintenance->id_maintenance}/verify", [
                'status' => 'menunggu',
            ])
            ->assertStatus(422)
            ->assertJsonStructure(['code', 'data', 'message', 'errors']);
    }

    public function test_teknisi_tidak_boleh_memverifikasi(): void
    {
        $token = $this->token('67890');
        $maintenance = Maintenance::where('status_verifikasi', 'menunggu')->firstOrFail();

        $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$maintenance->id_maintenance}/verify", [
                'status' => 'disetujui',
            ])
            ->assertStatus(403);
    }

    public function test_papan_overdue_supervisor(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/maintenance/overdue?limit=5')
            ->assertOk()
            ->assertJsonStructure(['data' => [['barcode_alat', 'merk_alat', 'terlambat_hari']]]);
    }

    public function test_riwayat_dapat_disaring_status_verifikasi(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/maintenance?status_verifikasi=menunggu&per_page=5')
            ->assertOk()
            ->assertJsonPath('code', 200);
    }
}
