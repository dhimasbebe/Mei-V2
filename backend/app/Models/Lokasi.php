<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Lokasi/ruang alat. Serialisasi mengikuti
 * `app/lib/domain/models/lokasi.dart` (butuh `jumlah_alat`).
 */
class Lokasi extends Model
{
    /**
     * Nama tabel ditulis eksplisit: pluralizer Laravel akan mencari
     * `lokasis`, sedangkan tabel warisan Mei-V bernama `lokasi`.
     */
    protected $table = 'lokasi';

    protected $primaryKey = 'id_lokasi';
    public $incrementing = true;

    protected $fillable = [
        'nama_lokasi',
        'lantai',
        'keterangan',
    ];

    protected $appends = [
        'jumlah_alat',
    ];

    protected $casts = [
        'lantai' => 'integer',
    ];

    public function alat(): HasMany
    {
        return $this->hasMany(Alat::class, 'id_lokasi', 'id_lokasi');
    }

    public function maintenance(): HasMany
    {
        return $this->hasMany(Maintenance::class, 'id_lokasi', 'id_lokasi');
    }

    /**
     * Gunakan `Lokasi::withCount('alat')` di controller agar tidak N+1.
     */
    public function getJumlahAlatAttribute(): int
    {
        if (array_key_exists('alat_count', $this->attributes)) {
            return (int) $this->attributes['alat_count'];
        }

        return $this->alat()->count();
    }
}
