import '../../domain/models/dashboard.dart';
import '../api/api_service.dart';

class DashboardRepository {
  const DashboardRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<DashboardKpi> getKpi() => _api.getDashboardKpi();

  Future<List<TrendPoint>> getTrends({int hari = 30}) => _api.getDashboardTrends(hari: hari);

  Future<List<DistributionItem>> getDistribution() => _api.getDashboardDistribution();

  Future<List<OverdueItem>> getOverdue({int limit = 10}) => _api.getDashboardOverdue(limit: limit);

  // --- Ekspor berkas (WS L, N — T09) -----------------------------------------

  /// CSV riwayat pemeliharaan (Supervisor/Admin) — biner.
  Future<List<int>> exportCsv({DateTime? dari, DateTime? sampai}) =>
      _api.exportLaporan(dari: dari, sampai: sampai, format: 'csv');

  /// PDF ringkasan periode (Supervisor/Admin). Server menolak 422 bila rentang
  /// > 90 hari atau baris > 500 (AC-L3).
  Future<List<int>> exportPdf({required DateTime dari, required DateTime sampai}) =>
      _api.getPeriodePdf(dari: dari, sampai: sampai);

  /// PDF label QR untuk daftar [barcode] (AC-N1, AC-N2).
  Future<List<int>> exportQrLabels(List<String> barcode) => _api.postQrLabels(barcode);
}
