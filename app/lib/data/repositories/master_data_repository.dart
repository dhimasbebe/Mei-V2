import '../../domain/models/alat.dart';
import '../../domain/models/kategori.dart';
import '../../domain/models/lokasi.dart';
import '../../domain/models/spesifikasi.dart';
import '../api/api_service.dart';

/// Repository master data (Admin): kategori, lokasi, spesifikasi, alat.
/// Tipis: hanya memanggil [ApiService].
class MasterDataRepository {
  const MasterDataRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  // --- Kategori -------------------------------------------------------------

  /// Daftar kategori (baca) — dipakai layar Master Data.
  Future<List<Kategori>> getKategoriList() => _api.getKategoriList();

  Future<Kategori> createKategori({
    required String nama,
    String? deskripsi,
    int? maintenanceCycleDays,
    String? iconAsset,
  }) =>
      _api.createKategori(
        nama: nama,
        deskripsi: deskripsi,
        maintenanceCycleDays: maintenanceCycleDays,
        iconAsset: iconAsset,
      );

  Future<Kategori> updateKategori({
    required int id,
    String? nama,
    String? deskripsi,
    String? iconAsset,
  }) =>
      _api.updateKategori(id: id, nama: nama, deskripsi: deskripsi, iconAsset: iconAsset);

  Future<void> deleteKategori(int id) => _api.deleteKategori(id);

  Future<Kategori> updateKategoriCycle({
    required int id,
    required int maintenanceCycleDays,
  }) =>
      _api.updateKategoriCycle(id: id, maintenanceCycleDays: maintenanceCycleDays);

  // --- Lokasi ---------------------------------------------------------------

  /// Daftar lokasi (baca) — dipakai layar Master Data.
  Future<List<Lokasi>> getLokasiList() => _api.getLokasiList();

  Future<Lokasi> createLokasi({required String namaLokasi, int? lantai}) =>
      _api.createLokasi(namaLokasi: namaLokasi, lantai: lantai);

  Future<Lokasi> updateLokasi({required int id, String? namaLokasi, int? lantai}) =>
      _api.updateLokasi(id: id, namaLokasi: namaLokasi, lantai: lantai);

  Future<void> deleteLokasi(int id) => _api.deleteLokasi(id);

  // --- Spesifikasi ----------------------------------------------------------

  Future<List<Spesifikasi>> getSpesifikasiList({int? idKategori}) =>
      _api.getSpesifikasiList(idKategori: idKategori);

  Future<Spesifikasi> createSpesifikasi({
    required int idKategori,
    required String namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) =>
      _api.createSpesifikasi(
        idKategori: idKategori,
        namaSpesifikasi: namaSpesifikasi,
        tipeInput: tipeInput,
        satuan: satuan,
        opsi: opsi,
        urutan: urutan,
      );

  Future<Spesifikasi> updateSpesifikasi({
    required int id,
    String? namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) =>
      _api.updateSpesifikasi(
        id: id,
        namaSpesifikasi: namaSpesifikasi,
        tipeInput: tipeInput,
        satuan: satuan,
        opsi: opsi,
        urutan: urutan,
      );

  Future<void> deleteSpesifikasi(int id) => _api.deleteSpesifikasi(id);

  Future<void> reorderSpesifikasi({
    required int idKategori,
    required List<int> urutanIds,
  }) =>
      _api.reorderSpesifikasi(idKategori: idKategori, urutanIds: urutanIds);

  // --- Alat -----------------------------------------------------------------

  /// Cari/daftar alat (baca) — dipakai layar Master Data.
  Future<List<Alat>> searchAlat({String? query, int? idKategori, int? idLokasi}) =>
      _api.searchAlat(query: query, idKategori: idKategori, idLokasi: idLokasi);

  Future<Alat> createAlat({
    required String barcodeAlat,
    required String merkAlat,
    required int idKategori,
    int? idLokasi,
  }) =>
      _api.createAlat(
        barcodeAlat: barcodeAlat,
        merkAlat: merkAlat,
        idKategori: idKategori,
        idLokasi: idLokasi,
      );

  Future<Alat> updateAlat({
    required String barcode,
    String? merkAlat,
    int? idKategori,
    int? idLokasi,
  }) =>
      _api.updateAlat(
        barcode: barcode,
        merkAlat: merkAlat,
        idKategori: idKategori,
        idLokasi: idLokasi,
      );

  Future<void> deleteAlat(String barcode) => _api.deleteAlat(barcode);
}
