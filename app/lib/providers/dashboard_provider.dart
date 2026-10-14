import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/dashboard_repository.dart';
import '../domain/models/dashboard.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => const DashboardRepository(),
);

final dashboardKpiProvider = FutureProvider<DashboardKpi>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getKpi();
});

final dashboardTrendsProvider = FutureProvider.family<List<TrendPoint>, int>((ref, hari) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getTrends(hari: hari);
});

final dashboardDistributionProvider = FutureProvider<List<DistributionItem>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDistribution();
});

final dashboardOverdueProvider = FutureProvider.family<List<OverdueItem>, int>((ref, limit) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getOverdue(limit: limit);
});
