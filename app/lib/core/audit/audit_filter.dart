/// Filter rentang tanggal untuk layar audit log — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Normalisasi `dari`/`sampai` dan
/// validasinya diuji lewat `tools/modelcheck` (mendukung AC-D3 di lapisan UI).
/// Lihat `docs/DESIGN-FEATURES-V3.md` §5.3.
library;

/// Aturan filter tanggal audit log.
abstract class AuditFilter {
  const AuditFilter._();

  /// Awal hari (00:00:00) untuk `dari` — supaya filter mencakup seluruh hari.
  static DateTime? normalisasiDari(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  /// Akhir hari (23:59:59) untuk `sampai` — supaya catatan jam malam hari
  /// itu tetap ikut.
  static DateTime? normalisasiSampai(DateTime? d) => d == null
      ? null
      : DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// `true` bila pasangan rentang valid. Salah satu `null` berarti "tanpa
  /// batas" → selalu valid. Invalid bila `dari` SETELAH `sampai`.
  static bool valid(DateTime? dari, DateTime? sampai) {
    if (dari == null || sampai == null) return true;
    return !dari.isAfter(sampai);
  }

  /// Format `yyyy-MM-dd` untuk query `dari=`/`sampai=` (kontrak endpoint
  /// `whereDate`). `null` → `null` (parameter tidak dikirim).
  static String? keQuery(DateTime? d) {
    if (d == null) return null;
    String p(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }
}
