import 'foto_lokal.dart';

/// Implementasi cadangan [PhotoStore] (dipakai bila tidak ada `dart:io`
/// maupun `dart:html`). Sengaja melempar agar tidak ada foto yang hilang
/// diam-diam.
Future<FotoLokal> simpan({
  required List<int> bytes,
  required String nama,
  required String mime,
}) async {
  throw UnsupportedError('PhotoStore tidak tersedia di platform ini.');
}

Future<List<int>?> baca(String kunci) async => null;

Future<void> hapus(String kunci) async {}
