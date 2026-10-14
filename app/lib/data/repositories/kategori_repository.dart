import '../../domain/models/kategori.dart';
import '../../domain/models/spesifikasi.dart';
import '../api/api_service.dart';

class KategoriRepository {
  const KategoriRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<List<Kategori>> getKategoriList() => _api.getKategoriList();

  Future<List<Spesifikasi>> getSpesifikasi(int idKategori) =>
      _api.getSpesifikasiByKategori(idKategori);
}
