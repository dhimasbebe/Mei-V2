import '../../domain/models/audit_log.dart';
import '../../domain/models/dashboard.dart';
import '../../domain/models/maintenance.dart';
import '../api/api_service.dart';

class MaintenanceRepository {
  const MaintenanceRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<Maintenance> submit(MaintenancePayload payload) => _api.submitMaintenance(payload);

  Future<PagedResult<Maintenance>> getList({
    int page = 1,
    int perPage = 20,
    String? barcodeAlat,
    int? idKategori,
    String? username,
    String? statusVerifikasi,
    DateTime? dari,
    DateTime? sampai,
  }) =>
      _api.getMaintenanceList(
        page: page,
        perPage: perPage,
        barcodeAlat: barcodeAlat,
        idKategori: idKategori,
        username: username,
        statusVerifikasi: statusVerifikasi,
        dari: dari,
        sampai: sampai,
      );

  Future<Maintenance> getDetail(int id) => _api.getMaintenanceDetail(id);

  /// Papan keterlambatan (Supervisor/Admin).
  Future<PagedResult<Maintenance>> getOverdue({int page = 1, int perPage = 20}) =>
      _api.getMaintenanceOverdue(page: page, perPage: perPage);

  /// Riwayat audit log (Admin/Supervisor) — Tahap 3 WS D.
  Future<PagedResult<AuditLogEntry>> getAuditLog({
    int page = 1,
    int perPage = 20,
    String? entitas,
    String? actor,
    String? aksi,
    String? dari,
    String? sampai,
  }) =>
      _api.getAuditLog(
        page: page,
        perPage: perPage,
        entitas: entitas,
        actor: actor,
        aksi: aksi,
        dari: dari,
        sampai: sampai,
      );
}
