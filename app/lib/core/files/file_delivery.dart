/// Penyerahan berkas ke pengguna (unduh/bagikan) — API lintas platform.
///
/// Implementasi dipilih saat kompilasi, mengikuti pola yang sudah dipakai
/// `core/media/photo_store.dart`:
///  * `dart:io`    → `file_delivery_io.dart` (mobile/desktop: tulis ke direktori
///    sementara lewat `path_provider`, lalu buka sheet bagikan OS).
///  * `dart:html`  → `file_delivery_web.dart` (web: `XFile.fromData` + Web
///    Share API; jatuh ke unduhan biasa bila API tidak tersedia).
///  * default      → `file_delivery_stub.dart` (menolak dengan jelas).
///
/// Kegagalan TIDAK pernah dilempar ke UI: pemanggil menerima
/// [HasilPenyerahan.berhasil] `false` dan menampilkan fallback (mis. "salin
/// tautan ke papan klip"). Ini yang membuat AC-O8/O9 aman di perangkat tanpa
/// sheet bagikan.
library;

import 'file_delivery_stub.dart'
    if (dart.library.io) 'file_delivery_io.dart'
    if (dart.library.html) 'file_delivery_web.dart' as impl;
import 'hasil_penyerahan.dart';

export 'hasil_penyerahan.dart';

/// Simpan & bagikan berkas biner (PDF/CSV) atau teks kepada pengguna.
abstract class FileDelivery {
  const FileDelivery._();

  /// `true` bila platform ini dapat menyerahkan berkas (bukan stub).
  static bool get didukung => impl.didukung;

  /// Menyerahkan [bytes] sebagai berkas bernama [nama] bertipe [mime].
  ///
  /// [judul] menjadi subjek sheet bagikan (mis. "Laporan #12").
  static Future<HasilPenyerahan> bagikanBerkas({
    required List<int> bytes,
    required String nama,
    required String mime,
    String? judul,
  }) =>
      impl.bagikanBerkas(bytes: bytes, nama: nama, mime: mime, judul: judul);

  /// Membagikan [teks] biasa (mis. URL tautan bagikan).
  static Future<HasilPenyerahan> bagikanTeks({
    required String teks,
    String? judul,
  }) =>
      impl.bagikanTeks(teks: teks, judul: judul);
}
