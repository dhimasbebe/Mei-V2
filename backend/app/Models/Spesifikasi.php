<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Spesifikasi extends Model
{
    /**
     * Nama tabel ditulis eksplisit: pluralizer Laravel akan mencari
     * `spesifikasis`, sedangkan tabel warisan Mei-V bernama `spesifikasi`.
     */
    protected $table = 'spesifikasi';

    protected $primaryKey = 'id_spesifikasi';
    public $incrementing = true;

    protected $fillable = [
        'id_kategori',
        'nama_spesifikasi',
        'tipe_input',
        'satuan',
        'opsi',
        'urutan',
    ];

    public function kategori(): BelongsTo
    {
        return $this->belongsTo(Kategori::class, 'id_kategori', 'id_kategori');
    }

    public function getOpsiArrayAttribute(): array
    {
        if (empty($this->opsi)) return [];
        return array_map('trim', explode('|', $this->opsi));
    }
}
