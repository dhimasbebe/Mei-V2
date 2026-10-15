/// Antrean patroli scan berkelanjutan (WS I, Fitur Tahap 3) — **Dart murni**.
///
/// Modul ini TIDAK boleh mengimpor `package:flutter`; seluruhnya diuji lewat
/// `dart.exe` (`tools/modelcheck`). Persistensi nyata (`shared_preferences`)
/// berada di lapisan provider, bukan di sini. Lihat
/// `docs/DESIGN-FEATURES-V3.md` §C.1.1 dan `docs/PRD-FEATURES-V3.md` §I.
library;

import 'dart:convert';

/// Status validasi satu item patroli.
///
/// Barcode yang belum dapat divalidasi (offline / 404) tetap boleh masuk
/// antrean dengan status [belumValidasi] — validasi penuh terjadi saat
/// laporan dikirim (PRD I.2, AC-I4).
enum PatrolStatus { tervalidasi, belumValidasi }

/// Satu barcode dalam antrean patroli.
class PatrolItem {
  const PatrolItem({
    required this.barcode,
    required this.ditambahkanPada,
    this.status = PatrolStatus.belumValidasi,
  });

  final String barcode;

  /// Waktu scan pertama barcode ini (dipakai juga sebagai urutan FIFO).
  final DateTime ditambahkanPada;

  final PatrolStatus status;

  /// Item baru dengan status berbeda (objek lama tidak diubah).
  PatrolItem copyWith({PatrolStatus? status}) => PatrolItem(
        barcode: barcode,
        ditambahkanPada: ditambahkanPada,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode': barcode,
        'ditambahkan_pada': ditambahkanPada.toIso8601String(),
        'status': status.name,
      };

  factory PatrolItem.fromJson(Map<String, dynamic> json) => PatrolItem(
        barcode: '${json['barcode'] ?? ''}',
        ditambahkanPada:
            DateTime.tryParse('${json['ditambahkan_pada'] ?? ''}') ?? DateTime.now(),
        status: _statusDari('${json['status'] ?? ''}'),
      );

  static PatrolStatus _statusDari(String raw) =>
      raw == PatrolStatus.tervalidasi.name
          ? PatrolStatus.tervalidasi
          : PatrolStatus.belumValidasi;
}

/// Antrean patroli satu sesi kerja — FIFO, dedupe per barcode, dapat
/// diserialisasi. Pola penyimpanan SAMA dengan `DraftQueue`: satu string JSON
/// di `shared_preferences` (key [storageKey]).
class PatrolQueue {
  PatrolQueue([List<PatrolItem> initial = const <PatrolItem>[]])
      : _items = List<PatrolItem>.of(initial);

  /// Kunci penyimpanan di `shared_preferences` (satu string JSON).
  static const String storageKey = 'meiv.patrol_queue.v1';

  final List<PatrolItem> _items;

  /// Salinan antrean dalam urutan FIFO (AC-I2).
  List<PatrolItem> get items => List<PatrolItem>.unmodifiable(_items);

  int get count => _items.length;

  /// Jumlah item yang masih berstatus [PatrolStatus.belumValidasi].
  int get jumlahBelumValidasi => _items
      .where((PatrolItem i) => i.status == PatrolStatus.belumValidasi)
      .length;

  bool get kosong => _items.isEmpty;

  /// Tambah barcode ke UJUNG antrean.
  ///
  /// Mengembalikan `false` bila barcode sudah ada (TIDAK menduplikasi) dan
  /// `true` bila benar-benar ditambahkan — AC-I1. Pencocokan barcode
  /// case-insensitive dan di-trim agar "ac-001" tidak masuk dua kali.
  bool add(String barcode, {DateTime? pada}) {
    final String bersih = barcode.trim();
    if (bersih.isEmpty) return false;
    if (_indexOf(bersih) >= 0) return false;

    _items.add(PatrolItem(
      barcode: bersih,
      ditambahkanPada: pada ?? DateTime.now(),
    ));
    return true;
  }

  /// Hapus barcode; urutan item lain TETAP — AC-I2.
  void remove(String barcode) {
    final int index = _indexOf(barcode);
    if (index >= 0) _items.removeAt(index);
  }

  void clear() => _items.clear();

  /// Tandai barcode belum tervalidasi (mis. 404 dari `GET /alat/{barcode}`).
  /// Item TIDAK dihapus — AC-I4. `false` bila barcode tidak ada di antrean.
  bool tandaiBelumValidasi(String barcode) =>
      _ubahStatus(barcode, PatrolStatus.belumValidasi);

  /// Tandai barcode tervalidasi (berhasil `GET /alat/{barcode}`).
  bool tandaiTervalidasi(String barcode) =>
      _ubahStatus(barcode, PatrolStatus.tervalidasi);

  /// Serialisasi seluruh antrean menjadi satu string JSON (AC-I3).
  String serialize() => jsonEncode(<String, dynamic>{
        'version': 1,
        'items': _items.map((PatrolItem i) => i.toJson()).toList(),
      });

  /// Bangun ulang antrean dari string JSON. String `null`/kosong atau rusak
  /// menghasilkan antrean kosong (tidak melempar exception) — round-trip
  /// dengan [serialize] menghasilkan antrean identik (AC-I3).
  factory PatrolQueue.deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return PatrolQueue();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        final Object? items = decoded['items'];
        if (items is List) {
          return PatrolQueue(items
              .whereType<Map<String, dynamic>>()
              .map(PatrolItem.fromJson)
              .toList(growable: false));
        }
      }
      // Bentuk lama: array langsung.
      if (decoded is List) {
        return PatrolQueue(decoded
            .whereType<Map<String, dynamic>>()
            .map(PatrolItem.fromJson)
            .toList(growable: false));
      }
    } catch (_) {
      // Abaikan: kembalikan antrean kosong.
    }
    return PatrolQueue();
  }

  bool _ubahStatus(String barcode, PatrolStatus status) {
    final int index = _indexOf(barcode);
    if (index < 0) return false;

    if (_items[index].status != status) {
      _items[index] = _items[index].copyWith(status: status);
    }
    return true;
  }

  /// Indeks item dengan barcode (case-insensitive, trim); -1 bila tidak ada.
  int _indexOf(String barcode) {
    final String kunci = barcode.trim().toLowerCase();
    return _items.indexWhere((PatrolItem i) => i.barcode.toLowerCase() == kunci);
  }
}
