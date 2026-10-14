import '../../domain/models/tugas.dart';
import '../api/api_service.dart';

/// Repository "Tugas Hari Ini" (beranda Teknisi). Tipis: hanya memanggil
/// [ApiService].
class TugasRepository {
  const TugasRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<TugasHariIni> getHariIni() => _api.getTugasHariIni();
}
