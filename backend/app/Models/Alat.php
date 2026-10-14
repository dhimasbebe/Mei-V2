<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * Alat yang dipelihara. PK: barcode_alat.
 *
 * Serialisasi mengikuti `app/lib/domain/models/alat.dart` pada sisi Flutter:
 * klien membaca objek DATAR (nama_kategori, nama_lokasi, lantai, dst),
 * sehingga kolom hasil join ditambahkan lewat accessor di bawah.
 */
class Alat extends Model
{
    /**
     * Nama tabel ditulis eksplisit: pluralizer Laravel akan mencari `alats`,
     * sedangkan tabel warisan Mei-V bernama `alat` (tunggal, bahasa Indonesia).
     */
    protected $table = 'alat';

    protected $primaryKey = 'barcode_alat';
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'barcode_alat',
        'merk_alat',
        'id_kategori',
        'id_lokasi',
        // --- kolom penugasan (migrasi M3) ---
        'penanggung_jawab',
        'ditugaskan_pada',
    ];

    /**
     * Kolom turunan yang ikut dikirim ke klien.
     */
    protected $appends = [
        'nama_kategori',
        'deskripsi',
        'nama_lokasi',
        'lantai',
        'maintenance_cycle_days',
        'terakhir_maintenance',
        'nama_penanggung_jawab',
    ];

    /**
     * Relasi mentah tidak perlu dikirim (klien memakai versi datar).
     */
    protected $hidden = [
        'kategori',
        'lokasi',
        'maintenance',
        'penanggungJawab',
    ];

    protected function casts(): array
    {
        return [
            'ditugaskan_pada' => 'datetime',
        ];
    }

    public function kategori(): BelongsTo
    {
        return $this->belongsTo(Kategori::class, 'id_kategori', 'id_kategori');
    }

    public function lokasi(): BelongsTo
    {
        return $this->belongsTo(Lokasi::class, 'id_lokasi', 'id_lokasi');
    }

    public function penanggungJawab(): BelongsTo
    {
        return $this->belongsTo(User::class, 'penanggung_jawab', 'username');
    }

    public function maintenance(): HasMany
    {
        return $this->hasMany(Maintenance::class, 'barcode_alat', 'barcode_alat');
    }

    // ----------------------------------------------------------------------
    // Accessor (kolom turunan)
    // ----------------------------------------------------------------------

    public function getNamaKategoriAttribute(): ?string
    {
        return $this->kategori?->nama;
    }

    public function getDeskripsiAttribute(): ?string
    {
        return $this->kategori?->deskripsi;
    }

    public function getNamaLokasiAttribute(): ?string
    {
        return $this->lokasi?->nama_lokasi;
    }

    public function getLantaiAttribute(): ?int
    {
        return $this->lokasi?->lantai;
    }

    public function getMaintenanceCycleDaysAttribute(): int
    {
        return (int) ($this->kategori?->maintenance_cycle_days ?? 30);
    }

    /**
     * Nama teknisi penanggung jawab.
     *
     * WAJIB eager-load `penanggungJawab` di controller agar tidak N+1.
     */
    public function getNamaPenanggungJawabAttribute(): ?string
    {
        return $this->penanggungJawab?->nama_users;
    }

    /**
     * Waktu pemeliharaan terakhir.
     *
     * Nilai diisi massal oleh AlatController (`setAttribute`) supaya daftar
     * alat tidak menimbulkan query N+1. Bila belum diisi -> null, yang berarti
     * "belum pernah dipelihara" (klien menandainya sebagai overdue).
     */
    public function getTerakhirMaintenanceAttribute(): ?string
    {
        $value = $this->attributes['terakhir_maintenance'] ?? null;

        if ($value === null || $value === '') {
            return null;
        }

        return Carbon::parse($value)->toIso8601String();
    }

    /**
     * Query langsung (dipakai bila hanya butuh satu alat).
     */
    public function latestMaintenance(): ?Maintenance
    {
        return $this->maintenance()->latest('waktu_maintenance')->first();
    }
}
