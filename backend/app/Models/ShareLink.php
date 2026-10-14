<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Tautan bagikan publik satu laporan pemeliharaan (WS O, Fitur Tahap 3).
 *
 * PK: id_share. Tabel append-only kecuali pencabutan (soft revoke):
 * pencabutan hanya mengisi `revoked_at`, baris dipertahankan untuk jejak
 * audit. Lihat `docs/DESIGN-FEATURES-V3.md` §C.2.2.
 */
class ShareLink extends Model
{
    protected $table = 'share_links';

    protected $primaryKey = 'id_share';
    public $incrementing = true;

    /** Hanya `created_at` — baris tidak pernah diubah selain pencabutan. */
    public $timestamps = false;

    protected $fillable = [
        'id_maintenance',
        'token',
        'created_by',
        'expires_at',
        'revoked_at',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'revoked_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function maintenance(): BelongsTo
    {
        return $this->belongsTo(Maintenance::class, 'id_maintenance', 'id_maintenance');
    }

    /**
     * Tautan masih berlaku: belum dicabut dan belum kedaluwarsa.
     * Pengecekan dilakukan manual (bukan query scope) agar halaman publik
     * dapat membedakan "token tidak ada" vs "token tidak berlaku" — keduanya
     * tetap dijawab 404 yang sama.
     */
    public function masihBerlaku(): bool
    {
        return $this->revoked_at === null
            && ($this->expires_at === null || $this->expires_at->isFuture());
    }
}
