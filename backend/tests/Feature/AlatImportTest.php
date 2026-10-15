<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\AuditLog;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

/**
 * Impor massal alat dari CSV (WS M, Fitur Tahap 3) — AC-M1…AC-M5
 * (`docs/PRD-FEATURES-V3.md` §M.3, `docs/DESIGN-FEATURES-V3.md` §C.2.5).
 */
class AlatImportTest extends TestCase
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

    /** CSV valid 2 baris baru + header. */
    private function csvValid(): string
    {
        return "barcode_alat,merk_alat,nama_kategori,nama_lokasi\n".
            "IMP-001,Alat Impor Satu,AC,Lobby Utama\n".
            "IMP-002,Alat Impor Dua,Genset,Basement\n";
    }

    // ---------------------------------------------------------------- AC-M1

    public function test_preview_mengembalikan_hasil_validasi_tanpa_menulis_db(): void
    {
        $sebelum = Alat::count();
        $token = $this->token();

        $response = $this->withToken($token)
            ->post('/api/v1/alat/impor/preview', [
                'file' => UploadedFile::fake()->createWithContent('alat.csv', $this->csvValid()),
            ]);

        $response->assertOk()
            ->assertJsonPath('code', 200)
            ->assertJsonStructure(['data' => ['total', 'jumlah_valid', 'error']]);

        $this->assertSame(2, $response->json('data.total'));
        $this->assertSame(2, $response->json('data.jumlah_valid'));
        $this->assertSame([], $response->json('data.error'));

        // AC-M1: preview TIDAK menulis DB.
        $this->assertSame($sebelum, Alat::count());
        $this->assertFalse(Alat::where('barcode_alat', 'IMP-001')->exists());
    }

    public function test_preview_menerima_teks_csv_tempel_tanpa_berkas(): void
    {
        $token = $this->token();

        $response = $this->withToken($token)
            ->postJson('/api/v1/alat/impor/preview', [
                'csv' => $this->csvValid(),
            ]);

        $response->assertOk();
        $this->assertSame(2, $response->json('data.total'));
        $this->assertSame(2, $response->json('data.jumlah_valid'));
    }

    public function test_preview_melaporkan_error_per_baris(): void
    {
        $token = $this->token();

        // Baris 2: duplikat di DB (AC-001 ada dari seeder).
        // Baris 3: duplikat di dalam berkas (sama dengan baris 4).
        // Baris 5: kategori tak dikenal.
        // Baris 6: lokasi tak dikenal.
        // Baris 7: kolom kosong.
        $csv = "barcode_alat,merk_alat,nama_kategori,nama_lokasi\n".
            "AC-001,AC Duplikat DB,AC,Lobby Utama\n".
            "IMP-DUP,Duplikat Berkas,AC,Lobby Utama\n".
            "IMP-DUP,Duplikat Berkas 2,AC,Lobby Utama\n".
            "IMP-KAT,Kategori Aneh,AC Aneh,Lobby Utama\n".
            "IMP-LOK,Lokasi Aneh,AC,Ruang Mimpi\n".
            "IMP-KOSONG,,AC,Lobby Utama\n";

        $response = $this->withToken($token)
            ->postJson('/api/v1/alat/impor/preview', ['csv' => $csv]);

        $response->assertOk();

        $data = $response->json('data');
        $this->assertSame(6, $data['total']);
        $this->assertSame(1, $data['jumlah_valid']); // baris 3 (kemunculan pertama) valid
        $this->assertCount(5, $data['error']);

        $pesan = implode(' | ', array_column($data['error'], 'pesan'));
        $this->assertStringContainsString('AC-001', $pesan);
        $this->assertStringContainsString('duplikat di dalam berkas', $pesan);
        $this->assertStringContainsString("Kategori 'AC Aneh' tidak dikenal", $pesan);
        $this->assertStringContainsString("Lokasi 'Ruang Mimpi' tidak dikenal", $pesan);
        $this->assertStringContainsString('Kolom wajib kosong: merk_alat', $pesan);

        // Nomor baris fisik dilaporkan.
        $this->assertSame([2, 4, 5, 6, 7], array_column($data['error'], 'baris'));

        $this->assertFalse(Alat::where('barcode_alat', 'like', 'IMP-%')->exists());
    }

    // ---------------------------------------------------------------- AC-M2

    public function test_commit_mengimpor_hanya_baris_valid(): void
    {
        $sebelum = Alat::count();
        $token = $this->token();

        // 1 baris valid + 1 duplikat DB.
        $csv = "barcode_alat,merk_alat,nama_kategori,nama_lokasi\n".
            "IMP-OK1,Impor Valid,AC,Lobby Utama\n".
            "AC-001,Sudah Ada,AC,Lobby Utama\n";

        $response = $this->withToken($token)
            ->postJson('/api/v1/alat/impor/commit', ['csv' => $csv]);

        $response->assertStatus(201)
            ->assertJsonPath('code', 201);

        $this->assertSame(2, $response->json('data.total'));
        $this->assertSame(1, $response->json('data.diimpor'));
        $this->assertSame(1, $response->json('data.gagal'));

        $this->assertSame($sebelum + 1, Alat::count());
        $this->assertTrue(Alat::where('barcode_alat', 'IMP-OK1')->exists());

        // Kategori/lokasi di-resolve ke id.
        $alat = Alat::where('barcode_alat', 'IMP-OK1')->first();
        $this->assertSame('AC', $alat?->nama_kategori);
        $this->assertSame('Lobby Utama', $alat?->nama_lokasi);
    }

    // ---------------------------------------------------------------- AC-M3

    public function test_commit_tanpa_baris_valid_menghasilkan_422(): void
    {
        $sebelum = Alat::count();
        $token = $this->token();

        $csv = "barcode_alat,merk_alat,nama_kategori,nama_lokasi\n".
            "AC-001,Duplikat DB,AC,Lobby Utama\n".
            "AC-002,Duplikat DB Juga,AC,Lobby Utama\n";

        $response = $this->withToken($token)
            ->postJson('/api/v1/alat/impor/commit', ['csv' => $csv]);

        $response->assertStatus(422)
            ->assertJsonPath('code', 422);

        $this->assertSame($sebelum, Alat::count());
    }

    // ---------------------------------------------------------------- AC-M4

    public function test_supervisor_dan_teknisi_ditolak_403(): void
    {
        $csv = ['csv' => $this->csvValid()];

        $this->withToken($this->token('11111'))
            ->postJson('/api/v1/alat/impor/preview', $csv)
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->withToken($this->token('11111'))
            ->postJson('/api/v1/alat/impor/commit', $csv)
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->withToken($this->token('67890'))
            ->postJson('/api/v1/alat/impor/preview', $csv)
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->withToken($this->token('67890'))
            ->postJson('/api/v1/alat/impor/commit', $csv)
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->assertFalse(Alat::where('barcode_alat', 'IMP-001')->exists());
    }

    // ---------------------------------------------------------------- AC-M5

    public function test_impor_tercatat_di_audit_log(): void
    {
        $token = $this->token();

        $this->withToken($token)
            ->postJson('/api/v1/alat/impor/commit', ['csv' => $this->csvValid()])
            ->assertStatus(201);

        $log = AuditLog::where('aksi', 'import')
            ->where('entitas', 'alat')
            ->latest('id_audit')
            ->first();

        $this->assertNotNull($log);
        $this->assertSame('12345', $log->actor_username);

        $detail = json_decode((string) $log->detail, true);
        $this->assertSame(2, $detail['total']);
        $this->assertSame(2, $detail['valid']);
        $this->assertSame(0, $detail['gagal']);
    }

    public function test_impor_gagal_sebagian_tercatat_di_audit_log(): void
    {
        $token = $this->token();

        $csv = "barcode_alat,merk_alat,nama_kategori,nama_lokasi\n".
            "IMP-OK2,Impor Valid,AC,Lobby Utama\n".
            "IMP-BAD,Baris Rusak,AC,Ruang Mimpi\n";

        $this->withToken($token)
            ->postJson('/api/v1/alat/impor/commit', ['csv' => $csv])
            ->assertStatus(201);

        $detail = json_decode(
            (string) AuditLog::where('aksi', 'import')->latest('id_audit')->first()?->detail,
            true
        );

        $this->assertSame(2, $detail['total']);
        $this->assertSame(1, $detail['valid']);
        $this->assertSame(1, $detail['gagal']);
    }
}
