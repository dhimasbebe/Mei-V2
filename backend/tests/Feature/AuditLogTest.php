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

    // ------------------------------------------------- AC-D1 (Supervisor 200)

    public function test_supervisor_dapat_melihat_log_audit(): void
    {
        $supervisor = $this->token('11111');

        $this->withToken($supervisor)
            ->getJson('/api/v1/audit-log')
            ->assertOk()
            ->assertJsonPath('code', 200);
    }

    // ------------------------------------------------- AC-D2 (filter AND)

    public function test_filter_entitas_actor_aksi_bekerja_sebagai_and(): void
    {
        $token = $this->token();

        $this->withToken($token)->postJson('/api/v1/users', [
            'username' => '67894',
            'nama_users' => 'Teknisi E',
            'role_users' => 'Teknisi',
            'password' => 'rahasia123',
        ])->assertStatus(201);

        // entitas + aksi + actor yang cocok -> 1
        $this->withToken($token)
            ->getJson('/api/v1/audit-log?entitas=users&aksi=create&actor=12345')
            ->assertOk()
            ->assertJsonPath('data.total', 1);

        // actor yang tidak cocok -> 0 (membuktikan filter gabungan AND)
        $this->withToken($token)
            ->getJson('/api/v1/audit-log?entitas=users&aksi=create&actor=99999')
            ->assertOk()
            ->assertJsonPath('data.total', 0);
    }

    // ------------------------------------------------- AC-D3 (dari/sampai)

    public function test_filter_dari_sampai_mempersempit_berdasarkan_created_at(): void
    {
        \App\Models\AuditLog::create([
            'actor_username' => '12345', 'aksi' => 'create', 'entitas' => 'users',
            'entitas_id' => '90001', 'detail' => null, 'ip_address' => '127.0.0.1',
            'created_at' => '2020-01-10 08:00:00',
        ]);
        \App\Models\AuditLog::create([
            'actor_username' => '12345', 'aksi' => 'create', 'entitas' => 'users',
            'entitas_id' => '90002', 'detail' => null, 'ip_address' => '127.0.0.1',
            'created_at' => '2020-02-15 08:00:00',
        ]);

        $token = $this->token();

        // Hanya baris Februari (login audit "hari ini" tidak masuk rentang 2020).
        $this->withToken($token)
            ->getJson('/api/v1/audit-log?dari=2020-02-01&sampai=2020-02-28')
            ->assertOk()
            ->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.data.0.entitas_id', '90002');

        // Rentang lebih lebar mencakup keduanya.
        $this->withToken($token)
            ->getJson('/api/v1/audit-log?dari=2020-01-01&sampai=2020-12-31')
            ->assertOk()
            ->assertJsonPath('data.total', 2);
    }

    // ------------------------------------- AC-D4 + U2 (detail lama -> baru)

    public function test_update_alat_mencatat_detail_lama_baru(): void
    {
        $token = $this->token();
        $alat = \App\Models\Alat::firstOrFail();
        $merkBaru = $alat->merk_alat.' Revisi';

        $this->withToken($token)->putJson("/api/v1/alat/{$alat->barcode_alat}", [
            'merk_alat' => $merkBaru,
            'id_kategori' => $alat->id_kategori,
            'id_lokasi' => $alat->id_lokasi,
        ])->assertOk();

        $response = $this->withToken($token)
            ->getJson('/api/v1/audit-log?entitas=alat&aksi=update')
            ->assertOk()
            ->assertJsonPath('data.total', 1);

        $detail = json_decode((string) $response->json('data.data.0.detail'), true);

        $this->assertIsArray($detail);
        $this->assertArrayHasKey('merk_alat', $detail);
        $this->assertArrayHasKey('lama', $detail['merk_alat']);
        $this->assertArrayHasKey('baru', $detail['merk_alat']);
        $this->assertSame($merkBaru, $detail['merk_alat']['baru']);
    }
}
