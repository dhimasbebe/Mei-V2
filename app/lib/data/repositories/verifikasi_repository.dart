import '../../domain/models/dashboard.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/verifikasi.dart';
import '../api/api_service.dart';

/// Repository verifikasi maintenance (Supervisor/Admin). Tipis: hanya
/// memanggil [ApiService].
class VerifikasiRepository {
  const VerifikasiRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  /// Daftar menunggu verifikasi (berpaginasi).
  Future<PagedResult<VerifikasiItem>> getPending({int page = 1, int perPage = 20}) =>
      _api.getMaintenancePending(page: page, perPage: perPage);

  /// Jumlah antrean menunggu (badge tab Verifikasi).
  Future<PendingCount> getCount() => _api.getMaintenancePendingCount();

  /// Setujui / tolak satu item verifikasi.
  Future<Maintenance> verify(int id, VerifikasiPayload payload) =>
      _api.verifyMaintenance(id, payload);
}
