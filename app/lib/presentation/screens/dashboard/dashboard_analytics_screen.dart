import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/charts/chart_range.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/interactive_line_chart.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';

/// Dashboard Analytics — analisis tren pemeliharaan dengan filter periode.
///
/// Periode dikelola sebagai kode `ChartRange.periods` (`'7d'`, `'30d'`,
/// `'90d'`) sehingga rentang tanggal, label, dan jumlah hari seluruhnya
/// berasal dari modul murni `core/charts/chart_range.dart` (AC-G2/AC-G3).
class DashboardAnalyticsScreen extends ConsumerStatefulWidget {
  const DashboardAnalyticsScreen({super.key});

  @override
  ConsumerState<DashboardAnalyticsScreen> createState() =>
      _DashboardAnalyticsScreenState();
}

class _DashboardAnalyticsScreenState
    extends ConsumerState<DashboardAnalyticsScreen> {
  /// Kode periode aktif — selalu salah satu nilai [ChartRange.periods].
  String _periode = ChartRange.periodeDefault;

  @override
  Widget build(BuildContext context) {
    final int hari = ChartRange.jumlahHari(_periode);
    final ChartRange rentang = ChartRange.forPeriod(_periode);
    final AsyncValue<List<TrendPoint>> trends =
        ref.watch(dashboardTrendsProvider(hari));

    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'Analitik',
          subtitle: 'Jumlah pemeliharaan per hari',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        FilterChipBar(
          items: ChartRange.periods,
          selected: <String>[_periode],
          multi: false,
          labelBuilder: ChartRange.label,
          onChanged: (List<String> pilih) {
            if (pilih.isEmpty) return;
            setState(() => _periode = pilih.last);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        trends.when(
          data: (List<TrendPoint> list) => _Ringkasan(data: list, hari: hari),
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
                'Tren ${ChartRange.label(_periode)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.pal.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_tanggal(rentang.dari)} – ${_tanggal(rentang.sampai)}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.pal.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              trends.when(
                data: (List<TrendPoint> list) => InteractiveLineChart(
                  data: list,
                  tinggi: 300,
                  labelGaris: 'pemeliharaan',
                ),
                loading: () =>
                    const SkeletonBox(height: 300, radius: AppRadius.md),
                error: (Object e, _) => ErrorView(
                  message: 'Gagal memuat tren.\n$e',
                  onRetry: () => ref.invalidate(dashboardTrendsProvider(hari)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// Format ringkas `dd/MM/yyyy` untuk keterangan rentang tanggal.
  static String _tanggal(DateTime d) {
    final String bulan = d.month.toString().padLeft(2, '0');
    final String hari = d.day.toString().padLeft(2, '0');
    return '$hari/$bulan/${d.year}';
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
