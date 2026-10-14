import '../../domain/models/dashboard.dart';
import '../api/api_service.dart';

class DashboardRepository {
  const DashboardRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<DashboardKpi> getKpi() => _api.getDashboardKpi();

  Future<List<TrendPoint>> getTrends({int hari = 30}) => _api.getDashboardTrends(hari: hari);

  Future<List<DistributionItem>> getDistribution() => _api.getDashboardDistribution();

  Future<List<OverdueItem>> getOverdue({int limit = 10}) => _api.getDashboardOverdue(limit: limit);
}
