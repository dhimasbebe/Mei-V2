/// Model pengingat (jatuh tempo / terlambat / menunggu verifikasi) —
/// **Dart murni** (tanpa `package:flutter`, tanpa `intl`).
///
/// Bentuk JSON mengikuti `GET /api/v1/pengingat` (lihat
/// `docs/DESIGN-FEATURES-V3.md` §3.2 & fixture `app/test/fixtures/pengingat.json`).
library;

/// Ringkasan hitungan pengingat.
class PengingatRingkasan {
  const PengingatRingkasan({
    this.jatuhTempo = 0,
    this.terlambat = 0,
    this.menungguVerifikasi = 0,
  });

  final int jatuhTempo;
  final int terlambat;
  final int menungguVerifikasi;

  /// Total seluruh item yang diperhitungkan dalam ringkasan.
  int get total => jatuhTempo + terlambat + menungguVerifikasi;

  /// `true` bila tidak ada pengingat.
  bool get kosong => total == 0;

  factory PengingatRingkasan.fromJson(Map<String, dynamic> json) {
    return PengingatRingkasan(
      jatuhTempo: int.tryParse('${json['jatuh_tempo'] ?? 0}') ?? 0,
      terlambat: int.tryParse('${json['terlambat'] ?? 0}') ?? 0,
      menungguVerifikasi:
          int.tryParse('${json['menunggu_verifikasi'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'jatuh_tempo': jatuhTempo,
        'terlambat': terlambat,
        'menunggu_verifikasi': menungguVerifikasi,
      };
}

/// Satu baris item pengingat.
class PengingatItem {
  const PengingatItem({
    required this.tipe,
    required this.barcodeAlat,
    this.namaKategori,
    this.namaLokasi,
    this.jatuhTempo,
    this.terlambatHari = 0,
  });

  /// `'jatuh_tempo'` | `'terlambat'` | `'menunggu_verifikasi'`.
  final String tipe;
  final String barcodeAlat;
  final String? namaKategori;
  final String? namaLokasi;
  final DateTime? jatuhTempo;
  final int terlambatHari;

  bool get terlambat => tipe == 'terlambat';
  bool get jatuhTempoSaja => tipe == 'jatuh_tempo';

  factory PengingatItem.fromJson(Map<String, dynamic> json) {
    final Object? jt = json['jatuh_tempo'];
    return PengingatItem(
      tipe: '${json['tipe'] ?? ''}',
      barcodeAlat: '${json['barcode_alat'] ?? ''}',
      namaKategori: json['nama_kategori'] as String?,
      namaLokasi: json['nama_lokasi'] as String?,
      jatuhTempo: jt == null ? null : DateTime.tryParse('$jt'),
      terlambatHari: int.tryParse('${json['terlambat_hari'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tipe': tipe,
        'barcode_alat': barcodeAlat,
        'nama_kategori': namaKategori,
        'nama_lokasi': namaLokasi,
        'jatuh_tempo': jatuhTempo?.toIso8601String(),
        'terlambat_hari': terlambatHari,
      };
}

/// Payload `GET /api/v1/pengingat`.
class PengingatPayload {
  const PengingatPayload({
    this.ringkasan = const PengingatRingkasan(),
    this.daftar = const <PengingatItem>[],
  });

  final PengingatRingkasan ringkasan;
  final List<PengingatItem> daftar;

  /// Jumlah item pada [daftar].
  int get totalDaftar => daftar.length;

  /// `true` bila tidak ada pengingat sama sekali.
  bool get kosong => ringkasan.kosong && daftar.isEmpty;

  factory PengingatPayload.fromJson(Map<String, dynamic> json) {
    final Object? ringkasanRaw = json['ringkasan'];
    final Object? daftarRaw = json['daftar'];
    return PengingatPayload(
      ringkasan: ringkasanRaw is Map<String, dynamic>
          ? PengingatRingkasan.fromJson(ringkasanRaw)
          : const PengingatRingkasan(),
      daftar: daftarRaw is List
          ? daftarRaw
              .whereType<Map<String, dynamic>>()
              .map(PengingatItem.fromJson)
              .toList(growable: false)
          : const <PengingatItem>[],
    );
  }
}
