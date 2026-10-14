<?php

namespace Database\Seeders;

use App\Models\Alat;
use App\Models\Kategori;
use App\Models\Lokasi;
use App\Models\Maintenance;
use App\Models\Spesifikasi;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;

/**
 * Data contoh Mei-V2.
 *
 * Seeder ini IDEMPOTEN (memakai updateOrCreate / client_uuid tetap), sehingga
 * `php artisan db:seed` boleh dijalankan berulang tanpa menggandakan data.
 *
 * Cakupan:
 *  - 3 akun (Admin / Teknisi / Supervisor), password: "password"
 *  - 7 kategori  (sama dengan 7 menu pada aplikasi lama)
 *  - checklist spesifikasi LENGKAP untuk ketujuh kategori -> membuktikan
 *    model checklist generik (satu form dinamis, bukan 6 form hardcode)
 *  - 21 alat di 8 lokasi
 *  - riwayat pemeliharaan 90 hari terakhir (sebagian tepat waktu, sebagian
 *    melewati siklus) supaya grafik & KPI dashboard langsung berisi data
 */
class MeiVSeeder extends Seeder
{
    public function run(): void
    {
        $this->seedUsers();
        $this->seedLokasi();
        $this->seedKategori();
        $this->seedSpesifikasi();
        $this->seedAlat();
        $this->seedMaintenance();
    }

    // ----------------------------------------------------------------------

    private function seedUsers(): void
    {
        $users = [
            ['username' => '12345', 'nama_users' => 'Admin Mei-V', 'role_users' => 'Admin', 'email_users' => 'admin@meiv.test'],
            ['username' => '67890', 'nama_users' => 'Teknisi A', 'role_users' => 'Teknisi', 'email_users' => 'teknisi.a@meiv.test'],
            ['username' => '67891', 'nama_users' => 'Teknisi B', 'role_users' => 'Teknisi', 'email_users' => 'teknisi.b@meiv.test'],
            ['username' => '67892', 'nama_users' => 'Teknisi C', 'role_users' => 'Teknisi', 'email_users' => 'teknisi.c@meiv.test'],
            ['username' => '11111', 'nama_users' => 'Supervisor Utama', 'role_users' => 'Supervisor', 'email_users' => 'supervisor@meiv.test'],
        ];

        foreach ($users as $u) {
            User::updateOrCreate(
                ['username' => $u['username']],
                $u + ['password' => Hash::make('password')],
            );
        }
    }

    private function seedLokasi(): void
    {
        $lokasi = [
            ['nama_lokasi' => 'Lobby Utama', 'lantai' => 1, 'keterangan' => 'Area penerima tamu'],
            ['nama_lokasi' => 'Ruang Server', 'lantai' => 2, 'keterangan' => 'Data center lantai 2'],
            ['nama_lokasi' => 'Ruang Rapat Direksi', 'lantai' => 3, 'keterangan' => 'Meeting room eksekutif'],
            ['nama_lokasi' => 'Ruang Meeting', 'lantai' => 5, 'keterangan' => 'Meeting room umum'],
            ['nama_lokasi' => 'Aula Besar', 'lantai' => 7, 'keterangan' => 'Aula serbaguna'],
            ['nama_lokasi' => 'Ruang ME', 'lantai' => 7, 'keterangan' => 'Ruang mechanical & electrical'],
            ['nama_lokasi' => 'Rooftop', 'lantai' => 9, 'keterangan' => 'Area atap — penangkal petir'],
            ['nama_lokasi' => 'Basement', 'lantai' => -1, 'keterangan' => 'Area parkir & genset'],
        ];

        foreach ($lokasi as $l) {
            Lokasi::updateOrCreate(['nama_lokasi' => $l['nama_lokasi']], $l);
        }
    }

