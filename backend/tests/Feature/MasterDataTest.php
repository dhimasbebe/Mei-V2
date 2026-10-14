<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Lokasi;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Master data (Admin): kategori, lokasi, spesifikasi, alat, ekspor CSV,
 * dan sorotan parameter abnormal.
 */
class MasterDataTest extends TestCase
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

    // ----------------------------------------------------------------------
    // Kategori
    // ----------------------------------------------------------------------

    public function test_admin_membuat_memperbarui_dan_menghapus_kategori(): void
    {
        $token = $this->token();

        $created = $this->withToken($token)
            ->postJson('/api/v1/kategori', [
                'nama' => 'CCTV',
                'deskripsi' => 'Kamera pengawas',
                'maintenance_cycle_days' => 45,
            ])
            ->assertStatus(201)
            ->assertJsonPath('data.nama', 'CCTV')
            ->json('data.id_kategori');

        $this->withToken($token)
            ->putJson("/api/v1/kategori/{$created}", [
                'nama' => 'CCTV',
                'deskripsi' => 'Kamera pengawas revisi',
                'maintenance_cycle_days' => 45,
            ])
            ->assertOk()
            ->assertJsonPath('data.deskripsi', 'Kamera pengawas revisi');

        $this->withToken($token)
            ->deleteJson("/api/v1/kategori/{$created}")
            ->assertOk();

        $this->assertNull(Kategori::find($created));
    }

    public function test_konfigurasi_siklus_kategori(): void
    {
        $token = $this->token();
        $kategori = Kategori::where('nama', 'AC')->firstOrFail();

        $this->withToken($token)
            ->putJson("/api/v1/kategori/{$kategori->id_kategori}/cycle", [
                'maintenance_cycle_days' => 60,
            ])
            ->assertOk()
            ->assertJsonPath('data.maintenance_cycle_days', 60);

        $this->assertSame(60, Kategori::find($kategori->id_kategori)->maintenance_cycle_days);
    }

    public function test_menghapus_kategori_yang_masih_dipakai_ditolak_422(): void
    {
        $token = $this->token();
        $kategori = Kategori::where('nama', 'AC')->firstOrFail();

        $this->withToken($token)
            ->deleteJson("/api/v1/kategori/{$kategori->id_kategori}")
            ->assertStatus(422);
    }

    // ----------------------------------------------------------------------
    // Lokasi
    // ----------------------------------------------------------------------

    public function test_admin_crud_lokasi(): void
    {
        $token = $this->token();

        $id = $this->withToken($token)
            ->postJson('/api/v1/lokasi', [
                'nama_lokasi' => 'Gudang',
                'lantai' => 1,
                'keterangan' => 'Gudang penyimpanan',
            ])
            ->assertStatus(201)
            ->assertJsonPath('data.nama_lokasi', 'Gudang')
            ->json('data.id_lokasi');

        $this->withToken($token)
            ->putJson("/api/v1/lokasi/{$id}", [
                'nama_lokasi' => 'Gudang Utama',
                'lantai' => 1,
                'keterangan' => 'Gudang penyimpanan',
            ])
            ->assertOk()
            ->assertJsonPath('data.nama_lokasi', 'Gudang Utama');

        $this->withToken($token)
            ->deleteJson("/api/v1/lokasi/{$id}")
            ->assertOk();

        $this->assertNull(Lokasi::find($id));
    }

    // ----------------------------------------------------------------------
    // Spesifikasi
    // ----------------------------------------------------------------------

    public function test_admin_crud_dan_reorder_spesifikasi(): void
    {
        $token = $this->token();
        $kategori = Kategori::where('nama', 'AC')->firstOrFail();

        $id = $this->withToken($token)
            ->postJson('/api/v1/spesifikasi', [
                'id_kategori' => $kategori->id_kategori,
                'nama_spesifikasi' => 'Kelembapan',
                'tipe_input' => 'number',
                'satuan' => '%',
                'urutan' => 99,
            ])
            ->assertStatus(201)
            ->json('data.id_spesifikasi');

        $this->withToken($token)
            ->getJson("/api/v1/spesifikasi?id_kategori={$kategori->id_kategori}")
            ->assertOk()
            ->assertJsonPath('code', 200);

        $this->withToken($token)
            ->putJson("/api/v1/spesifikasi/{$id}", [
                'id_kategori' => $kategori->id_kategori,
                'nama_spesifikasi' => 'Kelembapan Relatif',
                'tipe_input' => 'number',
                'satuan' => '%',
                'urutan' => 99,
            ])
            ->assertOk()
            ->assertJsonPath('data.nama_spesifikasi', 'Kelembapan Relatif');

        $ids = \App\Models\Spesifikasi::where('id_kategori', $kategori->id_kategori)
            ->orderBy('urutan')
            ->pluck('id_spesifikasi')
            ->all();

        $items = [];
        foreach (array_reverse($ids) as $index => $specId) {
            $items[] = ['id_spesifikasi' => $specId, 'urutan' => $index + 1];
        }

        $this->withToken($token)
            ->putJson('/api/v1/spesifikasi/reorder', [
                'id_kategori' => $kategori->id_kategori,
                'items' => $items,
            ])
            ->assertOk()
            ->assertJsonPath('data.0.urutan', 1);

        $this->withToken($token)
            ->deleteJson("/api/v1/spesifikasi/{$id}")
            ->assertOk();
    }

    // ----------------------------------------------------------------------
    // Alat
    // ----------------------------------------------------------------------

    public function test_admin_crud_alat_dan_penugasan(): void
    {
        $token = $this->token();
        $kategori = Kategori::where('nama', 'AC')->firstOrFail();
        $lokasi = Lokasi::firstOrFail();

        $this->withToken($token)
            ->postJson('/api/v1/alat', [
                'barcode_alat' => 'TEST-001',
                'merk_alat' => 'Uji Merk',
                'id_kategori' => $kategori->id_kategori,
                'id_lokasi' => $lokasi->id_lokasi,
            ])
            ->assertStatus(201)
            ->assertJsonPath('data.barcode_alat', 'TEST-001');

        $this->withToken($token)
            ->putJson('/api/v1/alat/TEST-001', [
                'merk_alat' => 'Uji Merk Revisi',
                'id_kategori' => $kategori->id_kategori,
                'id_lokasi' => $lokasi->id_lokasi,
            ])
            ->assertOk()
            ->assertJsonPath('data.merk_alat', 'Uji Merk Revisi');

        $supervisor = $this->token('11111');

        $this->withToken($supervisor)
            ->postJson('/api/v1/alat/TEST-001/assign', ['username' => '67891'])
            ->assertOk()
            ->assertJsonPath('data.penanggung_jawab', '67891')
            ->assertJsonPath('data.nama_penanggung_jawab', 'Teknisi B')
            ->assertJsonStructure(['data' => ['barcode_alat', 'penanggung_jawab', 'nama_penanggung_jawab', 'ditugaskan_pada']]);

        $this->withToken($token)
            ->deleteJson('/api/v1/alat/TEST-001')
            ->assertOk();

        $this->assertNull(Alat::find('TEST-001'));
    }

    public function test_daftar_alat_dapat_disaring_overdue_dan_penanggung_jawab(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->getJson('/api/v1/alat?overdue=1')
            ->assertOk()
            ->assertJsonPath('code', 200);

        $this->withToken($token)
            ->getJson('/api/v1/alat?penanggung_jawab=67890')
            ->assertOk()
            ->assertJsonPath('code', 200);
    }

    public function test_teknisi_tidak_boleh_membuat_kategori(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->postJson('/api/v1/kategori', ['nama' => 'Nakal'])
            ->assertStatus(403);
    }

    // ----------------------------------------------------------------------
    // Ekspor & parameter abnormal
    // ----------------------------------------------------------------------

    public function test_ekspor_csv_mengembalikan_berkas_biner(): void
    {
        $token = $this->token();
        $dari = now()->subDays(400)->toDateString();
        $sampai = now()->toDateString();

        $response = $this->withToken($token)
            ->get("/api/v1/dashboard/export?format=csv&dari={$dari}&sampai={$sampai}");

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');

        $body = $response->streamedContent();

        $this->assertStringContainsString('ID,Waktu,Teknisi,Barcode,Kategori,Lokasi,Kondisi,Status Verifikasi', $body);
    }

    public function test_teknisi_tidak_boleh_mengekspor(): void
    {
        $token = $this->token('67890');

        $this->withToken($token)
            ->get('/api/v1/dashboard/export')
            ->assertStatus(403);
    }

    public function test_parameter_abnormal_mengembalikan_daftar(): void
    {
        $token = $this->token('11111');

        $this->withToken($token)
            ->getJson('/api/v1/dashboard/parameter-abnormal?days=400')
            ->assertOk()
            ->assertJsonPath('code', 200);

        $data = $this->withToken($token)
            ->getJson('/api/v1/dashboard/parameter-abnormal?days=400')
            ->json('data');

        $this->assertIsArray($data);

        if ($data !== []) {
            $this->assertArrayHasKey('barcode_alat', $data[0]);
            $this->assertArrayHasKey('nama_spesifikasi', $data[0]);
            $this->assertArrayHasKey('ambang', $data[0]);
        }
    }
}
