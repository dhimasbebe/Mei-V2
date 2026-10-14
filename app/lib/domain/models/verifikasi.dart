/// Model antrean verifikasi maintenance (Supervisor/Admin).
///
/// Kontrak JSON mengikuti `docs/DESIGN-ROLE-UI-V2.md` §6.5:
/// - `GET /v1/maintenance/pending`   → daftar [VerifikasiItem] (berpaginasi)
/// - `GET /v1/maintenance/pending/count` → [PendingCount]
/// - `POST /v1/maintenance/{id}/verify`  → payload [VerifikasiPayload]
library;

import 'maintenance.dart';

/// Satu item pada antrean "menunggu verifikasi".
///
/// Bentuknya sengaja mandiri (tidak memakai [Maintenance]) supaya layar
/// Verifikasi hanya bergantung pada kolom yang benar-benar ditampilkan.
class VerifikasiItem {
  const VerifikasiItem({
    required this.idMaintenance,
    required this.waktuMaintenance,
    required this.barcodeAlat,
    this.username,
    this.namaUsers,
    this.namaKategori,
    this.namaLokasi,
    this.lantai,
    this.kondisiKeseluruhan,
    this.statusVerifikasi,
    this.catatan,
    this.merkAlat,
    this.detail = const <DetailMaintenance>[],
    this.jumlahFoto = 0,
  });

  final int idMaintenance;
  final DateTime waktuMaintenance;
  final String barcodeAlat;
  final String? username;
  final String? namaUsers;
  final String? namaKategori;
  final String? namaLokasi;
  final int? lantai;

  /// `'baik'` | `'kurang_baik'` | `'rusak'`.
  final String? kondisiKeseluruhan;

  /// `'menunggu'` | `'disetujui'` | `'ditolak'`.
  final String? statusVerifikasi;
  final String? catatan;
  final String? merkAlat;
  final List<DetailMaintenance> detail;

  /// Jumlah foto lampiran (`GET /maintenance/pending` → `jumlah_foto`,
  /// Fitur Tahap 3). Dipakai menampilkan indikator pada kartu verifikasi.
  final int jumlahFoto;

  /// `true` bila laporan memiliki minimal satu foto.
  bool get punyaFoto => jumlahFoto > 0;

  bool get menunggu => (statusVerifikasi ?? 'menunggu') == 'menunggu';
  bool get disetujui => statusVerifikasi == 'disetujui';
  bool get ditolak => statusVerifikasi == 'ditolak';

  /// Teknisi penanggung jawab (fallback ke username bila nama tidak dikirim).
  String get teknisi => namaUsers ?? username ?? '-';

  /// Detail lokasi gaya aplikasi lama: "Aula Besar Lantai 7".
  String get detailLokasi {
    final String nama = (namaLokasi ?? '-').trim();
    if (lantai == null) return nama;
    return '$nama Lantai $lantai';
  }

  /// Ringkasan detail checklist untuk ditampilkan pada kartu verifikasi.
  String get detailRingkas =>
      detail.map((DetailMaintenance d) => d.teksLaporan).join('\n');

  factory VerifikasiItem.fromJson(Map<String, dynamic> json) {
    final Object? waktu = json['waktu_maintenance'] ?? json['waktuMaintenance'];
    final Object? detailRaw = json['detail'];
    return VerifikasiItem(
      idMaintenance:
          int.tryParse('${json['id_maintenance'] ?? json['idMaintenance'] ?? 0}') ?? 0,
      waktuMaintenance: DateTime.tryParse('$waktu') ?? DateTime.now(),
      barcodeAlat: (json['barcode_alat'] ?? json['barcodeAlat'] ?? '') as String,
      username: json['username'] as String?,
      namaUsers: (json['nama_users'] ?? json['namaUsers']) as String?,
      namaKategori: (json['nama_kategori'] ?? json['namaKategori']) as String?,
      namaLokasi: (json['nama_lokasi'] ?? json['namaLokasi']) as String?,
      lantai: json['lantai'] == null ? null : int.tryParse('${json['lantai']}'),
      kondisiKeseluruhan: (json['kondisi_keseluruhan'] ?? json['kondisiKeseluruhan']) as String?,
      statusVerifikasi: (json['status_verifikasi'] ?? json['statusVerifikasi']) as String?,
      catatan: json['catatan'] as String?,
      merkAlat: (json['merk_alat'] ?? json['merkAlat']) as String?,
      detail: detailRaw is List
          ? detailRaw
              .whereType<Map<String, dynamic>>()
              .map(DetailMaintenance.fromJson)
              .toList(growable: false)
          : const <DetailMaintenance>[],
      jumlahFoto:
          int.tryParse('${json['jumlah_foto'] ?? json['jumlahFoto'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_maintenance': idMaintenance,
        'waktu_maintenance': waktuMaintenance.toIso8601String(),
        'barcode_alat': barcodeAlat,
        'username': username,
        'nama_users': namaUsers,
        'nama_kategori': namaKategori,
        'nama_lokasi': namaLokasi,
        'lantai': lantai,
        'kondisi_keseluruhan': kondisiKeseluruhan,
        'status_verifikasi': statusVerifikasi,
        'catatan': catatan,
        'merk_alat': merkAlat,
        'detail': detail.map((DetailMaintenance d) => d.toJson()).toList(),
      };
}

/// Payload aksi setujui / tolak — `POST /v1/maintenance/{id}/verify`.
///
/// Body: `{"status":"disetujui","komentar":"Data lengkap."}`
class VerifikasiPayload {
  const VerifikasiPayload({required this.status, this.komentar});

  /// `'disetujui'` | `'ditolak'` (server menolak `'menunggu'`).
  final String status;
  final String? komentar;

  static const String disetujui = 'disetujui';
  static const String ditolak = 'ditolak';

  bool get valid => status == disetujui || status == ditolak;

  /// Aksi setujui dengan komentar opsional.
  factory VerifikasiPayload.setujui({String? komentar}) =>
      VerifikasiPayload(status: disetujui, komentar: komentar);

  /// Aksi tolak dengan alasan opsional.
  factory VerifikasiPayload.tolak({String? komentar}) =>
      VerifikasiPayload(status: ditolak, komentar: komentar);

  factory VerifikasiPayload.fromJson(Map<String, dynamic> json) => VerifikasiPayload(
        status: (json['status'] ?? json['status_verifikasi'] ?? '') as String,
        komentar: (json['komentar'] ?? json['komentar_verifikasi']) as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status,
        'komentar': komentar,
      };
}

/// Jumlah antrean menunggu verifikasi — `GET /v1/maintenance/pending/count`.
///
/// Body: `{"code":200,"data":{"menunggu":47}}`
class PendingCount {
  const PendingCount({this.menunggu = 0});

  final int menunggu;

  bool get kosong => menunggu <= 0;

  /// Teks badge jumlah (dipakai pada tab Verifikasi).
  String get label => menunggu > 99 ? '99+' : '$menunggu';

  factory PendingCount.fromJson(Map<String, dynamic> json) => PendingCount(
        menunggu: int.tryParse('${json['menunggu'] ?? json['count'] ?? 0}') ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'menunggu': menunggu};
}
