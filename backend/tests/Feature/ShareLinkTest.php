<?php

namespace Tests\Feature;

use App\Models\Maintenance;
use App\Models\ShareLink;
use Database\Seeders\MeiVSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Tautan bagikan laporan (WS O, Fitur Tahap 3) — AC-O1…AC-O5
 * (`docs/PRD-FEATURES-V3.md` §O.3, `docs/DESIGN-FEATURES-V3.md` §C.2.1–C.2.2).
 */
class ShareLinkTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(MeiVSeeder::class);
    }

    private function token(string $username = '11111'): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => 'password',
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    private function maintenance(): Maintenance
    {
        return Maintenance::firstOrFail();
    }

    // ---------------------------------------------------------------- AC-O1

    public function test_buat_share_link_mengembalikan_201_dengan_url_dan_token(): void
    {
        $m = $this->maintenance();
        $token = $this->token();

        $response = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", []);

        $response->assertStatus(201)
            ->assertJsonPath('code', 201)
            ->assertJsonStructure(['data' => ['token', 'url']]);

        $data = $response->json('data');

        // Token >= 32 karakter (PRD O.2) dan URL mengarah ke halaman publik.
        $this->assertGreaterThanOrEqual(32, strlen($data['token']));
        $this->assertStringEndsWith('/share/'.$data['token'], $data['url']);

        $this->assertTrue(ShareLink::where('token', $data['token'])->exists());
        $this->assertSame($m->id_maintenance, (int) $response->json('data.id_maintenance'));
    }

    public function test_dua_permintaan_menghasilkan_dua_token_berbeda(): void
    {
        $m = $this->maintenance();
        $token = $this->token();

        $a = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(201)
            ->json('data.token');

        $b = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(201)
            ->json('data.token');

        $this->assertNotSame($a, $b);
        $this->assertSame(2, ShareLink::where('id_maintenance', $m->id_maintenance)->count());
        $this->assertSame(2, ShareLink::distinct('token')->count('token'));
    }

    public function test_buat_share_link_dengan_expires_at(): void
    {
        $m = $this->maintenance();
        $token = $this->token();

        $response = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [
                'expires_at' => now()->addDays(7)->format('Y-m-d H:i:s'),
            ]);

        $response->assertStatus(201);
        $this->assertNotNull($response->json('data.expires_at'));

        $link = ShareLink::where('token', $response->json('data.token'))->first();
        $this->assertNotNull($link?->expires_at);
    }

    public function test_buat_share_link_ke_laporan_tidak_ada_menghasilkan_404(): void
    {
        $this->withToken($this->token())
            ->postJson('/api/v1/maintenance/999999/share', [])
            ->assertStatus(404)
            ->assertJsonPath('code', 404);
    }

    public function test_buat_share_link_expires_di_masa_lalu_ditolak_422(): void
    {
        $m = $this->maintenance();

        $this->withToken($this->token())
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [
                'expires_at' => now()->subDay()->format('Y-m-d H:i:s'),
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 422);
    }

    // ---------------------------------------------------------------- AC-O2

    public function test_halaman_publik_html_tanpa_auth(): void
    {
        $m = $this->maintenance();
        $link = ShareLink::create([
            'id_maintenance' => $m->id_maintenance,
            'token' => 'token-halaman-publik-0123456789abcdef',
            'created_by' => '11111',
            'created_at' => now(),
        ]);

        // TANPA header Authorization.
        $response = $this->get('/share/'.$link->token);

        $response->assertStatus(200);
        $this->assertStringContainsString('text/html', (string) $response->headers->get('Content-Type'));

        $html = $response->getContent();
        $this->assertStringContainsString('Laporan Pemeliharaan', $html);

        // Bukan envelope JSON — halaman web berdiri sendiri.
        $this->assertStringNotContainsString('"code"', $html);

        // Memuat data laporan ringkas.
        $this->assertStringContainsString((string) $m->barcode_alat, $html);
        $this->assertStringContainsString((string) $m->nama_lokasi, $html);
    }

    public function test_halaman_publik_tidak_memuat_email_atau_nip(): void
    {
        $m = $this->maintenance();
        $link = ShareLink::create([
            'id_maintenance' => $m->id_maintenance,
            'token' => 'token-privasi-0123456789abcdefghij',
            'created_by' => '11111',
            'created_at' => now(),
        ]);

        $html = $this->get('/share/'.$link->token)->getContent();

        $this->assertStringNotContainsString('@meiv.test', $html);
        $this->assertStringNotContainsString('email_users', $html);
        $this->assertStringNotContainsString((string) $m->username, $html);
    }

    // ---------------------------------------------------------------- AC-O3

    public function test_token_tidak_dikenal_menghasilkan_404_tautan_tidak_berlaku(): void
    {
        $response = $this->get('/share/token-tidak-ada-0123456789abcdef1234');

        $response->assertStatus(404);
        $this->assertStringContainsString('text/html', (string) $response->headers->get('Content-Type'));
        $this->assertStringContainsString('Tautan tidak berlaku', $response->getContent());
    }

    public function test_token_yang_dicabut_menghasilkan_404(): void
    {
        $m = $this->maintenance();
        $link = ShareLink::create([
            'id_maintenance' => $m->id_maintenance,
            'token' => 'token-dicabut-0123456789abcdefghijkl',
            'created_by' => '11111',
            'revoked_at' => now(),
            'created_at' => now(),
        ]);

        $response = $this->get('/share/'.$link->token);

        $response->assertStatus(404);
        $this->assertStringContainsString('Tautan tidak berlaku', $response->getContent());
    }

    public function test_token_kedaluwarsa_menghasilkan_404(): void
    {
        $m = $this->maintenance();
        $link = ShareLink::create([
            'id_maintenance' => $m->id_maintenance,
            'token' => 'token-kedaluwarsa-0123456789abcdefgh',
            'created_by' => '11111',
            'expires_at' => now()->subMinute(),
            'created_at' => now(),
        ]);

        $response = $this->get('/share/'.$link->token);

        $response->assertStatus(404);
        $this->assertStringContainsString('Tautan tidak berlaku', $response->getContent());
    }

    public function test_token_yang_belum_kedaluwarsa_tetap_diterima(): void
    {
        $m = $this->maintenance();
        $link = ShareLink::create([
            'id_maintenance' => $m->id_maintenance,
            'token' => 'token-masa-berlaku-0123456789abcdef',
            'created_by' => '11111',
            'expires_at' => now()->addHour(),
            'created_at' => now(),
        ]);

        $this->get('/share/'.$link->token)->assertStatus(200);
    }

    // ---------------------------------------------------------------- AC-O4

    public function test_cabut_share_link_setelahnya_404_dan_baris_dipertahankan(): void
    {
        $m = $this->maintenance();
        $token = $this->token();

        $create = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(201);

        $shareToken = $create->json('data.token');

        // Halaman publik masih hidup sebelum pencabutan.
        $this->get('/share/'.$shareToken)->assertStatus(200);

        // Pencabutan soft → 200.
        $this->withToken($token)
            ->deleteJson('/api/v1/share/'.$shareToken)
            ->assertOk()
            ->assertJsonPath('code', 200);

        // Baris DIPERTAHANKAN (soft revoke) untuk jejak audit.
        $row = ShareLink::where('token', $shareToken)->first();
        $this->assertNotNull($row);
        $this->assertNotNull($row->revoked_at);

        // Setelah dicabut: halaman publik 404 (AC-O3/O4).
        $this->get('/share/'.$shareToken)->assertStatus(404);

        // Idempoten: mencabut dua kali tetap 200.
        $this->withToken($token)
            ->deleteJson('/api/v1/share/'.$shareToken)
            ->assertOk();

        // Token tak dikenal saat pencabutan → 404.
        $this->withToken($token)
            ->deleteJson('/api/v1/share/token-tidak-ada-0123456789abcdef1234')
            ->assertStatus(404);
    }

    // ---------------------------------------------------------------- AC-O5

    public function test_teknisi_ditolak_403_saat_buat_dan_cabut(): void
    {
        $m = $this->maintenance();
        $teknisi = $this->token('67890');

        $this->withToken($teknisi)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->withToken($teknisi)
            ->deleteJson('/api/v1/share/token-apa-pun-0123456789abcdef123456')
            ->assertStatus(403)
            ->assertJsonPath('code', 403);

        $this->assertSame(0, ShareLink::count());
    }

    public function test_supervisor_dan_admin_boleh_membuat_tautan(): void
    {
        $m = $this->maintenance();

        $this->withToken($this->token('11111'))
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(201);

        $this->withToken($this->token('12345'))
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->assertStatus(201);

        $this->assertSame(2, ShareLink::count());
    }

    // ------------------------------------------------------ audit (R12)

    public function test_buat_dan_cabut_tercatat_di_audit_log(): void
    {
        $m = $this->maintenance();
        $token = $this->token();

        $shareToken = $this->withToken($token)
            ->postJson("/api/v1/maintenance/{$m->id_maintenance}/share", [])
            ->json('data.token');

        $this->withToken($token)->deleteJson('/api/v1/share/'.$shareToken)->assertOk();

        $buat = \App\Models\AuditLog::where('aksi', 'create')
            ->where('entitas', 'share_link')
            ->where('entitas_id', $shareToken)
            ->first();
        $this->assertNotNull($buat);
        $this->assertSame($m->id_maintenance, json_decode((string) $buat->detail, true)['id_maintenance']);

        $cabut = \App\Models\AuditLog::where('aksi', 'delete')
            ->where('entitas', 'share_link')
            ->where('entitas_id', $shareToken)
            ->first();
        $this->assertNotNull($cabut);
    }

    // ------------------------------------------------ migrasi aditif

    public function test_migrasi_share_links_aditif(): void
    {
        $this->assertTrue(\Illuminate\Support\Facades\Schema::hasTable('share_links'));
        $this->assertTrue(\Illuminate\Support\Facades\Schema::hasColumns('share_links', [
            'id_share', 'id_maintenance', 'token', 'created_by',
            'expires_at', 'revoked_at', 'created_at',
        ]));

        // Tabel lama tetap utuh.
        $this->assertTrue(\Illuminate\Support\Facades\Schema::hasColumns('maintenance', [
            'id_maintenance', 'waktu_maintenance', 'barcode_alat', 'username',
            'kondisi_keseluruhan', 'client_uuid',
        ]));
    }
}
