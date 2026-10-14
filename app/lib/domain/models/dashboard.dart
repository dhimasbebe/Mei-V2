/// Model untuk dashboard monitoring (fitur baru Mei-V2).
/// Semua dihitung di server (Laravel) agar ringan di klien.
library;

/// Hasil paginasi generik dari `GET /maintenance` (Laravel pagination style).
class PagedResult<T> {
  const PagedResult({
    required this.data,
    this.total = 0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
  });

  final List<T> data;
  final int total;
  final int currentPage;
  final int lastPage;
  final int perPage;

  bool get hasNext => currentPage < lastPage;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemBuilder,
  ) {
    final Object? raw = json['data'] ?? json['items'];
    return PagedResult<T>(
      data: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(itemBuilder).toList(growable: false)
          : const <Never>[],
      total: int.tryParse('${json['total'] ?? 0}') ?? 0,
      currentPage: int.tryParse('${json['current_page'] ?? json['page'] ?? 1}') ?? 1,
      lastPage: int.tryParse('${json['last_page'] ?? json['totalPages'] ?? 1}') ?? 1,
      perPage: int.tryParse('${json['per_page'] ?? json['perPage'] ?? 20}') ?? 20,
    );
  }
}

/// Ringkasan KPI (GET /dashboard/kpi).
class DashboardKpi {
  const DashboardKpi({
    required this.totalAlat,
    required this.totalKategori,
    required this.pemeliharaanBulanIni,
    required this.pemeliharaanTepatWaktu,
    required this.alatOverdue,
    this.teknisiAktif = 0,
    this.persenTepatWaktu = 0,
    this.rataRataIntervalHari,
  });

  final int totalAlat;
  final int totalKategori;
  final int pemeliharaanBulanIni;

  /// Jumlah alat yang dipelihara dalam siklus (tidak overdue).
  final int pemeliharaanTepatWaktu;
  final int alatOverdue;
  final int teknisiAktif;
  final double persenTepatWaktu;
  final double? rataRataIntervalHari;

  /// Tingkat kepatuhan (%) — dibulatkan untuk ditampilkan pada kartu KPI.
  int get kepatuhanPersen {
    if (totalAlat <= 0) return 0;
    return ((pemeliharaanTepatWaktu / totalAlat) * 100).round();
  }

  factory DashboardKpi.fromJson(Map<String, dynamic> json) {
    int i(String k, [String? alt]) {
      final dynamic v = json[k] ?? (alt != null ? json[alt] : null);
      return int.tryParse('$v') ?? 0;
    }
    double d(String k, [String? alt]) {
      final dynamic v = json[k] ?? (alt != null ? json[alt] : null);
      return double.tryParse('$v') ?? 0;
    }
    return DashboardKpi(
      totalAlat: i('total_alat', 'totalAlat'),
      totalKategori: i('total_kategori', 'totalKategori'),
      pemeliharaanBulanIni: i('pemeliharaan_bulan_ini', 'maintenanceBulanIni'),
      pemeliharaanTepatWaktu: i('pemeliharaan_tepat_waktu', 'pemeliharaanTepatWaktu'),
      alatOverdue: i('alat_overdue', 'overdueCount'),
      teknisiAktif: i('teknisi_aktif', 'teknisiAktif'),
      persenTepatWaktu: d('persen_tepat_waktu', 'persenTepatWaktu'),
      rataRataIntervalHari: json['rata_rata_interval_hari'] == null && json['rataRataIntervalHari'] == null
          ? null
          : d('rata_rata_interval_hari', 'rataRataIntervalHari'),
    );
  }
}

/// Titik data tren (GET /dashboard/trend).
class TrendPoint {
  const TrendPoint({required this.label, required this.jumlah});

  final String label; // mis. "2026-07"
  final int jumlah;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        label: '${json['label'] ?? json['periode'] ?? ''}',
        jumlah: int.tryParse('${json['jumlah'] ?? 0}') ?? 0,
      );
}

