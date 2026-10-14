/// Lokasi/ruang alat. Padanan tabel `lokasi` (id_lokasi, lantai, nama_lokasi).
///
/// Dipakai sebagai dropdown "Ruang" pada form pemeliharaan aplikasi lama.
class Lokasi {
  const Lokasi({
    required this.idLokasi,
    required this.namaLokasi,
    this.lantai,
    this.jumlahAlat,
  });

  final int idLokasi;
  final String namaLokasi;
  final int? lantai;
  final int? jumlahAlat;

  /// Label dropdown: "Ruang ME Lantai 7" (nama_lokasi sudah memuat "Ruang ...").
  String get label {
    if (lantai == null) return namaLokasi;
    final String nama = namaLokasi.trim();
    return nama.toLowerCase().contains('lantai') ? nama : '$nama Lantai $lantai';
  }

  factory Lokasi.fromJson(Map<String, dynamic> json) {
    return Lokasi(
      idLokasi: int.tryParse('${json['id_lokasi'] ?? json['idLokasi'] ?? 0}') ?? 0,
      namaLokasi: (json['nama_lokasi'] ?? json['namaLokasi'] ?? '') as String,
      lantai: json['lantai'] == null ? null : int.tryParse('${json['lantai']}'),
      jumlahAlat: json['jumlah_alat'] == null ? null : int.tryParse('${json['jumlah_alat']}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_lokasi': idLokasi,
        'nama_lokasi': namaLokasi,
        'lantai': lantai,
      };
}
