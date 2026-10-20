/// Aturan penamaan & pemeriksaan berkas ekspor (WS L, M, N — Fitur Tahap 3).
///
/// Modul **Dart murni** (tanpa `package:flutter`) supaya dapat diverifikasi
/// `tools/modelcheck` di dalam sandbox pengembangan yang tidak bisa menjalankan
/// `flutter test`. Lihat `docs/DESIGN-FEATURES-V3.md` §C.2.4.
///
/// Penamaan sengaja DISAMAKAN dengan nama berkas yang dikirim backend lewat
/// `->download(...)` pada `PdfController`/`QrLabelController`/ekspor CSV, agar
/// berkas yang diunduh dari aplikasi dan dari peramban tidak pernah bertabrakan
/// nama maupun berbeda konvensi.
library;

/// Spesifikasi nama berkas + deteksi isi untuk hasil ekspor biner.
abstract class FileExportSpec {
  const FileExportSpec._();

  /// Awalan berkas PDF (`%PDF-`).
  static const List<int> _tandaPdf = <int>[0x25, 0x50, 0x44, 0x46];

  /// Rentang PDF periode maksimum yang diterima backend (hari) — R11.
  static const int maxHariPdf = 90;

  /// Jumlah baris maksimum dalam PDF periode — R11.
  static const int maxBarisPdf = 500;

  /// Dua digit, mis. `7` → `07`.
  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// `YYYY-MM-DD` (tanggal lokal, tanpa zona waktu).
  static String tanggal(DateTime d) => '${d.year}-${_dua(d.month)}-${_dua(d.day)}';

  /// `meiv-laporan-<id>.pdf` — selaras `PdfController::show`.
  static String namaPdfLaporan(int id) => 'meiv-laporan-$id.pdf';

  /// `meiv-ringkasan-<dari>_<sampai>.pdf` — selaras `PdfController::periode`.
  static String namaPdfPeriode(DateTime dari, DateTime sampai) =>
      'meiv-ringkasan-${tanggal(dari)}_${tanggal(sampai)}.pdf';

  /// `meiv-label-qr.pdf` — selaras `QrLabelController::store`.
  static String namaLabelQr() => 'meiv-label-qr.pdf';

  /// `meiv-riwayat-<dari>_<sampai>.csv` — ekspor CSV periode.
  static String namaCsvPeriode(DateTime dari, DateTime sampai) =>
      'meiv-riwayat-${tanggal(dari)}_${tanggal(sampai)}.csv';

  /// `true` bila [bytes] benar-benar berkas PDF (diawali `%PDF`).
  ///
  /// AC-L1 menetapkan body PDF diawali `%PDF`; pemeriksaan ini mencegah
  /// aplikasi menyimpan halaman galat HTML/JSON sebagai `.pdf`.
  static bool tampakPdf(List<int> bytes) {
    if (bytes.length < _tandaPdf.length) return false;
    for (int i = 0; i < _tandaPdf.length; i++) {
      if (bytes[i] != _tandaPdf[i]) return false;
    }
    return true;
  }

  /// `true` bila [bytes] berisi data (bukan kosong / bukan galat HTML).
  ///
  /// Dipakai untuk CSV: backend mengirim teks tanpa envelope, sehingga cukup
  /// memastikan ada isi dan bukan awal dokumen HTML.
  static bool tampakCsv(List<int> bytes) {
    if (bytes.isEmpty) return false;
    final String awal = String.fromCharCodes(bytes.take(15)).toLowerCase();
    return !awal.startsWith('<!doctype') && !awal.startsWith('<html');
  }

  /// `true` bila rentang [dari]–[sampai] melebihi batas backend (90 hari).
  ///
  /// Dihitung inklusif seperti `PdfController::periode`
  /// (`diffInDays + 1 > MAX_HARI`), supaya pengguna diberi tahu SEBELUM
  /// permintaan ditolak 422.
  static bool rentangTerlaluPanjang(DateTime dari, DateTime sampai) {
    final int hari = sampai.difference(dari).inDays + 1;
    return hari > maxHariPdf;
  }

  /// Ukuran berkas dalam satuan yang enak dibaca ("842 KB", "1.4 MB").
  static String ukuranManusia(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
