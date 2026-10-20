import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'hasil_penyerahan.dart';

/// Implementasi [FileDelivery] untuk mobile/desktop (`dart:io`).
///
/// Berkas ditulis ke `<direktori sementara>/meiv-ekspor/<nama>` lebih dulu:
/// sheet bagikan Android/iOS memerlukan PATH berkas nyata (`XFile.fromData`
/// tidak dapat dibagikan di sana), dan direktori sementara dibersihkan sistem
/// sehingga unduhan tidak menumpuk di penyimpanan pengguna.
bool get didukung => true;

Future<HasilPenyerahan> bagikanBerkas({
  required List<int> bytes,
  required String nama,
  required String mime,
  String? judul,
}) async {
  try {
    final Directory dasar = await getTemporaryDirectory();
    final Directory folder = Directory('${dasar.path}${Platform.pathSeparator}meiv-ekspor');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final File berkas = File('${folder.path}${Platform.pathSeparator}$nama');
    await berkas.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      <XFile>[XFile(berkas.path, mimeType: mime)],
      subject: judul,
    );

    return HasilPenyerahan.sukses;
  } catch (e) {
    // Plugin tidak tersedia / pengguna menolak / penyimpanan penuh — UI
    // menampilkan pesan ini apa adanya, jadi tidak boleh kosong.
    return HasilPenyerahan.gagal('Gagal menyiapkan berkas: $e');
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
    return HasilPenyerahan.gagal('Gagal membuka sheet bagikan: $e');
  }
}
