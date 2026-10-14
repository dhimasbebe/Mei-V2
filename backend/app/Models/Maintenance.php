<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Satu sesi pemeliharaan (header). PK: id_maintenance.
 *
 * Serialisasi mengikuti `app/lib/domain/models/maintenance.dart`:
 * klien membaca nama_kategori / merk_alat / nama_users / nama_lokasi / lantai
 * sebagai kolom DATAR (padanan view_maintenance pada sistem lama).
 */
class Maintenance extends Model
{
    /**
     * Nama tabel ditulis eksplisit: pluralizer Laravel akan mencari
     * `maintenances`, sedangkan tabel warisan Mei-V bernama `maintenance`.
     */
    protected $table = 'maintenance';

    protected $primaryKey = 'id_maintenance';
    public $incrementing = true;

    protected $fillable = [
        'waktu_maintenance',
        'barcode_alat',
        'username',
        'id_lokasi',
        'id_kategori',
        'catatan',
        'kondisi_keseluruhan',
        'client_uuid',
        // --- kolom verifikasi (migrasi M1) ---
        'status_verifikasi',
        'diverifikasi_oleh',
        'waktu_verifikasi',
        'komentar_verifikasi',
    ];

    protected $appends = [
        'nama_kategori',
        'merk_alat',
        'nama_users',
        'nama_lokasi',
        'lantai',
    ];

    protected $hidden = [
        'alat',
        'user',
        'lokasi',
        'kategori',
    ];

    protected function casts(): array
    {
        return [
            'waktu_maintenance' => 'datetime',
            'waktu_verifikasi' => 'datetime',
        ];
    }

    // ----------------------------------------------------------------------
    // Relasi
    // ----------------------------------------------------------------------

    public function alat(): BelongsTo
    {
        return $this->belongsTo(Alat::class, 'barcode_alat', 'barcode_alat');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'username', 'username');
    }

    /**
     * Supervisor/Admin yang memverifikasi sesi ini.
     */
    public function verifikator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diverifikasi_oleh', 'username');
    }

    public function lokasi(): BelongsTo
    {
        return $this->belongsTo(Lokasi::class, 'id_lokasi', 'id_lokasi');
    }

    public function kategori(): BelongsTo
    {
        return $this->belongsTo(Kategori::class, 'id_kategori', 'id_kategori');
    }

    public function detail(): HasMany
    {
        return $this->hasMany(DetailMaintenance::class, 'id_maintenance', 'id_maintenance');
    }

    // ----------------------------------------------------------------------
    // Accessor (kolom turunan)
    //
    // Semua controller yang memakai model ini WAJIB eager-load:
    //   with(['detail.spesifikasi', 'alat.kategori', 'lokasi', 'user'])
    // sehingga accessor di bawah tidak memicu query tambahan (N+1).
    // ----------------------------------------------------------------------

    public function getNamaKategoriAttribute(): ?string
    {
        return $this->alat?->kategori?->nama;
    }

    public function getMerkAlatAttribute(): ?string
    {
        return $this->alat?->merk_alat;
    }

    public function getNamaUsersAttribute(): ?string
    {
        return $this->user?->nama_users;
    }

    public function getNamaLokasiAttribute(): ?string
    {
        return $this->lokasi?->nama_lokasi;
    }

    public function getLantaiAttribute(): ?int
    {
        return $this->lokasi?->lantai;
    }
}
