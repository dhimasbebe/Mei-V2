import '../../domain/models/pengingat.dart';
import '../api/api_service.dart';

/// Akses `GET /pengingat` (Tahap 3 — WS B).
class PengingatRepository {
  const PengingatRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<PengingatPayload> getPengingat() => _api.getPengingat();
}
