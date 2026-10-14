/// Model "Tugas Hari Ini" untuk beranda Teknisi — `GET /v1/tugas-hari-ini`.
///
/// Kontrak JSON mengikuti `docs/DESIGN-ROLE-UI-V2.md` §6.5:
/// ```json
/// { "code": 200, "message": "OK", "data": {
///   "ringkasan": { "total": 12, "overdue": 4, "jatuh_tempo_hari_ini": 3 },
///   "daftar": [
///     { "barcode_alat": "AC-001", "merk_alat": "Daikin 2PK",
///       "nama_kategori": "AC", "nama_lokasi": "Ruang Server", "lantai": 2,
///       "terlambat_hari": 6, "status": "overdue",
///       "terakhir_maintenance": "2026-06-10 08:12:00" } ] } }
/// ```
library;

/// Ringkasan jumlah tugas (kartu mikro beranda Teknisi).
class TugasRingkasan {
  const TugasRingkasan({
    this.total = 0,
    this.overdue = 0,
    this.jatuhTempoHariIni = 0,
  });

  final int total;

  /// Jumlah alat yang sudah melewati siklus pemeliharaan.
  final int overdue;

  /// Jumlah alat yang jatuh tempo tepat pada hari ini.
  final int jatuhTempoHariIni;

  /// Tidak ada tugas sama sekali → layar menampilkan EmptyState.
  bool get kosong => total == 0;

  /// Jumlah tugas yang masih dapat dikerjakan tepat waktu.
  int get tepatWaktu => (total - overdue).clamp(0, total);

  factory TugasRingkasan.fromJson(Map<String, dynamic> json) {
    int i(String k) => int.tryParse('${json[k] ?? 0}') ?? 0;
    return TugasRingkasan(
      total: i('total'),
      overdue: i('overdue'),
      jatuhTempoHariIni: int.tryParse(
              '${json['jatuh_tempo_hari_ini'] ?? json['jatuhTempoHariIni'] ?? 0}') ??
          0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'total': total,
        'overdue': overdue,
        'jatuh_tempo_hari_ini': jatuhTempoHariIni,
      };
}

/// Satu baris tugas: satu alat yang perlu / terlambat dipelihara.
class TugasItem {
  const TugasItem({
    required this.barcodeAlat,
    required this.merkAlat,
    required this.namaKategori,
    required this.namaLokasi,
    this.lantai,
    this.terlambatHari = 0,
    this.status = '',
    this.terakhirMaintenance,
  });

  final String barcodeAlat;
  final String merkAlat;
  final String namaKategori;
  final String namaLokasi;
  final int? lantai;

  /// Jumlah hari keterlambatan (0 = tidak terlambat).
  final int terlambatHari;

  /// `'overdue'` | `'jatuh_tempo'` | `'terjadwal'`.
  final String status;

  /// Waktu pemeliharaan terakhir; `null` bila belum pernah dipelihara.
  final DateTime? terakhirMaintenance;

  bool get isOverdue => status.toLowerCase() == 'overdue';
  bool get jatuhTempoHariIni => status.toLowerCase() == 'jatuh_tempo';
  bool get belumPernahDipelihara => terakhirMaintenance == null;

  /// Label lokasi gaya aplikasi lama: "Aula Besar Lantai 7".
  String get detailLokasi {
    final String nama = namaLokasi.trim();
    if (lantai == null) return nama;
    return '$nama Lantai $lantai';
  }

  /// Teks keterlambatan siap tampil (badge StatusBadge).
  String get teksKeterlambatan {
    if (terlambatHari <= 0) return 'Tepat waktu';
    return 'Terlambat $terlambatHari hari';
  }

  factory TugasItem.fromJson(Map<String, dynamic> json) {
    final Object? waktu =
        json['terakhir_maintenance'] ?? json['terakhirMaintenance'];
    return TugasItem(
      barcodeAlat: (json['barcode_alat'] ?? json['barcodeAlat'] ?? '') as String,
      merkAlat: (json['merk_alat'] ?? json['merkAlat'] ?? '') as String,
      namaKategori: (json['nama_kategori'] ?? json['namaKategori'] ?? '') as String,
      namaLokasi: (json['nama_lokasi'] ?? json['namaLokasi'] ?? '') as String,
      lantai: json['lantai'] == null ? null : int.tryParse('${json['lantai']}'),
      terlambatHari: int.tryParse('${json['terlambat_hari'] ?? json['terlambatHari'] ?? 0}') ?? 0,
      status: (json['status'] ?? '') as String,
      terakhirMaintenance: waktu == null ? null : DateTime.tryParse('$waktu'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode_alat': barcodeAlat,
        'merk_alat': merkAlat,
        'nama_kategori': namaKategori,
        'nama_lokasi': namaLokasi,
        'lantai': lantai,
        'terlambat_hari': terlambatHari,
        'status': status,
        'terakhir_maintenance': terakhirMaintenance?.toIso8601String(),
      };
}

/// Pembungkus respons `GET /tugas-hari-ini` (ringkasan + daftar).
class TugasHariIni {
  const TugasHariIni({
    this.ringkasan = const TugasRingkasan(),
    this.daftar = const <TugasItem>[],
  });

  final TugasRingkasan ringkasan;
  final List<TugasItem> daftar;

  bool get kosong => daftar.isEmpty;

  /// Jumlah alat yang belum pernah dipelihara pada daftar ini.
  int get belumPernahDipelihara =>
      daftar.where((TugasItem t) => t.belumPernahDipelihara).length;

  factory TugasHariIni.fromJson(Map<String, dynamic> json) {
    final Object? ringkas = json['ringkasan'];
    final Object? daftar = json['daftar'] ?? json['data'];
    return TugasHariIni(
      ringkasan: ringkas is Map<String, dynamic>
          ? TugasRingkasan.fromJson(ringkas)
          : const TugasRingkasan(),
      daftar: daftar is List
          ? daftar
              .whereType<Map<String, dynamic>>()
              .map(TugasItem.fromJson)
              .toList(growable: false)
          : const <TugasItem>[],
    );
  }
}