/// Item distribusi (GET /dashboard/distribution) — per kategori atau kondisi.
class DistributionItem {
  const DistributionItem({
    required this.label,
    required this.jumlah,
    this.iconAsset,
  });

  final String label;
  final int jumlah;
  final String? iconAsset;

  factory DistributionItem.fromJson(Map<String, dynamic> json) => DistributionItem(
        label: '${json['label'] ?? json['nama'] ?? ''}',
        jumlah: int.tryParse('${json['jumlah'] ?? 0}') ?? 0,
        iconAsset: json['icon_asset'] as String?,
      );
}

/// Item daftar alat terlambat (GET /dashboard/overdue).
class OverdueItem {
  const OverdueItem({
    required this.barcodeAlat,
    required this.merkAlat,
    required this.namaKategori,
    required this.namaLokasi,
    required this.terlambatHari,
    this.namaUsers,
  });

  final String barcodeAlat;
  final String merkAlat;
  final String namaKategori;
  final String namaLokasi;
  final int terlambatHari;
  final String? namaUsers;

  factory OverdueItem.fromJson(Map<String, dynamic> json) => OverdueItem(
        barcodeAlat: '${json['barcode_alat'] ?? json['barcodeAlat'] ?? ''}',
        merkAlat: '${json['merk_alat'] ?? json['merkAlat'] ?? ''}',
        namaKategori: '${json['nama_kategori'] ?? json['namaKategori'] ?? ''}',
        namaLokasi: '${json['nama_lokasi'] ?? json['namaLokasi'] ?? ''}',
        terlambatHari: int.tryParse('${json['terlambat_hari'] ?? json['hariTerlambat'] ?? 0}') ?? 0,
        namaUsers: json['nama_users'] ?? json['namaUsers'] as String?,
      );
}

/// Item sorotan parameter abnormal (GET /dashboard/parameter-abnormal).
///
/// Kontrak §6.5:
/// ```json
/// { "barcode_alat": "PL-002", "nama_spesifikasi": "Tegangan R-N",
///   "nilai": "198", "satuan": "V", "ambang": ">=215",
///   "waktu": "2026-07-14 11:00:00" }
/// ```
class ParameterAbnormal {
  const ParameterAbnormal({
    required this.barcodeAlat,
    required this.namaSpesifikasi,
    this.nilai,
    this.satuan,
    this.ambang,
    this.waktu,
  });

  final String barcodeAlat;
  final String namaSpesifikasi;

  /// Nilai terukur (dikirim sebagai string oleh server).
  final String? nilai;
  final String? satuan;

  /// Ambang batas, mis. ">=215".
  final String? ambang;
  final DateTime? waktu;

  /// "198 V" (tanpa satuan bila kosong).
  String get nilaiTampil {
    final String n = (nilai ?? '-').trim();
    final String s = (satuan ?? '').trim();
    return s.isEmpty ? n : '$n $s';
  }

  /// "198 V (>=215)" untuk ditampilkan pada kartu sorotan.
  String get nilaiDenganAmbang {
    final String a = (ambang ?? '').trim();
    return a.isEmpty ? nilaiTampil : '$nilaiTampil ($a)';
  }

  factory ParameterAbnormal.fromJson(Map<String, dynamic> json) => ParameterAbnormal(
        barcodeAlat: '${json['barcode_alat'] ?? json['barcodeAlat'] ?? ''}',
        namaSpesifikasi:
            '${json['nama_spesifikasi'] ?? json['namaSpesifikasi'] ?? ''}',
        nilai: json['nilai'] == null ? null : '${json['nilai']}',
        satuan: json['satuan'] as String?,
        ambang: json['ambang'] as String?,
        waktu: json['waktu'] == null ? null : DateTime.tryParse('${json['waktu']}'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode_alat': barcodeAlat,
        'nama_spesifikasi': namaSpesifikasi,
        'nilai': nilai,
        'satuan': satuan,
        'ambang': ambang,
        'waktu': waktu?.toIso8601String(),
      };
}
