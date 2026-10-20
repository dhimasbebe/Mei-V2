/// Hasil satu percobaan penyerahan berkas/teks ke pengguna.
///
/// Dipisah dari `file_delivery.dart` agar implementasi per platform dapat
/// mengimpornya tanpa impor melingkar. Modul **Dart murni** (tanpa
/// `package:flutter`) sehingga aman dipakai di semua platform.
library;

class HasilPenyerahan {
  const HasilPenyerahan({required this.berhasil, this.pesan});

  /// `true` bila sheet bagikan/unduhan berhasil dibuka.
  final bool berhasil;

  /// Alasan kegagalan (untuk ditampilkan); `null` bila berhasil.
  final String? pesan;

  static const HasilPenyerahan sukses = HasilPenyerahan(berhasil: true);

  factory HasilPenyerahan.gagal([String? pesan]) =>
      HasilPenyerahan(berhasil: false, pesan: pesan);

  @override
  String toString() => berhasil ? 'HasilPenyerahan(sukses)' : 'HasilPenyerahan(gagal: $pesan)';
}
