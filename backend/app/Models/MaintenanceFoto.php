<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

/**
 * Foto lampiran satu sesi pemeliharaan. PK: id_foto.
 *
 * Serialisasi mengikuti `docs/DESIGN-FEATURES-V3.md` §10.2 — klien membaca
 * `{ id_foto, url, mime, ukuran }`. `url` dihitung dari `path` (disk `public`),
 * sedangkan `path`/`username` disembunyikan dari respons.
 */
class MaintenanceFoto extends Model
{
    protected $table = 'maintenance_foto';

    protected $primaryKey = 'id_foto';

    /** Tabel append-only: hanya `created_at` (diisi eksplisit / DB default). */
    public $timestamps = false;

    protected $fillable = [
        'id_maintenance',
        'path',
        'mime',
        'ukuran',
        'username',
        'created_at',
    ];

    protected $hidden = [
        'path',
        'username',
    ];

    protected $appends = [
        'url',
    ];

    protected function casts(): array
    {
        return [
            'ukuran' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function maintenance(): BelongsTo
    {
        return $this->belongsTo(Maintenance::class, 'id_maintenance', 'id_maintenance');
    }

    /**
     * URL publik berkas (mis. `/storage/foto/ab12.jpg`).
     */
    public function getUrlAttribute(): string
    {
        return Storage::disk('public')->url($this->path);
    }
}
