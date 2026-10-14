<?php

namespace App\Support;

use App\Models\AuditLog;

/**
 * Penulis log audit terpusat.
 *
 * Dipanggil oleh controller CRUD (users/alat/kategori/lokasi/spesifikasi),
 * verifikasi maintenance, penugasan alat, dan login. Aktor diambil dari
 * pengguna yang sedang terautentikasi pada request berjalan.
 */
class AuditLogger
{
    /**
     * Tulis satu baris audit.
     *
     * @param  string       $aksi        create|update|delete|verify|assign|login
     * @param  string       $entitas     users|alat|kategori|lokasi|spesifikasi|maintenance
     * @param  string       $entitasId   kunci entitas (username/barcode/id)
     * @param  array        $detail      detail tambahan (disimpan sebagai JSON)
     * @param  string|null  $actor       penimpa aktor (mis. saat login, sebelum auth)
     */
    public static function log(
        string $aksi,
        string $entitas,
        string $entitasId,
        array $detail = [],
        ?string $actor = null,
    ): void {
        $request = request();
        $actor ??= $request->user()?->username;

        AuditLog::create([
            'actor_username' => $actor ?? 'system',
            'aksi' => $aksi,
            'entitas' => $entitas,
            'entitas_id' => $entitasId,
            'detail' => $detail === []
                ? null
                : json_encode($detail, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);
    }

    /**
     * Tulis satu baris audit `update` dalam bentuk diff `{field: {lama, baru}}`.
     *
     * ADITIF (Fitur Tahap 3, keputusan U2): hanya field yang benar-benar
     * berubah yang dicatat. Bentuk lama (`{field: nilai}`) tetap didukung
     * `AuditDetail.format` di klien, jadi baris audit lama tidak rusak.
     *
     * @param  array  $lama  nilai SEBELUM perubahan (field => nilai)
     * @param  array  $baru  nilai SESUDAH perubahan (field => nilai)
     */
    public static function logUpdate(
        string $entitas,
        string $entitasId,
        array $lama,
        array $baru,
        ?string $actor = null,
    ): void {
        $detail = [];

        foreach (array_unique(array_merge(array_keys($lama), array_keys($baru))) as $field) {
            $sebelum = $lama[$field] ?? null;
            $sesudah = $baru[$field] ?? null;

            if ($sebelum === $sesudah) {
                continue; // hanya catat yang berubah
            }

            $detail[$field] = ['lama' => $sebelum, 'baru' => $sesudah];
        }

        self::log('update', $entitas, $entitasId, $detail, $actor);
    }
}
