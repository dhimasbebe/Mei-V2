<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Kategori alat (AC, APAR, Fire Alarm, Genset, Hydrant, Panel Listrik,
 * Penangkal Petir). Serialisasi mengikuti
 * `app/lib/domain/models/kategori.dart` -> memakai kunci `jumlah_alat`.
 */
class Kategori extends Model
{
    /**
     * Nama tabel ditulis eksplisit: pluralizer Laravel akan mencari
     * `kategoris`, sedangkan tabel warisan Mei-V bernama `kategori`.
     */
    protected $table = 'kategori';

    protected $primaryKey = 'id_kategori';
    public $incrementing = true;
    protected $keyType = 'int';

    protected $fillable = [
        'nama',
        'deskripsi',
        'maintenance_cycle_days',
        'icon_asset',
    ];

    protected $appends = [
        'jumlah_alat',
    ];

    protected $casts = [
        'maintenance_cycle_days' => 'integer',
    ];

    public function spesifikasi(): HasMany
    {
        return $this->hasMany(Spesifikasi::class, 'id_kategori', 'id_kategori');
    }

    public function alat(): HasMany
    {
        return $this->hasMany(Alat::class, 'id_kategori', 'id_kategori');
    }

    /**
     * Jumlah alat per kategori.
     *
     * Gunakan `Kategori::withCount('alat')` di controller agar tidak N+1 —
     * accessor ini otomatis memakai hasil `withCount` bila tersedia.
     */
    public function getJumlahAlatAttribute(): int
    {
        if (array_key_exists('alat_count', $this->attributes)) {
            return (int) $this->attributes['alat_count'];
        }

        return $this->alat()->count();
    }
}
