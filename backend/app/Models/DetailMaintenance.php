<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Satu baris hasil pemeliharaan per item checklist.
 * Serialisasi mengikuti `app/lib/domain/models/maintenance.dart`
 * (DetailMaintenance) -> butuh `nama_spesifikasi` dan `satuan` yang datar.
 */
class DetailMaintenance extends Model
{
    protected $table = 'detail_maintenance';

    // PK bawaan Laravel: kolom `id` (lihat migrasi 2024_01_01_000006).
    protected $fillable = [
        'id_maintenance',
        'id_spesifikasi',
        'status',
    ];

    protected $appends = [
        'nama_spesifikasi',
        'satuan',
    ];

    protected $hidden = [
        'spesifikasi',
    ];

    public function maintenance(): BelongsTo
    {
        return $this->belongsTo(Maintenance::class, 'id_maintenance', 'id_maintenance');
    }

    public function spesifikasi(): BelongsTo
    {
        return $this->belongsTo(Spesifikasi::class, 'id_spesifikasi', 'id_spesifikasi');
    }

    public function getNamaSpesifikasiAttribute(): ?string
    {
        return $this->spesifikasi?->nama_spesifikasi;
    }

    public function getSatuanAttribute(): ?string
    {
        return $this->spesifikasi?->satuan;
    }
}
