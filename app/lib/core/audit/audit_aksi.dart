/// Terjemahan kode aksi audit ke label Indonesia — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2.
library;

/// Peta kode aksi → label tampilan.
abstract class AuditAksi {
  const AuditAksi._();

  /// Label resmi per kode aksi (huruf kecil).
  static const Map<String, String> labels = <String, String>{
    'create': 'Buat',
    'update': 'Ubah',
    'delete': 'Hapus',
    'verify': 'Verifikasi',
    'assign': 'Tugaskan',
    'login': 'Masuk',
  };

  /// Label untuk [aksi]. Pencocokan tanpa peduli huruf besar/kecil. Kode tak
  /// dikenal → dikembalikan apa adanya (AC-D7).
  static String label(String aksi) {
    final String kunci = aksi.trim().toLowerCase();
    return labels[kunci] ?? aksi;
  }
}
