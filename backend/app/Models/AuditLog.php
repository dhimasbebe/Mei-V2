<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Jejak audit aksi pengguna. Tabel: `audit_log`, PK: id_audit.
 *
 * Hanya memiliki `created_at` (append-only) sehingga `$timestamps = false`
 * dan nilai `created_at` diisi eksplisit oleh `App\Support\AuditLogger`.
 */
class AuditLog extends Model
{
    protected $table = 'audit_log';

    protected $primaryKey = 'id_audit';
    public $incrementing = true;
    protected $keyType = 'int';

    public $timestamps = false;

    protected $fillable = [
        'actor_username',
        'aksi',
        'entitas',
        'entitas_id',
        'detail',
        'ip_address',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }
}
