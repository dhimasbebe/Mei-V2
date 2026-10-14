import '../../domain/models/alat.dart';
import '../../domain/models/lokasi.dart';
import '../api/api_service.dart';

class AlatRepository {
  const AlatRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<Alat> getByBarcode(String barcode) => _api.getAlatByBarcode(barcode);

  Future<List<Alat>> search({String? query, int? idKategori, int? idLokasi}) =>
      _api.searchAlat(query: query, idKategori: idKategori, idLokasi: idLokasi);

  Future<List<Lokasi>> getLokasiList() => _api.getLokasiList();
}
