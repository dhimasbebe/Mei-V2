/// Alat yang dipelihara. Padanan tabel `alat` (PK: barcode_alat).
///
/// Di layar Detail Alat aplikasi lama ditampilkan: Kode Alat, Merk Alat,
/// Detail Lokasi Alat.
class Alat {
  const Alat({
    required this.barcodeAlat,
    required this.merkAlat,
    required this.idKategori,
    this.namaKategori,
    this.deskripsiKategori,
    this.idLokasi,
    this.namaLokasi,
    this.lantai,
    this.terakhirMaintenance,
    this.siklusHari = 30,
    this.penanggungJawab,
    this.namaPenanggungJawab,
    this.ditugaskanPada,
  });

  final String barcodeAlat;
  final String merkAlat;
  final int idKategori;
  final String? namaKategori;
  final String? deskripsiKategori;
  final int? idLokasi;
  final String? namaLokasi;
  final int? lantai;

  /// Waktu pemeliharaan terakhir (dari riwayat) — untuk status overdue.
  final DateTime? terakhirMaintenance;
  final int siklusHari;

  // Kolom tindak lanjut (migrasi M3). Opsional agar fixture lama tetap terparse.
  /// Username teknisi yang ditugaskan menangani alat ini.
  final String? penanggungJawab;
  final String? namaPenanggungJawab;
  final DateTime? ditugaskanPada;

  /// Sudah ada penanggung jawab (dipakai papan overdue).
  bool get ditugaskan => (penanggungJawab ?? '').isNotEmpty;

  /// Nama penanggung jawab siap tampil (fallback ke username).
  String get penanggungJawabTampil {
    final String nama = (namaPenanggungJawab ?? '').trim();
    if (nama.isNotEmpty) return nama;
    final String u = (penanggungJawab ?? '').trim();
    return u.isEmpty ? 'Belum ditugaskan' : u;
  }

  /// Umur sejak pemeliharaan terakhir, dalam hari.
  int? get umurHari {
    if (terakhirMaintenance == null) return null;
    return DateTime.now().difference(terakhirMaintenance!).inDays;
  }

  /// Belum pernah dipelihara atau melewati siklus → dianggap terlambat.
  bool get overdue {
    final int? umur = umurHari;
    if (umur == null) return true;
    return umur > siklusHari;
  }

  /// Sisa hari menuju jatuh tempo (negatif = sudah lewat).
  int? get sisaHari {
    final int? umur = umurHari;
    if (umur == null) return null;
    return siklusHari - umur;
  }

  /// Detail lokasi gaya aplikasi lama: "Aula Besar Lantai 7".
  String get detailLokasi {
    final String nama = (namaLokasi ?? '-').trim();
    if (lantai == null) return nama;
    return '$nama Lantai $lantai';
  }

  factory Alat.fromJson(Map<String, dynamic> json) {
    final Object? waktu = json['terakhir_maintenance'] ?? json['terakhirMaintenance'];
    return Alat(
      barcodeAlat: (json['barcode_alat'] ?? json['barcodeAlat'] ?? '') as String,
      merkAlat: (json['merk_alat'] ?? json['merkAlat'] ?? '') as String,
      idKategori: int.tryParse('${json['id_kategori'] ?? json['idKategori'] ?? 0}') ?? 0,
      namaKategori: (json['nama_kategori'] ?? json['namaKategori']) as String?,
      deskripsiKategori: (json['deskripsi'] ?? json['deskripsi_kategori']) as String?,
      idLokasi: json['id_lokasi'] == null ? null : int.tryParse('${json['id_lokasi']}'),
      namaLokasi: (json['nama_lokasi'] ?? json['namaLokasi']) as String?,
      lantai: json['lantai'] == null ? null : int.tryParse('${json['lantai']}'),
      terakhirMaintenance: waktu == null ? null : DateTime.tryParse('$waktu'),
      siklusHari:
          int.tryParse('${json['maintenance_cycle_days'] ?? json['siklus_hari'] ?? 30}') ?? 30,
      penanggungJawab: (json['penanggung_jawab'] ?? json['penanggungJawab']) as String?,
      namaPenanggungJawab:
          (json['nama_penanggung_jawab'] ?? json['namaPenanggungJawab']) as String?,
      ditugaskanPada: (json['ditugaskan_pada'] ?? json['ditugaskanPada']) == null
          ? null
          : DateTime.tryParse('${json['ditugaskan_pada'] ?? json['ditugaskanPada']}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode_alat': barcodeAlat,
        'merk_alat': merkAlat,
        'id_kategori': idKategori,
        'id_lokasi': idLokasi,
        'penanggung_jawab': penanggungJawab,
      };
}
