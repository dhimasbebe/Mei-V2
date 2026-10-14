<?php

namespace Tests\Feature;

use App\Models\Maintenance;
use App\Models\MaintenanceFoto;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Foto lampiran pemeliharaan — AC-C1…AC-C7
 * (`docs/DESIGN-FEATURES-V3.md` §10.2–10.3).
 */
class FotoTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
        Storage::fake('public');
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

    /** Sesi milik teknisi 67890 (pemilik default seeder). */
    private function maintenanceMilikTeknisi(): Maintenance
    {
        return Maintenance::where('username', '67890')->firstOrFail();
    }

    private function maintenanceMilikOrangLain(): Maintenance
    {
        $alat = \App\Models\Alat::firstOrFail();

        return Maintenance::create([
            'client_uuid' => 'test-foto-lain-'.uniqid(),
            'barcode_alat' => $alat->barcode_alat,
            'username' => '67891',
            'id_lokasi' => $alat->id_lokasi,
            'id_kategori' => $alat->id_kategori,
            'waktu_maintenance' => now(),
            'kondisi_keseluruhan' => 'baik',
            'status_verifikasi' => 'menunggu',
        ]);
    }

    // ---------------------------------------------------------------- AC-C1

    public function test_unggah_foto_mengembalikan_201_dengan_bentuk_benar(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        $response = $this->withToken($token)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                'foto' => UploadedFile::fake()->image('foto.jpg', 320, 240),
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('code', 201)
            ->assertJsonStructure(['data' => ['id_foto', 'url', 'mime', 'ukuran']]);

        $this->assertSame('image/jpeg', $response->json('data.mime'));
        $this->assertGreaterThan(0, (int) $response->json('data.ukuran'));
        $this->assertStringContainsString('/storage/', (string) $response->json('data.url'));

        $foto = MaintenanceFoto::findOrFail($response->json('data.id_foto'));
        Storage::disk('public')->assertExists($foto->path);
    }

    // ---------------------------------------------------------------- AC-C2

    public function test_unggah_ke_id_tidak_ada_menghasilkan_404(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->post('/api/v1/maintenance/999999/foto', [
                'foto' => UploadedFile::fake()->image('foto.jpg', 100, 100),
            ])
            ->assertStatus(404)
            ->assertJsonPath('code', 404);
    }

    public function test_unggah_ke_laporan_milik_teknisi_lain_menghasilkan_403(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikOrangLain();

        $this->withToken($token)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                'foto' => UploadedFile::fake()->image('foto.jpg', 100, 100),
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 403);
    }

    // ---------------------------------------------------------------- AC-C3

    public function test_unggah_lebih_dari_5mb_menghasilkan_422(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        $this->withToken($token)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                // 6000 KB > 5120 KB (5 MB)
                'foto' => UploadedFile::fake()->image('besar.jpg', 800, 800)->size(6000),
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    // ---------------------------------------------------------------- AC-C4

    public function test_unggah_foto_keenam_menghasilkan_422_maksimum_5_foto(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        for ($i = 0; $i < 5; $i++) {
            MaintenanceFoto::create([
                'id_maintenance' => $m->id_maintenance,
                'path' => "foto/seed-$i.jpg",
                'mime' => 'image/jpeg',
                'ukuran' => 1024,
                'username' => '67890',
                'created_at' => now(),
            ]);
        }

        $this->withToken($token)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                'foto' => UploadedFile::fake()->image('keenam.jpg', 100, 100),
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 422);

        $this->assertSame(5, MaintenanceFoto::where('id_maintenance', $m->id_maintenance)->count());
    }

    // ---------------------------------------------------------------- AC-C5

    public function test_daftar_foto_dan_detail_menyertakan_array_foto(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        $this->withToken($token)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                'foto' => UploadedFile::fake()->image('foto.jpg', 100, 100),
            ])
            ->assertStatus(201);

        // GET /maintenance/{id}/foto
        $this->withToken($token)
            ->getJson("/api/v1/maintenance/{$m->id_maintenance}/foto")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonStructure(['data' => [['id_foto', 'url', 'mime', 'ukuran']]]);

        // GET /maintenance/{id} menyertakan `foto`
        $this->withToken($token)
            ->getJson("/api/v1/maintenance/{$m->id_maintenance}")
            ->assertOk()
            ->assertJsonStructure(['data' => ['foto' => [['id_foto', 'url', 'mime', 'ukuran']]]])
            ->assertJsonCount(1, 'data.foto');
    }

    public function test_detail_tanpa_foto_mengembalikan_array_kosong(): void
    {
        $token = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        $this->withToken($token)
            ->getJson("/api/v1/maintenance/{$m->id_maintenance}")
            ->assertOk()
            ->assertJsonPath('data.foto', []);
    }

    // ---------------------------------------------------------------- AC-C6

    public function test_hapus_foto_oleh_supervisor_menghapus_baris_dan_berkas(): void
    {
        // Foto dibuat langsung (bukan lewat HTTP) agar test ini memakai SATU
        // token saja — guard Sanctum menyimpan pengguna terautentikasi per
        // request dalam satu test, sehingga berganti token di tengah test
        // tidak dapat diandalkan.
        $m = $this->maintenanceMilikTeknisi();
        $path = 'foto/hapus-'.uniqid().'.jpg';
        Storage::disk('public')->put($path, 'isi-foto');

        $foto = MaintenanceFoto::create([
            'id_maintenance' => $m->id_maintenance,
            'path' => $path,
            'mime' => 'image/jpeg',
            'ukuran' => 8,
            'username' => '67890',
            'created_at' => now(),
        ]);

        $supervisor = $this->token('11111');

        $this->withToken($supervisor)
            ->deleteJson('/api/v1/maintenance/foto/'.$foto->id_foto)
            ->assertOk()
            ->assertJsonPath('code', 200);

        $this->assertNull(MaintenanceFoto::find($foto->id_foto));
        Storage::disk('public')->assertMissing($path);
    }

    public function test_hapus_foto_oleh_teknisi_menghasilkan_403(): void
    {
        $teknisi = $this->token('67890');
        $m = $this->maintenanceMilikTeknisi();

        $create = $this->withToken($teknisi)
            ->post("/api/v1/maintenance/{$m->id_maintenance}/foto", [
                'foto' => UploadedFile::fake()->image('x.jpg', 100, 100),
            ])
            ->assertStatus(201);

        $this->withToken($teknisi)
            ->deleteJson('/api/v1/maintenance/foto/'.$create->json('data.id_foto'))
            ->assertStatus(403);
    }

    // ---------------------------------------------------------------- AC-C7

    public function test_migrasi_aditif_tidak_mengubah_tabel_lama(): void
    {
        $this->assertTrue(Schema::hasTable('maintenance_foto'));

        $this->assertTrue(Schema::hasColumns('maintenance_foto', [
            'id_foto', 'id_maintenance', 'path', 'mime', 'ukuran', 'username', 'created_at',
        ]));

        // Tabel lama tetap memiliki seluruh kolomnya.
        $this->assertTrue(Schema::hasColumns('maintenance', [
            'id_maintenance', 'waktu_maintenance', 'barcode_alat', 'username',
            'id_lokasi', 'id_kategori', 'catatan', 'kondisi_keseluruhan',
            'client_uuid', 'status_verifikasi', 'diverifikasi_oleh',
            'waktu_verifikasi', 'komentar_verifikasi',
        ]));
    }
}
