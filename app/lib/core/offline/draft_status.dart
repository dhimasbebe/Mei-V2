/// Status sebuah draf pemeliharaan di antrean sinkron offline.
///
/// Modul **Dart murni** — TIDAK boleh mengimpor `package:flutter` apa pun,
/// supaya dapat diuji lewat `dart.exe` (`tools/modelcheck`). Lihat
/// `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.1.
library;

/// Lima keadaan draf beserta kode string untuk serialisasi JSON.
///
/// Kode string dipakai apa adanya saat menulis ke `shared_preferences`,
/// sehingga nilainya **stabil** dan tidak boleh diubah tanpa migrasi.
enum DraftStatus {
  /// Menunggu kesempatan dikirim; satu-satunya status yang boleh di-retry
  /// otomatis (AC-A10, AC-A13).
  menungguSinkron('menunggu_sinkron'),

  /// Sedang dikirim ke server; pencegahan kiriman ganda (AC-A13).
  sedangKirim('sedang_kirim'),

  /// Sudah diterima server (201/200) (AC-A10).
  terkirim('terkirim'),

  /// Ditolak server secara terminal: 422 validasi (AC-A14) atau 403 role
  /// (AC-A16). TIDAK pernah diulang otomatis.
  ditolakServer('ditolak_server'),

  /// Ditahan karena 401 (token kedaluwarsa); menghentikan seluruh antrean
  /// (AC-A15).
  ditahan('ditahan');

  const DraftStatus(this.code);

  /// Kode string stabil untuk serialisasi.
  final String code;

  /// Memetakan kembali kode string ke status. Kode tak dikenal / `null`
  /// dikembalikan sebagai [DraftStatus.menungguSinkron] (fail-safe: draf
  /// tetap dicoba dikirim, tidak pernah hilang diam-diam).
  static DraftStatus fromCode(String? code) {
    for (final DraftStatus status in DraftStatus.values) {
      if (status.code == code) return status;
    }
    return DraftStatus.menungguSinkron;
  }

  /// Hanya [DraftStatus.menungguSinkron] yang boleh diulang otomatis oleh
  /// mesin sinkron (AC-A10, AC-A14, AC-A15, AC-A16).
  bool get bolehDiulangOtomatis => this == DraftStatus.menungguSinkron;
}
