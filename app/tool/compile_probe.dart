/// Gerbang kompilasi VARIASI PLATFORM — bukan aplikasi, hanya probe.
///
/// Masalah yang diselesaikan: `gen_kernel_aot --target flutter` dikompilasi
/// untuk VM, sehingga `dart.library.io` **true** dan `dart.library.html`
/// **false**. Akibatnya file `*_web.dart` pada import kondisional
/// (`file_delivery.dart`, `photo_store.dart`) TIDAK PERNAH ikut terkompilasi
/// oleh gerbang `lib/main.dart` maupun `lib/main_web.dart`, sehingga galat tipe
/// di dalamnya lolos sampai runtime web.
///
/// Contoh nyata: `XFile.fromData` menuntut `Uint8List`, sedangkan lapisan API
/// mengembalikan `List<int>`. Gerbang utama hijau, probe ini menangkapnya.
///
/// Cara jalan (dari `app/`):
/// ```
/// "C:/src/flutter/bin/cache/dart-sdk/bin/dartaotruntime.exe" \
///   "C:/src/flutter/bin/cache/dart-sdk/bin/snapshots/gen_kernel_aot.dart.snapshot" \
///   --platform "C:/src/flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk/platform_strong.dill" \
///   --target flutter --packages ".dart_tool/package_config.json" \
///   --no-link-platform -o /tmp/probe.dill tool/compile_probe.dart
/// ```
/// EXIT=0 wajib. Tambahkan impor baru di sini setiap kali membuat file
/// `*_web.dart` / `*_stub.dart` baru.
library;

import 'dart:typed_data';

import 'package:mei_v/core/files/file_delivery_stub.dart' as delivery_stub;
import 'package:mei_v/core/files/file_delivery_web.dart' as delivery_web;
import 'package:mei_v/core/media/photo_store_stub.dart' as photo_stub;
import 'package:mei_v/core/media/photo_store_web.dart' as photo_web;

Future<int> main() async {
  final Uint8List dummy = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]);

  // Variasi web — file_delivery.
  final bool webDidukung = delivery_web.didukung;
  await delivery_web.bagikanBerkas(
    bytes: dummy,
    nama: 'probe.pdf',
    mime: 'application/pdf',
    judul: 'probe',
  );
  await delivery_web.bagikanTeks(teks: 'probe', judul: 'probe');

  // Variasi stub — file_delivery.
  final bool stubDidukung = delivery_stub.didukung;
  await delivery_stub.bagikanBerkas(
    bytes: dummy,
    nama: 'probe.pdf',
    mime: 'application/pdf',
  );
  await delivery_stub.bagikanTeks(teks: 'probe');

  // Variasi web & stub — photo_store (jalur yang sama, sudah ada sebelumnya).
  await photo_web.simpan(bytes: dummy, nama: 'probe.jpg', mime: 'image/jpeg');
  await photo_web.hapus('mem://probe');
  await photo_stub.hapus('probe');

  // Nilai dipakai sebagai kode keluar agar pemanggilan di atas tidak dibuang
  // kompilator sebagai kode mati — sekaligus bukti stub melaporkan false.
  return (webDidukung ? 1 : 0) + (stubDidukung ? 2 : 0);
}
