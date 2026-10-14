/// Kebijakan foto lampiran (jumlah, ukuran, dimensi target) — **Dart murni**.
///
/// Modul ini **netral terhadap format berkas**: hanya mengatur batas ukuran,
/// jumlah, dan dimensi target. Keputusan encoder (JPEG/PNG) sengaja TIDAK
/// diasumsikan di sini — masih menunggu persetujuan paket di tugas lain
/// (`docs/DESIGN-FEATURES-V3.md` §5.2). TIDAK mengimpor `package:flutter`.
library;

/// Aturan validasi & penskalaan foto lampiran.
abstract class PhotoPolicy {
  const PhotoPolicy._();

  /// Jumlah maksimum foto per laporan.
  static const int maxFotos = 5;

  /// Ukuran maksimum satu berkas foto (5 MB).
  static const int maxBytes = 5 * 1024 * 1024;

  /// Panjang maksimum sisi terpanjang setelah resize (px).
  static const int maxSisiPx = 1600;

  /// `true` bila masih boleh menambah foto saat ini ada [currentCount] foto.
  ///
  /// `false` saat `currentCount >= maxFotos` (AC-C9).
  static bool canAdd(int currentCount) => currentCount < maxFotos;

  /// `true` bila ukuran [bytes] diterima (1 ≤ [bytes] ≤ [maxBytes]) (AC-C10).
  static bool acceptSize(int bytes) => bytes > 0 && bytes <= maxBytes;

  /// `true` bila citra berukuran [lebar]×[tinggi] perlu diperkecil agar sisi
  /// terpanjangnya ≤ [maxSisiPx].
  static bool perluResize(int lebar, int tinggi) {
    if (lebar <= 0 || tinggi <= 0) return false;
    return (lebar > maxSisiPx) || (tinggi > maxSisiPx);
  }

  /// Dimensi target setelah resize (sisi terpanjang ≤ [maxSisiPx], rasio
  /// dipertahankan). Citra yang sudah kecil dikembalikan apa adanya.
  ///
  /// Mengembalikan `[lebar, tinggi]`.
  static List<int> targetDimensi(int lebar, int tinggi) {
    if (lebar <= 0 || tinggi <= 0) return <int>[lebar, tinggi];
    final int sisiTerpanjang = lebar > tinggi ? lebar : tinggi;
    if (sisiTerpanjang <= maxSisiPx) return <int>[lebar, tinggi];

    final double skala = maxSisiPx / sisiTerpanjang;
    int w = (lebar * skala).round();
    int h = (tinggi * skala).round();
    // Jaga agar tidak pernah menjadi 0 pada sisi yang valid.
    if (w < 1) w = 1;
    if (h < 1) h = 1;
    return <int>[w, h];
  }

  /// Daftar dimensi target bertahap (turun) bila hasil masih > [maxBytes].
  ///
  /// Turun dari [maxSisiPx] menuju 1024 px, seperti disebut §5.2
  /// (1600 → 1280 → 1024). Berguna sebagai panduan kompresi cadangan.
  static List<int> tahapSisi() => <int>[maxSisiPx, 1280, 1024];
}
