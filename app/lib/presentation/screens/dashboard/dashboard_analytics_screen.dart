import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';

/// Dashboard Analytics — analisis tren pemeliharaan dengan filter periode.
class DashboardAnalyticsScreen extends ConsumerStatefulWidget {
  const DashboardAnalyticsScreen({super.key});

  @override
  ConsumerState<DashboardAnalyticsScreen> createState() =>
      _DashboardAnalyticsScreenState();
}

class _DashboardAnalyticsScreenState
    extends ConsumerState<DashboardAnalyticsScreen> {
  int _hari = 30;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TrendPoint>> trends =
        ref.watch(dashboardTrendsProvider(_hari));

    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'Analitik',
          subtitle: 'Jumlah pemeliharaan per hari',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        FilterChipBar(
          items: const <String>['7 hari', '30 hari', '90 hari'],
          selected: <String>['$_hari hari'],
          multi: false,
          onChanged: (List<String> pilih) {
            if (pilih.isEmpty) return;
            setState(() => _hari = int.tryParse(pilih.last.split(' ').first) ?? 30);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        trends.when(
          data: (List<TrendPoint> list) => _Ringkasan(data: list, hari: _hari),
          loading: () => const _SkeletonRingkasan(),
          error: (Object e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tren $_hari hari',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 300,
                child: trends.when(
                  data: (List<TrendPoint> list) => _GrafikBatang(data: list),
                  loading: () =>
                      const SkeletonBox(height: 300, radius: AppRadius.md),
                  error: (Object e, _) => ErrorView(
                    message: 'Gagal memuat tren.\n$e',
                    onRetry: () => ref.invalidate(dashboardTrendsProvider(_hari)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SkeletonRingkasan extends StatelessWidget {
  const _SkeletonRingkasan();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(child: SkeletonBox(height: 84, radius: AppRadius.md)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: SkeletonBox(height: 84, radius: AppRadius.md)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: SkeletonBox(height: 84, radius: AppRadius.md)),
      ],
    );
  }
}

/// Tiga angka kunci yang bisa langsung dibaca pengawas.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.data, required this.hari});

  final List<TrendPoint> data;
  final int hari;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Belum ada data',
        message: 'Tidak ada pemeliharaan pada periode ini.',
      );
    }

    final int total = data.fold(0, (int s, TrendPoint t) => s + t.jumlah);
    final int puncak =
        data.map((TrendPoint t) => t.jumlah).reduce((int a, int b) => a > b ? a : b);
    final double rata = total / data.length;

    return Row(
      children: <Widget>[
        Expanded(
          child: StatTile(
            label: 'Total ($hari hari)',
            value: '$total',
            icon: Icons.summarize_outlined,
            color: AppColors.roleAdmin,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            label: 'Rata-rata/hari',
            value: rata.toStringAsFixed(1),
            icon: Icons.timeline,
            color: AppColors.roleSupervisor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            label: 'Puncak',
            value: '$puncak',
            icon: Icons.arrow_upward,
            color: AppColors.statusWarning,
          ),
        ),
      ],
    );
  }
}

class _GrafikBatang extends StatelessWidget {
  const _GrafikBatang({required this.data});

  final List<TrendPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        title: 'Tidak ada data',
        message: 'Coba pilih periode lain.',
      );
    }

    final double maxY = data
            .map((TrendPoint t) => t.jumlah.toDouble())
            .reduce((double a, double b) => a > b ? a : b) *
        1.25;

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double v) =>
              const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (data.length / 8).ceilToDouble().clamp(1, 60),
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final String l = data[i].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.length > 5 ? l.substring(5) : l,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxY < 5 ? 5 : maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              return BarTooltipItem(
                '${data[group.x].label}\n${rod.toY.toInt()} pemeliharaan',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: data.asMap().entries.map((MapEntry<int, TrendPoint> e) {
          return BarChartGroupData(
            x: e.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: e.value.jumlah.toDouble(),
                color: AppColors.primary,
                width: data.length > 40 ? 6 : 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
