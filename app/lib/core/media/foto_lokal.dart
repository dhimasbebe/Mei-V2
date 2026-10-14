/// Referensi satu foto lokal yang belum terunggah.
///
/// Modul **Dart murni** (tanpa `package:flutter`) supaya aman dipakai lintas
/// platform. `kunci` adalah path berkas di mobile, atau `mem://<id>` di web
/// (foto hanya bertahan selama sesi). Lihat `docs/DESIGN-FEATURES-V3.md` §5.2.
library;

class FotoLokal {
  const FotoLokal({
    required this.kunci,
    required this.nama,
    required this.mime,
    required this.persisten,
    this.ukuran = 0,
  });

  /// Penanda lokasi foto: path berkas (mobile) atau `mem://<id>` (web).
  final String kunci;

  /// Nama berkas asal (menentukan ekstensi yang divalidasi server).
  final String nama;

  /// Tipe MIME hasil kompresi (`image/jpeg` atau `image/png`).
  final String mime;

  /// `true` bila foto bertahan setelah aplikasi ditutup (butuh `path_provider`).
  final bool persisten;

  /// Ukuran berkas hasil kompresi (byte) — dipakai untuk kuota total
  /// 100 MB per laporan ([PhotoPolicy.maxTotalBytes]). `0` = tidak diketahui.
  final int ukuran;

  /// `true` bila foto hanya ada di memori (web / tanpa `path_provider`).
  bool get diMemori => !persisten;
}
