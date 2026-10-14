<?php

namespace Tests\Feature;

use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Log audit (Admin) — jejak aksi CRUD, verifikasi, penugasan, dan login.
 */
class AuditLogTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function token(string $username = '12345'): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    public function test_login_tercatat_di_log_audit(): void
    {
        $token = $this->token('12345');

        $this->withToken($token)
            ->getJson('/api/v1/audit-log?aksi=login')
            ->assertOk()
            ->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.data.0.actor_username', '12345')
            ->assertJsonPath('data.data.0.entitas', 'users');
    }

    public function test_crud_pengguna_tercatat_di_log_audit(): void
    {
        $token = $this->token();

        $this->withToken($token)->postJson('/api/v1/users', [
            'username' => '67894',
            'nama_users' => 'Teknisi E',
            'role_users' => 'Teknisi',
            'password' => 'rahasia123',
        ])->assertStatus(201);

        $this->withToken($token)
            ->getJson('/api/v1/audit-log?entitas=users&aksi=create')
            ->assertOk()
            ->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.data.0.entitas_id', '67894')
            ->assertJsonPath('data.data.0.actor_username', '12345');
    }

    public function test_verifikasi_tercatat_di_log_audit(): void
    {
        $supervisor = $this->token('11111');
        $maintenance = \App\Models\Maintenance::where('status_verifikasi', 'menunggu')->firstOrFail();

        $this->withToken($supervisor)
            ->postJson("/api/v1/maintenance/{$maintenance->id_maintenance}/verify", [
                'status' => 'disetujui',
            ])
            ->assertOk();

        $this->withToken($supervisor)
            ->getJson('/api/v1/audit-log?entitas=maintenance&aksi=verify')
            ->assertOk()
            ->assertJsonPath('data.total', 1);
    }

    public function test_struktur_log_audit(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->getJson('/api/v1/audit-log?per_page=5')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'data' => [[
                    'id_audit',
                    'actor_username',
                    'aksi',
                    'entitas',
                    'entitas_id',
                    'detail',
                    'created_at',
                ]],
                'current_page',
                'last_page',
                'per_page',
                'total',
            ]]);
    }

    public function test_teknisi_tidak_boleh_melihat_log_audit(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->getJson('/api/v1/audit-log')
            ->assertStatus(403);
    }
}
