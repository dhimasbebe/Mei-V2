<?php

namespace Tests\Feature;

use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Guard peran di server (dua lapis dengan guard klien).
 *
 * Membuktikan: login dengan role salah ditolak 403, dan middleware `role`
 * mencegah lintas peran pada endpoint sensitif.
 */
class RoleAccessTest extends TestCase
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

        $response->assertOk()->assertJsonPath('code', 200);

        return (string) $response->json('data.token');
    }

    public function test_login_dengan_role_cocok_berhasil(): void
    {
        $this->postJson('/api/v1/auth/login', [
            'username' => '12345',
            'password' => 'password',
            'role' => 'Admin',
        ])
            ->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonPath('data.user.role_users', 'Admin')
            ->assertJsonStructure(['data' => ['token', 'user']]);
    }

    public function test_login_dengan_role_tidak_cocok_ditolak_403(): void
    {
        $this->postJson('/api/v1/auth/login', [
            'username' => '12345',
            'password' => 'password',
            'role' => 'Teknisi',
        ])
            ->assertStatus(403)
            ->assertJsonPath('code', 403)
            ->assertJsonPath('data', null)
            ->assertJsonPath('message', 'Role yang dipilih tidak sesuai dengan akun ini.');
    }

    public function test_login_tanpa_role_tetap_berhasil_kompatibilitas(): void
    {
        $this->postJson('/api/v1/auth/login', [
            'username' => '67890',
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonPath('data.user.role_users', 'Teknisi');
    }

    public function test_login_role_tidak_dikenal_ditolak_422(): void
    {
        $this->postJson('/api/v1/auth/login', [
            'username' => '12345',
            'password' => 'password',
            'role' => 'Manajer',
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 422)
            ->assertJsonStructure(['code', 'data', 'message', 'errors']);
    }

    public function test_teknisi_ditolak_di_endpoint_admin(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->getJson('/api/v1/users')
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }

    public function test_teknisi_ditolak_di_endpoint_supervisor(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->getJson('/api/v1/maintenance/pending')
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }

    public function test_supervisor_ditolak_di_endpoint_admin(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/users')
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }

    public function test_admin_boleh_akses_manajemen_user(): void
    {
        $token = $this->token('12345');

        $this->withToken($token)
            ->getJson('/api/v1/users')
            ->assertOk()
            ->assertJsonPath('code', 200);
    }

    public function test_supervisor_boleh_akses_antrean_verifikasi(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/maintenance/pending')
            ->assertOk()
            ->assertJsonPath('code', 200);
    }

    public function test_endpoint_baru_menolak_tanpa_token(): void
    {
        $this->getJson('/api/v1/users')->assertStatus(401);
        $this->getJson('/api/v1/maintenance/pending')->assertStatus(401);
        $this->getJson('/api/v1/tugas-hari-ini')->assertStatus(401);
        $this->getJson('/api/v1/audit-log')->assertStatus(401);
    }
}
