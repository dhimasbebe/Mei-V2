/// Pembentuk draf dari laporan lama — aksi "Duplikat" (WS K, Fitur Tahap 3).
/// **Dart murni**, diuji lewat `dart.exe` (`tools/modelcheck`).
///
/// Lihat `docs/DESIGN-FEATURES-V3.md` §C.1.3 dan `docs/PRD-FEATURES-V3.md` §K.
library;

import '../../domain/models/maintenance.dart';
import '../offline/draft_queue.dart';

/// Bentuk draf BARU dari laporan terakhir (AC-K1..K3).
///
/// `buatUuid` WAJIB di-inject (bukan dipanggil langsung dari modul) supaya uji
/// `[MDL]` dapat menegaskan `clientUuid` hasil **≠** uuid asal tanpa bergantung
/// pada waktu — dan supaya modul tetap murni.
abstract class DraftTemplate {
  /// Bangun [DraftRecord] dari [report]:
  ///  - `clientUuid` SELALU baru dari [buatUuid] (duplikat = laporan baru,
  ///    bukan kirim ulang — AC-K1);
  ///  - `fotoPaths` selalu `const []` — foto TIDAK disalin, bukti harus
  ///    aktual (AC-K1);
  ///  - `waktuMaintenance` = [waktuDuplikasi] ?? `DateTime.now()`, yaitu
  ///    waktu duplikasi, bukan waktu laporan asal (AC-K2);
  ///  - `barcodeAlat`, `idLokasi`, `idKategori`, checklist (`id → status`),
  ///    `catatan`, `kondisiKeseluruhan` tersalin utuh (AC-K3).
  ///
  /// Status antrean memakai bawaan [DraftRecord] (`menungguSinkron`) sehingga
  /// draf langsung ikut antrean WS A.
  static DraftRecord fromReport(
    Maintenance report, {
    required String? Function() buatUuid,
    DateTime? waktuDuplikasi,
  }) {
    final String? uuid = buatUuid();
    if (uuid == null || uuid.trim().isEmpty) {
      throw ArgumentError('buatUuid() wajib mengembalikan client_uuid baru yang tidak kosong.');
    }

    return DraftRecord(
      clientUuid: uuid.trim(),
      barcodeAlat: report.barcodeAlat,
      idLokasi: report.idLokasi,
      idKategori: report.idKategori,
      waktuMaintenance: waktuDuplikasi ?? DateTime.now(),
      checklist: <int, String>{
        for (final DetailMaintenance d in report.detail) d.idSpesifikasi: d.status,
      },
      catatan: report.catatan,
      kondisiKeseluruhan: report.kondisiKeseluruhan,
      // Foto sengaja TIDAK disalin (AC-K1).
      fotoPaths: const <String>[],
    );
  }
}
