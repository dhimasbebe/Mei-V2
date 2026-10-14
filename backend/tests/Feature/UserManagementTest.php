<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Manajemen pengguna (Admin): CRUD, reset password, guard hapus-diri.
 */
class UserManagementTest extends TestCase
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

    public function test_daftar_pengguna_terpaginasi_dengan_jumlah_maintenance(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->getJson('/api/v1/users?per_page=10')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'data' => [['username', 'nama_users', 'role_users', 'email_users', 'jumlah_maintenance']],
                'current_page',
                'last_page',
                'per_page',
                'total',
            ]]);
    }

    public function test_daftar_pengguna_dapat_disaring_role_dan_pencarian(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->getJson('/api/v1/users?role=Teknisi')
            ->assertOk()
            ->assertJsonPath('data.total', 3);

        $this->withToken($token)
            ->getJson('/api/v1/users?q=Teknisi+B')
            ->assertOk()
            ->assertJsonPath('data.total', 1);
    }

    public function test_admin_membuat_pengguna_dan_password_di_hash(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->postJson('/api/v1/users', [
                'username' => '67893',
                'nama_users' => 'Teknisi D',
                'role_users' => 'Teknisi',
                'email_users' => 'teknisi.d@meiv.test',
                'password' => 'rahasia123',
            ])
            ->assertStatus(201)
            ->assertJsonPath('code', 201)
            ->assertJsonPath('data.username', '67893');

        $user = User::findOrFail('67893');

        $this->assertTrue(Hash::check('rahasia123', $user->password));
        $this->assertNotSame('rahasia123', $user->password);
    }

    public function test_membuat_pengguna_username_duplikat_ditolak_422(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->postJson('/api/v1/users', [
                'username' => '67890',
                'nama_users' => 'Duplikat',
                'role_users' => 'Teknisi',
                'password' => 'rahasia123',
            ])
            ->assertStatus(422)
            ->assertJsonStructure(['code', 'data', 'message', 'errors']);
    }

    public function test_admin_memperbarui_pengguna(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->putJson('/api/v1/users/67890', [
                'nama_users' => 'Teknisi A Revisi',
                'role_users' => 'Supervisor',
                'email_users' => 'teknisi.a@meiv.test',
            ])
            ->assertOk()
            ->assertJsonPath('data.nama_users', 'Teknisi A Revisi')
            ->assertJsonPath('data.role_users', 'Supervisor');

        $this->assertSame('Supervisor', User::find('67890')->role_users);
    }

    public function test_admin_menghapus_pengguna(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->deleteJson('/api/v1/users/67892')
            ->assertOk()
            ->assertJsonPath('data', null);

        $this->assertNull(User::find('67892'));
    }

    public function test_admin_tidak_dapat_menghapus_akun_sendiri(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->deleteJson('/api/v1/users/12345')
            ->assertStatus(422)
            ->assertJsonPath('code', 422);

        $this->assertNotNull(User::find('12345'));
    }

    public function test_admin_mereset_password_dan_pengguna_bisa_login(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->postJson('/api/v1/users/67890/reset-password', ['password' => 'baru1234'])
            ->assertOk()
            ->assertJsonPath('data.username', '67890');

        $this->postJson('/api/v1/auth/login', [
            'username' => '67890',
            'password' => 'baru1234',
        ])->assertOk();
    }

    public function test_reset_password_tanpa_password_mengembalikan_password_acak(): void
    {
        $token = $this->token();

        $response = $this->withToken($token)
            ->postJson('/api/v1/users/67891/reset-password', [])
            ->assertOk()
            ->assertJsonStructure(['data' => ['username', 'password']]);

        $generated = (string) $response->json('data.password');

        $this->assertNotEmpty($generated);

        $this->postJson('/api/v1/auth/login', [
            'username' => '67891',
            'password' => $generated,
        ])->assertOk();
    }

    public function test_teknisi_tidak_boleh_membuat_pengguna(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->postJson('/api/v1/users', [
                'username' => '67999',
                'nama_users' => 'Nakal',
                'role_users' => 'Admin',
                'password' => 'rahasia123',
            ])
            ->assertStatus(403);
    }
}
