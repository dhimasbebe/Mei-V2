<?php

namespace Tests\Unit;

use App\Models\Spesifikasi;
use Tests\TestCase;

/**
 * Parsing opsi dropdown (kolom `opsi` menyimpan nilai dipisah tanda `|`).
 * Ini kontrak yang dipakai klien Flutter pada Spesifikasi.opsi.
 */
class SpesifikasiOpsiTest extends TestCase
{
    public function test_opsi_dipecah_dari_tanda_pipe(): void
    {
        $spec = new Spesifikasi(['opsi' => 'Baik|Tidak Baik|Rusak']);

        $this->assertSame(['Baik', 'Tidak Baik', 'Rusak'], $spec->opsi_array);
    }

    public function test_opsi_kosong_menghasilkan_array_kosong(): void
    {
        $this->assertSame([], (new Spesifikasi(['opsi' => null]))->opsi_array);
        $this->assertSame([], (new Spesifikasi(['opsi' => '']))->opsi_array);
    }

    public function test_spasi_di_sekitar_opsi_dibersihkan(): void
    {
        $spec = new Spesifikasi(['opsi' => ' Bersih | Tidak ']);

        $this->assertSame(['Bersih', 'Tidak'], $spec->opsi_array);
    }

    public function test_tipe_input_membedakan_jenis_field(): void
    {
        $this->assertSame('number', (new Spesifikasi(['tipe_input' => 'number']))->tipe_input);
        $this->assertSame('select', (new Spesifikasi(['tipe_input' => 'select']))->tipe_input);
    }
}