    private function seedKategori(): void
    {
        $kategori = [
            ['nama' => 'AC', 'deskripsi' => 'Air Conditioner', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/ac.png'],
            ['nama' => 'Penangkal Petir', 'deskripsi' => 'Lightning Protection System', 'maintenance_cycle_days' => 90, 'icon_asset' => 'assets/images/penangkal_petir.png'],
            ['nama' => 'Panel Listrik', 'deskripsi' => 'Electrical Panel', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/panel_listrik.png'],
            ['nama' => 'APAR', 'deskripsi' => 'Alat Pemadam Api Ringan', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/apar.png'],
            ['nama' => 'Fire Alarm', 'deskripsi' => 'Smoke Detector & Alarm', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/fire_alarm.png'],
            ['nama' => 'Hydrant', 'deskripsi' => 'Fire Hydrant System', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/hydrant.png'],
            ['nama' => 'Genset', 'deskripsi' => 'Generator Set', 'maintenance_cycle_days' => 30, 'icon_asset' => 'assets/images/genset.png'],
        ];

        foreach ($kategori as $k) {
            Kategori::updateOrCreate(['nama' => $k['nama']], $k);
        }
    }

    /**
     * Checklist per kategori — sumber form dinamis di aplikasi.
     * Nilai `opsi` dipisah tanda `|` (dibaca klien sebagai dropdown).
     */
    private function seedSpesifikasi(): void
    {
        $checklist = [
            'AC' => [
                ['Voltage R-S', 'number', 'V'],
                ['Voltage S-T', 'number', 'V'],
                ['Voltage T-R', 'number', 'V'],
                ['Ampere R', 'number', 'A'],
                ['Ampere S', 'number', 'A'],
                ['Ampere T', 'number', 'A'],
                ['Freon Pressure', 'number', 'PSI'],
                ['Bersih/Tidak', 'select', null, 'Bersih|Tidak'],
            ],
            'Penangkal Petir' => [
                ['Tahanan Ground', 'number', 'Ohm'],
                ['Tinggi Tiang', 'number', 'm'],
                ['Kondisi Air Terminal', 'select', null, 'Baik|Tidak Baik'],
                ['Kondisi Kabel Konduktor', 'select', null, 'Baik|Tidak Baik'],
                ['Sambungan Kabel', 'select', null, 'Kencang|Kendor'],
            ],
            'Panel Listrik' => [
                ['Tegangan R-N', 'number', 'V'],
                ['Tegangan S-N', 'number', 'V'],
                ['Tegangan T-N', 'number', 'V'],
                ['Arus R', 'number', 'A'],
                ['Arus S', 'number', 'A'],
                ['Arus T', 'number', 'A'],
                ['Suhu Panel', 'number', '°C'],
                ['Kondisi MCB', 'select', null, 'Baik|Tidak Baik'],
                ['Kebersihan Panel', 'select', null, 'Bersih|Kotor'],
            ],
            'APAR' => [
                ['Tekanan Tabung', 'number', 'Bar'],
                ['Berat Tabung', 'number', 'Kg'],
                ['Jenis Media', 'select', null, 'Powder|CO2|Foam'],
                ['Kondisi Segel', 'select', null, 'Baik|Rusak'],
                ['Kondisi Selang', 'select', null, 'Baik|Rusak'],
                ['Kondisi Tuas', 'select', null, 'Baik|Rusak'],
            ],
            'Fire Alarm' => [
                ['Tegangan Baterai', 'number', 'V'],
                ['Kondisi Detector', 'select', null, 'Normal|Tidak Normal'],
                ['Kondisi Baterai Backup', 'select', null, 'Baik|Lemah'],
                ['Uji Alarm', 'select', null, 'Berbunyi|Tidak Berbunyi'],
                ['Kondisi Kabel', 'select', null, 'Baik|Tidak Baik'],
            ],
            'Hydrant' => [
                ['Tekanan Air', 'number', 'Bar'],
                ['Kondisi Selang', 'select', null, 'Baik|Rusak'],
                ['Kondisi Nozzle', 'select', null, 'Baik|Rusak'],
                ['Kondisi Valve', 'select', null, 'Baik|Tidak Baik'],
                ['Level Air Reservoir', 'select', null, 'Full|Setengah|Kosong'],
            ],
            'Genset' => [
                ['Tegangan Output', 'number', 'V'],
                ['Frekuensi', 'number', 'Hz'],
                ['Jam Operasi', 'number', 'Jam'],
                ['Level BBM', 'select', null, 'Full|Setengah|Kosong'],
                ['Level Oli', 'select', null, 'Full|Setengah|Kosong'],
                ['Level Air Radiator', 'select', null, 'Full|Setengah|Kosong'],
                ['Kondisi Aki', 'select', null, 'Normal|Lemah'],
            ],
        ];

        foreach ($checklist as $namaKategori => $items) {
            $kategori = Kategori::where('nama', $namaKategori)->first();

            if ($kategori === null) {
                continue;
            }

            foreach ($items as $index => $item) {
                Spesifikasi::updateOrCreate(
                    [
                        'id_kategori' => $kategori->id_kategori,
                        'nama_spesifikasi' => $item[0],
                    ],
                    [
                        'tipe_input' => $item[1],
                        'satuan' => $item[2] ?? null,
                        'opsi' => $item[3] ?? null,
                        'urutan' => $index + 1,
                    ],
                );
            }
        }
    }

    private function seedAlat(): void
    {
        $alat = [
            // AC
            ['AC-001', 'Daikin 2PK', 'AC', 'Aula Besar'],
            ['AC-002', 'Panasonic 1.5PK', 'AC', 'Ruang Server'],
            ['AC-003', 'LG Dual Inverter 2PK', 'AC', 'Ruang Rapat Direksi'],
            // Penangkal Petir
            ['PP-001', 'Kingsmill Air Terminal', 'Penangkal Petir', 'Rooftop'],
            ['PP-002', 'Grounding Rod Copper', 'Penangkal Petir', 'Basement'],
            // Panel Listrik
            ['PL-001', 'Schneider Acti9', 'Panel Listrik', 'Ruang ME'],
            ['PL-002', 'ABB Sace Tmax', 'Panel Listrik', 'Ruang Server'],
            ['PL-003', 'Hager Volta', 'Panel Listrik', 'Basement'],
            // APAR
            ['AP-001', 'Yamato Powder 6Kg', 'APAR', 'Lobby Utama'],
            ['AP-002', 'Servvo CO2 5Kg', 'APAR', 'Ruang Server'],
            ['AP-003', 'Yamato Powder 3Kg', 'APAR', 'Ruang Meeting'],
            // Fire Alarm
            ['FA-001', 'Hochiki Photoelectric', 'Fire Alarm', 'Lobby Utama'],
            ['FA-002', 'Notifier AFP-200', 'Fire Alarm', 'Aula Besar'],
            ['FA-003', 'Apollo Series 65', 'Fire Alarm', 'Ruang Rapat Direksi'],
            // Hydrant
            ['HY-001', 'Ozeki Indoor Box', 'Hydrant', 'Lobby Utama'],
            ['HY-002', 'Ozeki Pillar', 'Hydrant', 'Basement'],
            ['HY-003', 'Ozeki Landing Valve', 'Hydrant', 'Aula Besar'],
            // Genset
            ['GS-001', 'Cummins 500 kVA', 'Genset', 'Basement'],
            ['GS-002', 'Perkins 250 kVA', 'Genset', 'Ruang ME'],
            ['GS-003', 'Caterpillar 100 kVA', 'Genset', 'Basement'],
            ['GS-004', 'Yanmar 50 kVA', 'Genset', 'Rooftop'],
        ];

        $teknisi = ['67890', '67891', '67892'];

        foreach ($alat as $index => [$barcode, $merk, $namaKategori, $namaLokasi]) {
            $kategori = Kategori::where('nama', $namaKategori)->first();
            $lokasi = Lokasi::where('nama_lokasi', $namaLokasi)->first();

            if ($kategori === null) {
                continue;
            }

            Alat::updateOrCreate(
                ['barcode_alat' => $barcode],
                [
                    'merk_alat' => $merk,
                    'id_kategori' => $kategori->id_kategori,
                    'id_lokasi' => $lokasi?->id_lokasi,
                    'penanggung_jawab' => $teknisi[$index % count($teknisi)],
                    'ditugaskan_pada' => Carbon::now()->subDays(($index % 7) + 1),
                ],
            );
        }
    }

    /**
     * Riwayat pemeliharaan.
     *
     * Jarak waktu dihitung dari SIKLUS kategori (faktor 0.2 / 0.5 / 1.5 / 4.0)
     * sehingga selalu menghasilkan campuran alat tepat waktu dan overdue,
     * berapa pun nilai maintenance_cycle_days-nya.
     *
     * Satu alat (AC-003) sengaja DIBIARKAN tanpa riwayat untuk menguji jalur
     * "belum pernah dipelihara".
     */
    private function seedMaintenance(): void
    {
        $tanpaRiwayat = ['AC-003'];
        $faktor = [0.2, 0.5, 1.5, 4.0];
        $kondisiBaik = ['baik', 'baik', 'kurang_baik', 'rusak'];

        $alatList = Alat::with('kategori')
            ->orderBy('barcode_alat')
            ->get();

        foreach ($alatList as $i => $alat) {
            if (in_array($alat->barcode_alat, $tanpaRiwayat, true)) {
                continue;
            }

            $kategori = $alat->kategori;
            $cycle = (int) ($kategori?->maintenance_cycle_days ?? 30);

            // 1 sesi riwayat per alat; sesekali tambah sesi kedua yang lebih baru.
            $sesi = [$faktor[$i % 4]];

            if ($i % 3 === 0) {
                $sesi[] = $faktor[($i + 1) % 4];
            }

            foreach ($sesi as $s => $f) {
                $hariLalu = max(1, (int) round($cycle * $f));
                $waktu = Carbon::now()->subDays($hariLalu)->setTime(8 + ($i % 8), ($i * 7) % 60);
                $kondisi = $kondisiBaik[($i + $s) % 4];

                // Status verifikasi deterministik: sebagian menunggu, sebagian
                // disetujui/ditolak agar antrean Verifikasi & badge berisi data.
                $statusVerifikasi = ['menunggu', 'disetujui', 'ditolak'][($i + $s) % 3];
                $terverifikasi = $statusVerifikasi !== 'menunggu';

                $maintenance = Maintenance::updateOrCreate(
                    ['client_uuid' => "seed-{$alat->barcode_alat}-{$s}"],
                    [
                        'barcode_alat' => $alat->barcode_alat,
                        'username' => '67890',
                        'id_lokasi' => $alat->id_lokasi,
                        'id_kategori' => $alat->id_kategori,
                        'waktu_maintenance' => $waktu,
                        'catatan' => $s === 0
                            ? 'Pemeriksaan rutin sesuai jadwal.'
                            : 'Pemeriksaan ulang setelah perbaikan.',
                        'kondisi_keseluruhan' => $kondisi,
                        'status_verifikasi' => $statusVerifikasi,
                        'diverifikasi_oleh' => $terverifikasi ? '11111' : null,
                        'waktu_verifikasi' => $terverifikasi ? Carbon::now()->subDays(max(0, $hariLalu - 1)) : null,
                        'komentar_verifikasi' => $terverifikasi ? 'Hasil pemeriksaan diverifikasi.' : null,
                    ],
                );

                // Isi detail sesuai checklist kategori (semua item terisi).
                foreach ($kategori?->spesifikasi()->orderBy('urutan')->get() ?? [] as $j => $spec) {
                    $maintenance->detail()->updateOrCreate(
                        ['id_spesifikasi' => $spec->id_spesifikasi],
                        ['status' => $this->nilaiContoh($spec, $i, $j)],
                    );
                }
            }
        }
    }

    /**
     * Nilai contoh yang masuk akal menurut nama & tipe field, mis.
     * Voltage -> 220-an, Ampere -> 2–15, Tekanan -> 4–9 Bar.
     */
    private function nilaiContoh(Spesifikasi $spec, int $i, int $j): string
    {
        if ($spec->tipe_input === 'select') {
            $opsi = array_filter(array_map('trim', explode('|', (string) $spec->opsi)));

            return $opsi === [] ? 'Baik' : $opsi[($i + $j) % count($opsi)];
        }

        if ($spec->tipe_input !== 'number') {
            return 'Sesuai standar';
        }

        $nama = strtolower($spec->nama_spesifikasi);

        [$min, $max] = match (true) {
            str_contains($nama, 'voltage'), str_contains($nama, 'tegangan') => [215, 230],
            str_contains($nama, 'ampere'), str_contains($nama, 'arus') => [2, 15],
            str_contains($nama, 'freon'), str_contains($nama, 'tekanan') => [4, 9],
            str_contains($nama, 'suhu') => [26, 38],
            str_contains($nama, 'frekuensi') => [49, 51],
            str_contains($nama, 'tahanan') => [1, 5],
            str_contains($nama, 'tinggi') => [4, 8],
            str_contains($nama, 'berat') => [3, 7],
            str_contains($nama, 'jam') => [100, 900],
            default => [10, 200],
        };

        $span = $max - $min + 1;

        return (string) ($min + (($i * 17 + $j * 29) % $span));
    }
}
