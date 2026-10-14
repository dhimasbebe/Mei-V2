import 'package:intl/intl.dart';

/// Satu baris hasil pemeliharaan per item checklist. Padanan `detail_maintenance`.
class DetailMaintenance {
  const DetailMaintenance({
    required this.idSpesifikasi,
    required this.status,
    this.namaSpesifikasi,
    this.satuan,
  });

  final int idSpesifikasi;
  final String status;
  final String? namaSpesifikasi;
  final String? satuan;

  /// Teks gaya laporan aplikasi lama: "Voltage R-S : 380".
  String get teksLaporan {
    final String nama = (namaSpesifikasi ?? 'Item').trim();
    final String s = (satuan ?? '').trim();
    return s.isEmpty ? '$nama : $status' : '$nama : $status $s';
  }

  factory DetailMaintenance.fromJson(Map<String, dynamic> json) {
    return DetailMaintenance(
      idSpesifikasi: int.tryParse('${json['id_spesifikasi'] ?? 0}') ?? 0,
      status: '${json['status'] ?? ''}',
      namaSpesifikasi: json['nama_spesifikasi'] as String?,
      satuan: json['satuan'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_spesifikasi': idSpesifikasi,
        'status': status,
      };
}

/// Satu sesi pemeliharaan (header + detail). Padanan `maintenance`
/// digabung dengan `detail_maintenance`.
class Maintenance {
  const Maintenance({
    required this.idMaintenance,
    required this.waktuMaintenance,
    required this.barcodeAlat,
    required this.username,
    required this.idLokasi,
    this.idKategori,
    this.catatan,
    this.kondisiKeseluruhan,
    this.detail = const <DetailMaintenance>[],
    this.namaKategori,
    this.merkAlat,
    this.namaUsers,
    this.namaLokasi,
    this.lantai,
    this.statusVerifikasi,
    this.diverifikasiOleh,
    this.waktuVerifikasi,
    this.komentarVerifikasi,
  });

  final int idMaintenance;
  final DateTime waktuMaintenance;
  final String barcodeAlat;
  final String username;
  final int idLokasi;
  final int? idKategori;
  final String? catatan;

  /// 'baik' | 'kurang_baik' | 'rusak' (kolom baru untuk KPI dashboard).
  final String? kondisiKeseluruhan;
  final List<DetailMaintenance> detail;

  // Kolom baca-saja hasil join (view_maintenance).
  final String? namaKategori;
  final String? merkAlat;
  final String? namaUsers;
  final String? namaLokasi;
  final int? lantai;

  /// Nama teknisi untuk ditampilkan pada tabel/kartu.
  ///
  /// `username` (NIP) hanya dipakai sebagai cadangan bila `nama_users` tidak
  /// dikirim server. Nilainya disalin lebih dulu ke variabel bertipe `String?`
  /// supaya maksudnya eksplisit bagi pembaca dan analyzer.
  String get namaTeknisi {
    final String? nama = namaUsers;
    return nama ?? username;
  }

  // Kolom verifikasi (migrasi M1). Opsional agar fixture lama tetap terparse.
  /// 'menunggu' | 'disetujui' | 'ditolak'.
  final String? statusVerifikasi;

  /// Username Supervisor/Admin yang memverifikasi.
  final String? diverifikasiOleh;
  final DateTime? waktuVerifikasi;
  final String? komentarVerifikasi;

  /// Belum diverifikasi atau masih menunggu (nilai default server).
  bool get menungguVerifikasi =>
      statusVerifikasi == null || statusVerifikasi == 'menunggu';
  bool get disetujui => statusVerifikasi == 'disetujui';
  bool get ditolak => statusVerifikasi == 'ditolak';

  /// Status verifikasi siap tampil (badge), default 'menunggu'.
  String get statusVerifikasiTampil => statusVerifikasi ?? 'menunggu';

  /// Tanggal + jam gaya aplikasi lama: "2022-07-15 13:02:47".
  String get waktuTampil =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(waktuMaintenance);

  /// Ringkasan detail untuk kolom DETAIL pada tabel riwayat supervisor.
  String get detailRingkas => detail.map((DetailMaintenance d) => d.teksLaporan).join('\n');

  factory Maintenance.fromJson(Map<String, dynamic> json) {
    final Object? waktu = json['waktu_maintenance'] ?? json['waktuMaintenance'];
    final Object? detailRaw = json['detail'];
    return Maintenance(
      idMaintenance: int.tryParse('${json['id_maintenance'] ?? json['idMaintenance'] ?? 0}') ?? 0,
      waktuMaintenance: DateTime.tryParse('$waktu') ?? DateTime.now(),
      barcodeAlat: (json['barcode_alat'] ?? json['barcodeAlat'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      idLokasi: int.tryParse('${json['id_lokasi'] ?? json['idLokasi'] ?? 0}') ?? 0,
      idKategori: json['id_kategori'] == null ? null : int.tryParse('${json['id_kategori']}'),
      catatan: json['catatan'] as String?,
      kondisiKeseluruhan: json['kondisi_keseluruhan'] as String?,
      detail: detailRaw is List
          ? detailRaw
              .whereType<Map<String, dynamic>>()
              .map(DetailMaintenance.fromJson)
              .toList(growable: false)
          : const <DetailMaintenance>[],
      namaKategori: json['nama_kategori'] as String?,
      merkAlat: json['merk_alat'] as String?,
      namaUsers: json['nama_users'] as String?,
      namaLokasi: json['nama_lokasi'] as String?,
      lantai: json['lantai'] == null ? null : int.tryParse('${json['lantai']}'),
      statusVerifikasi: (json['status_verifikasi'] ?? json['statusVerifikasi']) as String?,
      diverifikasiOleh: (json['diverifikasi_oleh'] ?? json['diverifikasiOleh']) as String?,
      waktuVerifikasi: (json['waktu_verifikasi'] ?? json['waktuVerifikasi']) == null
          ? null
          : DateTime.tryParse('${json['waktu_verifikasi'] ?? json['waktuVerifikasi']}'),
      komentarVerifikasi:
          (json['komentar_verifikasi'] ?? json['komentarVerifikasi']) as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_maintenance': idMaintenance,
        'waktu_maintenance': waktuMaintenance.toIso8601String(),
        'barcode_alat': barcodeAlat,
        'username': username,
        'id_lokasi': idLokasi,
        'id_kategori': idKategori,
        'catatan': catatan,
        'kondisi_keseluruhan': kondisiKeseluruhan,
        'detail': detail.map((DetailMaintenance d) => d.toJson()).toList(),
        'status_verifikasi': statusVerifikasi,
        'diverifikasi_oleh': diverifikasiOleh,
        'waktu_verifikasi': waktuVerifikasi?.toIso8601String(),
        'komentar_verifikasi': komentarVerifikasi,
      };
}

/// Baris tabel "Riwayat Maintenance" (WAKTU | TEKNISI | DETAIL)
/// seperti tampilan Supervisor pada aplikasi lama (Gambar 4.8).
class RiwayatItem {
  const RiwayatItem({
    required this.idMaintenance,
    required this.waktu,
    required this.teknisi,
    required this.lokasi,
    required this.detail,
    this.catatan,
  });

  final int idMaintenance;
  final DateTime waktu;
  final String teknisi;
  final String lokasi;
  final String detail;
  final String? catatan;

  String get waktuTampil => DateFormat('yyyy-MM-dd HH:mm:ss').format(waktu);

  factory RiwayatItem.fromMaintenance(Maintenance m) {
    return RiwayatItem(
      idMaintenance: m.idMaintenance,
      waktu: m.waktuMaintenance,
      teknisi: m.namaUsers ?? m.username,
      lokasi: m.namaLokasi ?? '-',
      detail: m.detailRingkas.isEmpty ? (m.catatan ?? '-') : m.detailRingkas,
      catatan: m.catatan,
    );
  }
}

/// Payload kirim form pemeliharaan ke `POST /api/v1/maintenance`.
class MaintenancePayload {
  MaintenancePayload({
    required this.barcodeAlat,
    required this.idLokasi,
    required this.detail,
    this.catatan,
    this.kondisiKeseluruhan,
    String? clientUuid,
    DateTime? waktuMaintenance,
  })  : clientUuid = clientUuid ?? _uuid(),
        waktuMaintenance = waktuMaintenance ?? DateTime.now();

  final String barcodeAlat;
  final int idLokasi;
  final List<DetailMaintenance> detail;
  final String? catatan;
  final String? kondisiKeseluruhan;
  final DateTime waktuMaintenance;

  /// Idempotency key (UUID v4) — supaya kirim ulang saat sinkron offline
  /// tidak menghasilkan data ganda. Server wajib UNIQUE pada kolom ini.
  final String clientUuid;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'client_uuid': clientUuid,
        'barcode_alat': barcodeAlat,
        'id_lokasi': idLokasi,
        'waktu_maintenance': waktuMaintenance.toIso8601String(),
        'catatan': catatan,
        'kondisi_keseluruhan': kondisiKeseluruhan,
        'detail': detail.map((DetailMaintenance d) => d.toJson()).toList(),
      };

  /// Penghitung urut untuk menjamin keunikan dalam milidetik yang sama.
  static int _seq = 0;

  /// UUID v4 sederhana tanpa dependensi tambahan.
  ///
  /// Dua hal yang mudah salah dan sudah diperbaiki di sini:
  ///
  /// 1. Semua nilai di-mask ke 32 bit. Tanpa itu, `seed << 13` melampaui
  ///    batas int64 Dart sehingga hasilnya NEGATIF, dan `toRadixString(16)`
  ///    pada bilangan negatif menyisipkan tanda '-' — UUID jadi tidak valid
  ///    (pernah menghasilkan "-344e620--344-4-34-a-34--344e62065db").
  ///
  /// 2. Penghitung `_seq` WAJIB ada. `DateTime.now()` di Windows hanya
  ///    bergranularitas ~1 milidetik, jadi tanpa penghitung semua UUID yang
  ///    dibuat dalam satu milidetik akan IDENTIK (terukur: hanya 5 nilai unik
  ///    dari 3000). Akibatnya saat antrean offline dikirim beruntun, server
  ///    menganggap kiriman ke-2 dan seterusnya sebagai duplikat lalu
  ///    MEMBUANGNYA — data hilang tepat pada kasus yang ingin dilindungi.
  static String _uuid() {
    final int seed = DateTime.now().microsecondsSinceEpoch;
    _seq = (_seq + 1) & 0xFFFFFFFF;

    // Penghitung disebar ke bit atas juga (c ^ (c << 16)); kalau hanya
    // ditambahkan apa adanya, perbedaannya cuma di bit rendah dan tidak
    // menyebar ke bit atas - UUID beruntun lalu tetap bisa bertabrakan.
    final int c = _seq & 0xFFFFFFFF;
    int state = ((seed & 0xFFFFFFFF) ^ ((seed >> 32) & 0xFFFFFFFF) ^
            c ^ ((c << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
    if (state == 0) state = 0x6D2B79F5;

    // Empat putaran xorshift32 per kata keluaran. Satu putaran TIDAK cukup:
    // selisih kecil di state hanya menyebar sebagian, sehingga 3000 UUID
    // beruntun masih menyisakan ~600 tabrakan (terukur).
    int next32() {
      for (int i = 0; i < 4; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= state >> 17;
        state ^= (state << 5) & 0xFFFFFFFF;
        state &= 0xFFFFFFFF;
      }
      return state;
    }

    // Ambil `width` digit heksadesimal dari bit terbawah.
    String h(int value, int width) {
      final int mask = (1 << (width * 4)) - 1;
      return (value & mask).toRadixString(16).padLeft(width, '0');
    }

    const String variant = '89ab';
    final String g1 = h(next32(), 8);
    final String g2 = h(next32(), 4);
    final String g3 = '4${h(next32(), 3)}'; // versi 4
    final String g4 = '${variant[(next32() >> 30) & 0x3]}${h(next32(), 3)}';
    final String g5 = h(next32(), 8) + h(next32(), 4);
    return '$g1-$g2-$g3-$g4-$g5';
  }
}
