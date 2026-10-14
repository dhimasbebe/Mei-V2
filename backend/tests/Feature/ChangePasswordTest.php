<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Ganti password sendiri (semua peran) — POST /auth/change-password.
 */
class ChangePasswordTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function token(string $username = '67890'): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    public function test_ganti_password_berhasil_dan_password_lama_gagal(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', [
                'password_lama' => 'password',
                'password_baru' => 'baru1234',
            ])
            ->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonPath('data', null);

        $this->assertTrue(Hash::check('baru1234', User::find('67890')->password));

        // Password lama tidak berlaku lagi.
        $this->postJson('/api/v1/auth/login', [
            'username' => '67890',
            'password' => 'password',
        ])->assertStatus(422);

        // Password baru berlaku.
        $this->postJson('/api/v1/auth/login', [
            'username' => '67890',
            'password' => 'baru1234',
        ])->assertOk();
    }

    public function test_password_lama_salah_ditolak_422(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', [
                'password_lama' => 'salah',
                'password_baru' => 'baru1234',
            ])
            ->assertStatus(422)
            ->assertJsonStructure(['code', 'data', 'message', 'errors']);
    }

    public function test_password_baru_terlalu_pendek_ditolak_422(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', [
                'password_lama' => 'password',
                'password_baru' => '12',
            ])
            ->assertStatus(422);
    }

    public function test_tanpa_token_ditolak_401(): void
    {
        $this->postJson('/api/v1/auth/change-password', [
            'password_lama' => 'password',
            'password_baru' => 'baru1234',
        ])->assertStatus(401);
    }
}
