import '../../domain/models/alat.dart';
import '../../domain/models/alat_import.dart';
import '../../domain/models/lokasi.dart';
import '../api/api_service.dart';

class AlatRepository {
  const AlatRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<Alat> getByBarcode(String barcode) => _api.getAlatByBarcode(barcode);

  Future<List<Alat>> search({String? query, int? idKategori, int? idLokasi}) =>
      _api.searchAlat(query: query, idKategori: idKategori, idLokasi: idLokasi);

  Future<List<Lokasi>> getLokasiList() => _api.getLokasiList();

  // --- Impor CSV massal (WS M — T09) -----------------------------------------

  /// Validasi CSV per baris tanpa menulis DB (AC-M1).
  ///
  /// Pilih salah satu sumber: [csv] teks tempelan (ponsel) atau [fileBytes]
  /// isi berkas (web). [fileBytes] diutamakan bila keduanya diisi (AC-M9).
  Future<AlatImportResult> previewImpor({
    String? csv,
    List<int>? fileBytes,
    String namaFile = 'alat.csv',
  }) =>
      _api.previewImporCsv(csv: csv, fileBytes: fileBytes, namaFile: namaFile);

  /// Tulis hanya baris valid dalam satu transaksi (AC-M2, AC-M3).
  Future<AlatImportResult> commitImpor({
    String? csv,
    List<int>? fileBytes,
    String namaFile = 'alat.csv',
  }) =>
      _api.commitImporCsv(csv: csv, fileBytes: fileBytes, namaFile: namaFile);
}
