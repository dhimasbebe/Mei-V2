<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\Maintenance;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Batas privasi laporan antar-Teknisi (QA tahap 3).
 *
 * Sebelum perbaikan, `GET /maintenance` tanpa parameter `username` dan
 * `GET /maintenance/{id}` sama-sama mengembalikan laporan milik teknisi lain
 * kepada Teknisi mana pun — penyaringan hanya ada di klien. Uji ini mengunci
 * perilaku yang benar di server.
 */
class MaintenancePrivacyTest extends TestCase
{
    use RefreshDatabase;

    private string $tokenA;

    private string $tokenB;

    private int $idMilikB;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);

        // 67890 = Teknisi A, 67891 = Teknisi B (lihat MeiVSeeder).
        $this->tokenA = $this->token('67890');
        $this->tokenB = $this->token('67891');

        // Seeder menempatkan seluruh laporan contoh pada 67890. Tambahkan
        // satu laporan milik 67891 agar isolasi benar-benar teruji.
        $this->idMilikB = $this->buatLaporan('67891', 'seed-privasi-teknisi-b');
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

    private function buatLaporan(string $username, string $uuid): int
    {
        $alat = Alat::query()->firstOrFail();

        $maintenance = Maintenance::create([
            'client_uuid' => $uuid,
            'barcode_alat' => $alat->barcode_alat,
            'username' => $username,
            'id_lokasi' => $alat->id_lokasi,
            'id_kategori' => $alat->id_kategori,
            'waktu_maintenance' => now(),
            'status_verifikasi' => 'menunggu',
        ]);

        return (int) $maintenance->id_maintenance;
    }

    public function test_teknisi_hanya_menerima_laporannya_sendiri_tanpa_filter(): void
    {
        $response = $this->withToken($this->tokenA)
            ->getJson('/api/v1/maintenance?per_page=100');

        $response->assertOk()->assertJsonPath('code', 200);

        $usernames = array_column($response->json('data.data'), 'username');
        $this->assertNotEmpty($usernames, 'Daftar laporan tidak boleh kosong.');
        $this->assertSame(
            ['67890'],
            array_values(array_unique($usernames)),
            'Teknisi A tidak boleh menerima laporan milik teknisi lain.'
        );
    }

    public function test_teknisi_tidak_bisa_meminta_laporan_teknisi_lain_lewat_parameter(): void
    {
        $response = $this->withToken($this->tokenA)
            ->getJson('/api/v1/maintenance?username=67891&per_page=100');

        $response->assertOk();

        // Parameter diabaikan, bukan digabung: hasilnya tetap hanya milik A,
        // sehingga tidak ada baris 67891 yang bocor.
        $usernames = array_column($response->json('data.data'), 'username');
        $this->assertSame(['67890'], array_values(array_unique($usernames)));
    }

    public function test_teknisi_ditolak_membuka_laporan_teknisi_lain(): void
    {
        $this->withToken($this->tokenA)
            ->getJson('/api/v1/maintenance/'.$this->idMilikB)
            ->assertStatus(403)
            ->assertJsonPath('code', 403)
            ->assertJsonPath('data', null);
    }

    public function test_teknisi_boleh_membuka_laporannya_sendiri(): void
    {
        $idSendiri = $this->buatLaporan('67890', 'seed-privasi-teknisi-a');

        $this->withToken($this->tokenA)
            ->getJson('/api/v1/maintenance/'.$idSendiri)
            ->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonPath('data.username', '67890');
    }

    public function test_teknisi_b_dapat_membuka_laporannya_sendiri(): void
    {
        $this->withToken($this->tokenB)
            ->getJson('/api/v1/maintenance/'.$this->idMilikB)
            ->assertOk()
            ->assertJsonPath('data.username', '67891');
    }

    public function test_supervisor_tetap_melihat_semua_laporan(): void
    {
        $token = $this->token('11111');

        $response = $this->withToken($token)
            ->getJson('/api/v1/maintenance?per_page=100');

        $response->assertOk();

        $usernames = array_values(array_unique(
            array_column($response->json('data.data'), 'username')
        ));

        $this->assertContains('67890', $usernames);
        $this->assertContains('67891', $usernames, 'Supervisor harus melihat lintas teknisi.');
    }

    public function test_supervisor_boleh_membuka_laporan_teknisi(): void
    {
        $this->withToken($this->token('11111'))
            ->getJson('/api/v1/maintenance/'.$this->idMilikB)
            ->assertOk()
            ->assertJsonPath('data.username', '67891');
    }

    public function test_admin_boleh_membuka_laporan_teknisi(): void
    {
        $this->withToken($this->token('12345'))
            ->getJson('/api/v1/maintenance/'.$this->idMilikB)
            ->assertOk()
            ->assertJsonPath('data.username', '67891');
    }
}
