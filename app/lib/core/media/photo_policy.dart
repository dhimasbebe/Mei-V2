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
  static const int maxFotos = 15;

  /// Total kuota ukuran gabungan seluruh foto per laporan (100 MB).
  static const int maxTotalBytes = 100 * 1024 * 1024; // 104857600

  /// Ukuran maksimum satu berkas foto (5 MB) — batas per berkas yang wajar
  /// karena aplikasi mengompres ke ±300–500 KB per foto (JPEG q80, ≤1600 px).
  static const int maxBytes = 5 * 1024 * 1024;

  /// Panjang maksimum sisi terpanjang setelah resize (px).
  static const int maxSisiPx = 1600;

  /// `true` bila masih boleh menambah foto saat ini ada [currentCount] foto,
  /// dengan total berkas terpakai [totalBytes] byte dan foto baru berukuran
  /// [bytesBaru] byte (AC-C9).
  ///
  /// Aturan:
  /// - `false` saat `currentCount >= maxFotos`;
  /// - bila [bytesBaru] belum diketahui (0), cukup pastikan kuota total belum
  ///   penuh (`totalBytes < maxTotalBytes`);
  /// - bila [bytesBaru] diketahui (> 0), wajib `totalBytes + bytesBaru <=
  ///   maxTotalBytes`.
  static bool canAdd(int currentCount, {int totalBytes = 0, int bytesBaru = 0}) {
    if (currentCount >= maxFotos) return false;
    if (totalBytes < 0 || bytesBaru < 0) return false;
    if (bytesBaru == 0) return totalBytes < maxTotalBytes;
    return totalBytes + bytesBaru <= maxTotalBytes;
  }

  /// Sisa kuota total (byte) setelah [totalBytes] terpakai — tidak pernah
  /// negatif. Berguna untuk indikator kuota di UI.
  static int sisaKuota(int totalBytes) {
    final int sisa = maxTotalBytes - totalBytes;
    return sisa > 0 ? sisa : 0;
  }

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
