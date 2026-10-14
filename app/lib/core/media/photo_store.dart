/// Penyimpanan berkas foto lokal — API lintas platform.
///
/// Implementasi dipilih saat kompilasi:
///  * `dart:io`   → `photo_store_io.dart` (mobile/desktop, memakai
///    `path_provider` sehingga draf foto tahan tutup aplikasi).
///  * `dart:html` → `photo_store_web.dart` (web, hanya di memori).
///  * default     → `photo_store_stub.dart` (menolak dengan jelas).
///
/// Lihat `docs/DESIGN-FEATURES-V3.md` §5.2.
library;

import 'foto_lokal.dart';
import 'photo_store_stub.dart'
    if (dart.library.io) 'photo_store_io.dart'
    if (dart.library.html) 'photo_store_web.dart' as impl;

/// Simpan/pulihkan berkas foto lokal.
abstract class PhotoStore {
  const PhotoStore._();

  /// Menyimpan [bytes] sebagai berkas foto dan mengembalikan [FotoLokal].
  static Future<FotoLokal> simpan({
    required List<int> bytes,
    required String nama,
    required String mime,
  }) =>
      impl.simpan(bytes: bytes, nama: nama, mime: mime);

  /// Membaca kembali bytes dari [kunci]; `null` bila tidak ada.
  static Future<List<int>?> baca(String kunci) => impl.baca(kunci);

  /// Menghapus berkas pada [kunci] (mengabaikan bila tidak ada).
  static Future<void> hapus(String kunci) => impl.hapus(kunci);
}
