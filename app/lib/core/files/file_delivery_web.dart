import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'hasil_penyerahan.dart';

/// Implementasi [FileDelivery] untuk web.
///
/// Web tidak memiliki berkas yang dapat dialamatkan path, sehingga isi berkas
/// dititipkan sebagai `XFile.fromData` (didukung Web Share API). Bila peramban
/// tidak mendukung berbagi berkas, share_plus memicu unduhan biasa — keduanya
/// dianggap berhasil dari sudut pandang pengguna.
bool get didukung => true;

Future<HasilPenyerahan> bagikanBerkas({
  required List<int> bytes,
  required String nama,
  required String mime,
  String? judul,
}) async {
  try {
    await Share.shareXFiles(
      // `XFile.fromData` menuntut Uint8List; API service mengembalikan
      // List<int> agar netral terhadap platform.
      <XFile>[
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: nama,
          mimeType: mime,
        ),
      ],
      subject: judul,
      // `name` pada XFile.fromData diabaikan di sebagian platform; override ini
      // memastikan berkas tetap bernama benar di dialog unduhan.
      fileNameOverrides: <String>[nama],
    );
    return HasilPenyerahan.sukses;
  } catch (e) {
    return HasilPenyerahan.gagal('Peramban gagal mengunduh berkas: $e');
  }
}

Future<HasilPenyerahan> bagikanTeks({
  required String teks,
  String? judul,
}) async {
  try {
    await Share.share(teks, subject: judul);
    return HasilPenyerahan.sukses;
  } catch (e) {
    return HasilPenyerahan.gagal('Peramban gagal membuka bagikan: $e');
  }
}
