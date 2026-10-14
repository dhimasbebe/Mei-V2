<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Maintenance;
use App\Models\Spesifikasi;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Uji asap API Mei-V2 — memverifikasi kontrak yang dipakai klien Flutter
 * (envelope { code, data, message }, penamaan kunci snake_case, paginasi).
 */
class ApiSmokeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function login(string $username = '12345'): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk()->assertJsonPath('code', 200);

        return (string) $response->json('data.token');
    }

    // ----------------------------------------------------------------------
    // Auth
    // ----------------------------------------------------------------------

    public function test_login_mengembalikan_token_dan_profil(): void
    {
        $token = $this->login();

        $this->assertNotEmpty($token);

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.username', '12345')
            ->assertJsonPath('data.role_users', 'Admin');
    }

    public function test_login_gagal_dengan_password_salah(): void
    {
        $this->postJson('/api/v1/auth/login', [
            'username' => '12345',
            'password' => 'salah',
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 422)
            ->assertJsonStructure(['code', 'data', 'message', 'errors']);
    }

    public function test_endpoint_terlindungi_menolak_tanpa_token(): void
    {
        $this->getJson('/api/v1/kategori')
            ->assertStatus(401)
            ->assertJsonPath('code', 401)
            ->assertJsonPath('data', null);
    }

    // ----------------------------------------------------------------------
    // Master data
    // ----------------------------------------------------------------------

    public function test_daftar_kategori_memuat_jumlah_alat(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/kategori')
            ->assertOk()
            ->assertJsonCount(7, 'data')
            ->assertJsonStructure(['data' => [[
                'id_kategori',
                'nama',
                'deskripsi',
                'maintenance_cycle_days',
                'icon_asset',
                'jumlah_alat',
            ]]]);
    }

    public function test_checklist_spesifikasi_per_kategori(): void
    {
        $token = $this->login();
        $kategori = Kategori::where('nama', 'Genset')->firstOrFail();

        $this->withToken($token)
            ->getJson("/api/v1/kategori/{$kategori->id_kategori}/spesifikasi")
            ->assertOk()
            ->assertJsonCount(7, 'data')
            ->assertJsonStructure(['data' => [[
                'id_spesifikasi',
                'id_kategori',
                'nama_spesifikasi',
                'tipe_input',
                'satuan',
                'opsi',
                'urutan',
            ]]]);
    }

    public function test_detail_alat_memuat_kolom_datar(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/alat/AC-001')
            ->assertOk()
            ->assertJsonPath('data.barcode_alat', 'AC-001')
            ->assertJsonPath('data.nama_kategori', 'AC')
            ->assertJsonPath('data.nama_lokasi', 'Aula Besar')
            ->assertJsonPath('data.lantai', 7)
            ->assertJsonPath('data.maintenance_cycle_days', 30)
            ->assertJsonStructure(['data' => ['terakhir_maintenance']]);
    }

    public function test_daftar_lokasi_memuat_jumlah_alat(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/lokasi')
            ->assertOk()
            ->assertJsonStructure(['data' => [['id_lokasi', 'nama_lokasi', 'lantai', 'jumlah_alat']]]);
    }

    /**
     * Pencarian harus menjangkau NAMA KATEGORI dan NAMA LOKASI, bukan hanya
     * barcode/merk — teknisi di lapangan mengetik "genset" atau "basement",
     * bukan "GS-001". Harus case-insensitive juga, karena LIKE bersifat
     * case-sensitive di PostgreSQL (berbeda dari SQLite/MySQL).
     */
    public function test_pencarian_alat_menjangkau_kategori_dan_lokasi(): void
    {
        $token = $this->login();

        $kasus = [
            'genset' => 4,        // nama kategori
            'GENSET' => 4,        // huruf besar
            'GenSet' => 4,        // campuran
            'hydrant' => 3,       // nama kategori
            'basement' => 5,      // nama lokasi
            'aula' => 3,          // nama lokasi
            'ruang server' => 3,  // nama lokasi dua kata
            'GS-001' => 1,        // barcode
            'caterpillar' => 1,   // merk
            'zzz-tidak-ada' => 0, // tidak ketemu
        ];

        foreach ($kasus as $term => $expected) {
            $response = $this->withToken($token)->getJson('/api/v1/alat?q='.urlencode($term));

            $response->assertOk();
            $this->assertCount(
                $expected,
                $response->json('data'),
                "Pencarian '{$term}' seharusnya mengembalikan {$expected} alat."
            );
        }
    }

    /**
     * Regresi bug sistem lama: AC & Hydrant sama-sama memakai id_spesifikasi
     * 1,2 dan Fire Alarm & APAR sama-sama 23,24,25 — checklist saling
     * menimpa. Di v2 setiap id_spesifikasi wajib unik global dan setiap
     * kategori wajib punya checklist sendiri yang tidak kosong.
     */
    public function test_id_spesifikasi_unik_global_dan_tiap_kategori_punya_checklist(): void
    {
        $ids = Spesifikasi::pluck('id_spesifikasi');

        $this->assertSame(
            $ids->count(),
            $ids->unique()->count(),
            'Ada id_spesifikasi duplikat antar kategori (bug ID collision versi lama).'
        );

        $this->assertSame(45, $ids->count(), 'Total item checklist seharusnya 45.');

        foreach (Kategori::all() as $kategori) {
            $this->assertGreaterThan(
                0,
                $kategori->spesifikasi()->count(),
                "Kategori {$kategori->nama} tidak punya checklist — formnya akan kosong."
            );
        }
    }

    // ----------------------------------------------------------------------
    // Maintenance
    // ----------------------------------------------------------------------

    public function test_kirim_maintenance_idempoten(): void
    {
        $token = $this->login();
        $alat = Alat::with('kategori.spesifikasi')->findOrFail('AC-001');
        $spec = $alat->kategori->spesifikasi->firstOrFail();

        $payload = [
            'client_uuid' => 'uji-idempotensi-0001',
            'barcode_alat' => 'AC-001',
            'id_lokasi' => $alat->id_lokasi,
            'waktu_maintenance' => now()->toIso8601String(),
            'catatan' => 'Uji kirim ganda',
            'kondisi_keseluruhan' => 'baik',
            'detail' => [
                ['id_spesifikasi' => $spec->id_spesifikasi, 'status' => '220'],
            ],
        ];

        $this->withToken($token)
            ->postJson('/api/v1/maintenance', $payload)
            ->assertStatus(201)
            ->assertJsonPath('code', 201);

        // Kirim ulang dengan client_uuid sama -> 200, TIDAK menambah baris.
        $this->withToken($token)
            ->postJson('/api/v1/maintenance', $payload)
            ->assertOk()
            ->assertJsonPath('code', 200);

        $this->assertSame(
            1,
            Maintenance::where('client_uuid', 'uji-idempotensi-0001')->count(),
        );
    }

    public function test_riwayat_maintenance_terpaginasi_dan_berisi_kolom_join(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/maintenance?per_page=5')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'data',
                'current_page',
                'last_page',
                'per_page',
                'total',
            ]])
            ->assertJsonStructure(['data' => ['data' => [[
                'id_maintenance',
                'waktu_maintenance',
                'barcode_alat',
                'username',
                'nama_kategori',
                'merk_alat',
                'nama_users',
                'nama_lokasi',
                'detail',
            ]]]]);
    }

    public function test_detail_maintenance_memuat_nama_spesifikasi(): void
    {
        $token = $this->login();
        $maintenance = Maintenance::has('detail')->firstOrFail();

        $this->withToken($token)
            ->getJson("/api/v1/maintenance/{$maintenance->id_maintenance}")
            ->assertOk()
            ->assertJsonStructure(['data' => ['detail' => [[
                'id_spesifikasi',
                'status',
                'nama_spesifikasi',
                'satuan',
            ]]]]);
    }

    // ----------------------------------------------------------------------
    // Dashboard
    // ----------------------------------------------------------------------

    public function test_dashboard_kpi(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/dashboard/kpi')
            ->assertOk()
            ->assertJsonPath('data.total_alat', 21)
            ->assertJsonPath('data.total_kategori', 7)
            ->assertJsonStructure(['data' => [
                'total_alat',
                'total_kategori',
                'pemeliharaan_bulan_ini',
                'pemeliharaan_tepat_waktu',
                'alat_overdue',
                'teknisi_aktif',
                'persen_tepat_waktu',
                'rata_rata_interval_hari',
            ]]);
    }

    public function test_dashboard_tren_mengisi_semua_hari(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/dashboard/trends?days=7')
            ->assertOk()
            ->assertJsonCount(7, 'data')
            ->assertJsonStructure(['data' => [['label', 'jumlah']]]);
    }

    public function test_dashboard_distribusi_dan_overdue(): void
    {
        $token = $this->login();

        $this->withToken($token)
            ->getJson('/api/v1/dashboard/distribution')
            ->assertOk()
            ->assertJsonCount(7, 'data')
            ->assertJsonStructure(['data' => [['label', 'jumlah', 'icon_asset']]]);

        $this->withToken($token)
            ->getJson('/api/v1/dashboard/overdue?limit=5')
            ->assertOk()
            ->assertJsonStructure(['data' => [['barcode_alat', 'merk_alat', 'nama_kategori', 'nama_lokasi', 'terlambat_hari']]]);
    }
}
