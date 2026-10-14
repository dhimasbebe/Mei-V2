import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'foto_lokal.dart';

/// Implementasi [PhotoStore] untuk platform ber-`dart:io` (mobile/desktop).
///
/// Foto ditulis ke direktori dokumen aplikasi sehingga **tahan penutupan
/// paksa** (§5.2). Bila `path_provider` gagal, error dilempar ke pemanggil
/// (pemanggil menampilkan pesan, tidak menelan kesalahan diam-diam).
Future<FotoLokal> simpan({
  required List<int> bytes,
  required String nama,
  required String mime,
}) async {
  final Directory dokumen = await getApplicationDocumentsDirectory();
  final Directory fotoDir = Directory('${dokumen.path}/foto');
  if (!await fotoDir.exists()) {
    await fotoDir.create(recursive: true);
  }

  final String aman = _namaAman(nama);
  final String path =
      '${fotoDir.path}/${DateTime.now().microsecondsSinceEpoch}_$aman';
  await File(path).writeAsBytes(bytes, flush: true);

  return FotoLokal(
    kunci: path,
    nama: aman,
    mime: mime,
    persisten: true,
    ukuran: bytes.length,
  );
}

Future<List<int>?> baca(String kunci) async {
  final File berkas = File(kunci);
  if (!await berkas.exists()) return null;
  return berkas.readAsBytes();
}

Future<void> hapus(String kunci) async {
  final File berkas = File(kunci);
  if (await berkas.exists()) {
    await berkas.delete();
  }
}

String _namaAman(String nama) {
  final String bersih = nama.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return bersih.isEmpty ? 'foto.jpg' : bersih;
}
