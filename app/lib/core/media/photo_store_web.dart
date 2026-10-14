import 'foto_lokal.dart';

/// Implementasi [PhotoStore] untuk web.
///
/// Web tidak punya berkas yang dapat dialamatkan path; foto disimpan di memori
/// sehingga hanya bertahan selama sesi berjalan. Keterbatasan ini didokumentasi
/// (`docs/DESIGN-FEATURES-V3.md` §5.2 — tanpa `path_provider`, draf foto tidak
/// dijamin tahan tutup).
final Map<String, List<int>> _memori = <String, List<int>>{};

int _seq = 0;

Future<FotoLokal> simpan({
  required List<int> bytes,
  required String nama,
  required String mime,
}) async {
  final String kunci =
      'mem://${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
  _memori[kunci] = List<int>.of(bytes);
  return FotoLokal(
    kunci: kunci,
    nama: nama,
    mime: mime,
    persisten: false,
    ukuran: bytes.length,
  );
}

Future<List<int>?> baca(String kunci) async => _memori[kunci];

Future<void> hapus(String kunci) async {
  _memori.remove(kunci);
}
