import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/responsive.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Dashboard Overview — ringkasan KPI, tren, distribusi, dan alat terlambat.
///
/// Dirender di dalam `RoleShell`, jadi halaman ini hanya mengembalikan isi
/// (tanpa Scaffold/AppBar sendiri) agar tidak ada app bar bertumpuk.
class DashboardOverviewScreen extends ConsumerWidget {
  const DashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardKpi> kpi = ref.watch(dashboardKpiProvider);
    final AsyncValue<List<TrendPoint>> trends =
        ref.watch(dashboardTrendsProvider(30));
    final AsyncValue<List<DistributionItem>> distribusi =
        ref.watch(dashboardDistributionProvider);
    final AsyncValue<List<OverdueItem>> overdue =
        ref.watch(dashboardOverdueProvider(8));

    final int kolom =
        Responsive.gridColumns(context, mobile: 2, tablet: 2, desktop: 4);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(dashboardKpiProvider);
        ref.invalidate(dashboardTrendsProvider(30));
        ref.invalidate(dashboardDistributionProvider);
        ref.invalidate(dashboardOverdueProvider(8));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SectionHeader(
            title: 'Ringkasan',
            subtitle: 'Kondisi pemeliharaan alat terkini',
            icon: Icons.insights_outlined,
            actionLabel: 'Analitik',
            onAction: () => context.go(Routes.dashboardAnalytics),
          ),
          const SizedBox(height: AppSpacing.md),
          kpi.when(
            data: (DashboardKpi k) => _GridKpi(kpi: k, kolom: kolom),
            loading: () => _GridKpi(kpi: null, kolom: kolom),
            error: (Object e, _) => ErrorView(
              message: 'Gagal memuat KPI.\n$e',
              onRetry: () => ref.invalidate(dashboardKpiProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: 'Tren pemeliharaan',
            subtitle: '30 hari terakhir',
            icon: Icons.show_chart,
            actionLabel: 'Analitik',
            onAction: () => context.go(Routes.dashboardAnalytics),
          ),
          const SizedBox(height: AppSpacing.md),
          _Panel(
            child: SizedBox(
              height: 240,
              child: trends.when(
                data: (List<TrendPoint> list) => _GrafikTren(data: list),
                loading: () =>
                    const SkeletonBox(height: 240, radius: AppRadius.md),
                error: (Object e, _) => ErrorView(
                  message: 'Gagal memuat tren.',
                  compact: true,
                  onRetry: () => ref.invalidate(dashboardTrendsProvider(30)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (Responsive.isDesktop(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _panelDistribusi(distribusi, ref)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _panelOverdue(overdue, ref)),
              ],
            )
          else
            Column(
              children: <Widget>[
                _panelDistribusi(distribusi, ref),
                const SizedBox(height: AppSpacing.lg),
                _panelOverdue(overdue, ref),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: 'Catatan lengkap',
            subtitle: 'Seluruh riwayat pemeliharaan',
            icon: Icons.table_chart_outlined,
            actionLabel: 'Buka tabel',
            onAction: () => context.go(Routes.dashboardRecords),
          ),
        ],
      ),
    );
  }

  Widget _panelDistribusi(
    AsyncValue<List<DistributionItem>> data,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Distribusi per kategori',
          icon: Icons.pie_chart_outline,
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(
          child: SizedBox(
            height: 240,
            child: data.when(
              data: (List<DistributionItem> list) =>
                  _GrafikDistribusi(data: list),
              loading: () =>
                  const SkeletonBox(height: 240, radius: AppRadius.md),
              error: (Object e, _) => ErrorView(
                message: 'Gagal memuat distribusi.',
                compact: true,
                onRetry: () => ref.invalidate(dashboardDistributionProvider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelOverdue(
    AsyncValue<List<OverdueItem>> data,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Alat terlambat',
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(
          child: SizedBox(
            height: 240,
            child: data.when(
              data: (List<OverdueItem> list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.thumb_up_alt_outlined,
                    title: 'Semua tepat waktu',
                    message: 'Tidak ada alat yang melewati siklus pemeliharaan.',
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (BuildContext context, int i) {
                    final OverdueItem o = list[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule,
                        color: AppColors.overdue,
                        size: AppSizes.iconMd,
                      ),
                      title: Text(
                        o.barcodeAlat,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${o.merkAlat} • ${o.namaLokasi}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: StatusBadge(
                        label: '${o.terlambatHari} hari',
                        color: AppColors.overdue,
                        softColor: AppColors.overdueSoft,
                        dense: true,
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const SkeletonBox(height: 240, radius: AppRadius.md),
              error: (Object e, _) => ErrorView(
                message: 'Gagal memuat daftar keterlambatan.',
                compact: true,
                onRetry: () => ref.invalidate(dashboardOverdueProvider(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridKpi extends StatelessWidget {
  const _GridKpi({required this.kpi, required this.kolom});

  /// `null` berarti masih memuat — kartu menampilkan skeleton.
  final DashboardKpi? kpi;
  final int kolom;

  @override
  Widget build(BuildContext context) {
    final bool loading = kpi == null;
    final List<Widget> kartu = <Widget>[
      KpiCard(
        label: 'Total alat',
        value: '${kpi?.totalAlat ?? 0}',
        icon: Icons.build_outlined,
        color: AppColors.roleAdmin,
        loading: loading,
      ),
      KpiCard(
        label: 'Bulan ini',
        value: '${kpi?.pemeliharaanBulanIni ?? 0}',
        icon: Icons.fact_check_outlined,
        color: AppColors.tepatWaktu,
        loading: loading,
      ),
      KpiCard(
        label: 'Terlambat',
        value: '${kpi?.alatOverdue ?? 0}',
        icon: Icons.warning_amber_rounded,
        color: AppColors.overdue,
        loading: loading,
      ),
      KpiCard(
        label: 'Teknisi aktif',
        value: '${kpi?.teknisiAktif ?? 0}',
        icon: Icons.people_outline,
        color: AppColors.roleSupervisor,
        loading: loading,
        delta: loading
            ? null
            : '${kpi!.kepatuhanPersen.toStringAsFixed(0)}% tepat waktu',
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: kolom,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.6,
      children: kartu,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

class _GrafikTren extends StatelessWidget {
  const _GrafikTren({required this.data});

  final List<TrendPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Belum ada data tren',
        message: 'Grafik akan terisi setelah ada pemeliharaan tercatat.',
      );
    }

    final List<FlSpot> spots = data
        .asMap()
        .entries
        .map(
          (MapEntry<int, TrendPoint> e) =>
              FlSpot(e.key.toDouble(), e.value.jumlah.toDouble()),
        )
        .toList();

    final double maxY = spots
            .map((FlSpot s) => s.y)
            .reduce((double a, double b) => a > b ? a : b) *
        1.25;

    return LineChart(
      LineChartData(
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
              reservedSize: 26,
              interval: (data.length / 6).ceilToDouble().clamp(1, 30),
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final String l = data[i].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.length > 5 ? l.substring(5) : l,
                    style: const TextStyle(
                      fontSize: 10,
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
        minY: 0,
        maxY: maxY < 5 ? 5 : maxY,
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(show: data.length <= 15),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrafikDistribusi extends StatelessWidget {
  const _GrafikDistribusi({required this.data});

  final List<DistributionItem> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Belum ada data',
        message: 'Distribusi muncul setelah alat terdaftar.',
      );
    }

    final double total =
        data.fold(0, (double s, DistributionItem d) => s + d.jumlah);
    final List<Color> warna = <Color>[
      AppColors.primary,
      AppColors.roleAdmin,
      AppColors.roleSupervisor,
      AppColors.statusWarning,
      AppColors.statusOk,
      AppColors.primaryDark,
    ];

    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections:
                  data.asMap().entries.map((MapEntry<int, DistributionItem> e) {
                final double pct =
                    total == 0 ? 0 : (e.value.jumlah / total) * 100;
                return PieChartSectionData(
                  color: warna[e.key % warna.length],
                  value: e.value.jumlah.toDouble(),
                  title: pct < 6 ? '' : '${pct.toStringAsFixed(0)}%',
                  radius: 52,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: warna[i % warna.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      data[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(
                    '${data[i].jumlah}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
