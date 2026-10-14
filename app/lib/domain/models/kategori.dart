import '../../core/constants/app_strings.dart';

/// Kategori alat. Padanan tabel `kategori` pada sistem lama
/// (id_kategori, nama) + kolom baru `deskripsi` dan `maintenance_cycle_days`.
///
/// Deskripsi diambil dari `strings.xml` aplikasi lama (lihat AppStrings).
class Kategori {
  const Kategori({
    required this.idKategori,
    required this.nama,
    this.deskripsi,
    this.maintenanceCycleDays = 30,
    this.iconAsset,
    this.jumlahAlat,
  });

  final int idKategori;
  final String nama;
  final String? deskripsi;
  final int maintenanceCycleDays;

  /// Aset ikon asli aplikasi lama (drawable/*.png).
  final String? iconAsset;

  /// Jumlah alat pada kategori ini (dipakai di grid beranda & dashboard).
  final int? jumlahAlat;

  /// Deskripsi: dari API bila ada, kalau tidak jatuh ke teks asli strings.xml.
  String get deskripsiTampil =>
      (deskripsi != null && deskripsi!.trim().isNotEmpty)
          ? deskripsi!
          : (AppStrings.kategoriDeskripsi[nama] ?? '');

  /// Ikon: dari API bila ada, kalau tidak jatuh ke aset asli.
  String? get iconTampil => iconAsset ?? AppStrings.kategoriIcon[nama];

  factory Kategori.fromJson(Map<String, dynamic> json) {
    final String nama = (json['nama'] ?? '') as String;
    return Kategori(
      idKategori: int.tryParse('${json['id_kategori'] ?? json['idKategori'] ?? 0}') ?? 0,
      nama: nama,
      deskripsi: json['deskripsi'] as String?,
      maintenanceCycleDays:
          int.tryParse('${json['maintenance_cycle_days'] ?? json['maintenanceCycleDays'] ?? 30}') ??
              30,
      iconAsset: json['icon_asset'] as String?,
      jumlahAlat: json['jumlah_alat'] == null
          ? null
          : int.tryParse('${json['jumlah_alat']}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_kategori': idKategori,
        'nama': nama,
        'deskripsi': deskripsi,
        'maintenance_cycle_days': maintenanceCycleDays,
      };
}
