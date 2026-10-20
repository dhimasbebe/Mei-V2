import 'hasil_penyerahan.dart';

/// Implementasi cadangan [FileDelivery] (tidak ada `dart:io` maupun
/// `dart:html`).
///
/// Tidak melempar: mengembalikan kegagalan bersih supaya UI dapat menampilkan
/// fallback "salin tautan" alih-alih hancur.
bool get didukung => false;

Future<HasilPenyerahan> bagikanBerkas({
  required List<int> bytes,
  required String nama,
  required String mime,
  String? judul,
}) async =>
    HasilPenyerahan.gagal('Berbagi berkas tidak didukung di platform ini.');

Future<HasilPenyerahan> bagikanTeks({
  required String teks,
  String? judul,
}) async =>
    HasilPenyerahan.gagal('Berbagi teks tidak didukung di platform ini.');
