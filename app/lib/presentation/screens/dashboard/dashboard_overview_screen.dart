import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/charts/chart_range.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../domain/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/interactive_line_chart.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/responsive.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../../core/theme/app_palette.dart';

/// `yyyy-MM-dd` untuk query `dari`/`sampai` (AC-G6). Selalu ASCII angka;
/// tidak memakai locale agar tidak bergantung pada terjemahan.
String _tanggalQuery(DateTime d) {
  final String bulan = d.month.toString().padLeft(2, '0');
  final String hari = d.day.toString().padLeft(2, '0');
  return '${d.year}-$bulan-$hari';
}

/// Dashboard Overview — ringkasan KPI, tren, distribusi, dan alat terlambat.
///
/// Dirender di dalam `RoleShell`, jadi halaman ini hanya mengembalikan isi
/// (tanpa Scaffold/AppBar sendiri) agar tidak ada app bar bertumpuk.
class DashboardOverviewScreen extends ConsumerWidget {
  const DashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rentang tren diambil dari modul murni agar konsisten dengan layar
    // Analitik (AC-G2).
    final int hariTren = ChartRange.jumlahHari(ChartRange.periodeDefault);
    final AsyncValue<DashboardKpi> kpi = ref.watch(dashboardKpiProvider);
    final AsyncValue<List<TrendPoint>> trends =
        ref.watch(dashboardTrendsProvider(hariTren));
    final AsyncValue<List<DistributionItem>> distribusi =
        ref.watch(dashboardDistributionProvider);
    final AsyncValue<List<OverdueItem>> overdue =
        ref.watch(dashboardOverdueProvider(8));

    final int kolom =
        Responsive.gridColumns(context, mobile: 2, tablet: 2, desktop: 4);

    // AC-G6: tujuan tiap kartu. Kartu yang datanya hanya bisa dikelola Admin
    // (Total alat → Data Alat, Teknisi aktif → Data Users) sengaja tanpa aksi
    // untuk Supervisor, agar tidak melempar pengguna ke `/403`.
    final User? pengguna = ref.watch(authProvider).user;
    final bool admin = pengguna?.isAdmin ?? false;
    final DateTime sekarang = DateTime.now();
    final DateTime awalBulan = DateTime(sekarang.year, sekarang.month);
    final List<VoidCallback?> aksiKpi = <VoidCallback?>[
      admin ? () => context.go(Routes.dataAlat) : null,
      () => context.go(
            '${Routes.dashboardRecords}'
            '?dari=${_tanggalQuery(awalBulan)}&sampai=${_tanggalQuery(sekarang)}',
          ),
      () => context.go(Routes.dashboardOverdue),
      admin ? () => context.go(Routes.dataUsers) : null,
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(dashboardKpiProvider);
        ref.invalidate(dashboardTrendsProvider(hariTren));
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
            data: (DashboardKpi k) =>
                _GridKpi(kpi: k, kolom: kolom, aksi: aksiKpi),
            loading: () =>
                _GridKpi(kpi: null, kolom: kolom, aksi: aksiKpi),
            error: (Object e, _) => ErrorView(
              message: 'Gagal memuat KPI.\n$e',
              onRetry: () => ref.invalidate(dashboardKpiProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: 'Tren pemeliharaan',
            subtitle: '${ChartRange.label(ChartRange.periodeDefault)} terakhir',
            icon: Icons.show_chart,
            actionLabel: 'Analitik',
            onAction: () => context.go(Routes.dashboardAnalytics),
          ),
          const SizedBox(height: AppSpacing.md),
          _Panel(
            child: SizedBox(
              height: 240,
              child: trends.when(
                data: (List<TrendPoint> list) => InteractiveLineChart(
                  data: list,
                  tinggi: 240,
                  labelGaris: 'pemeliharaan',
                ),
                loading: () =>
                    const SkeletonBox(height: 240, radius: AppRadius.md),
                error: (Object e, _) => ErrorView(
                  message: 'Gagal memuat tren.',
                  compact: true,
                  onRetry: () =>
                      ref.invalidate(dashboardTrendsProvider(hariTren)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (Responsive.isDesktop(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _panelDistribusi(context, distribusi, ref)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _panelOverdue(context, overdue, ref)),
              ],
            )
          else
            Column(
              children: <Widget>[
                _panelDistribusi(context, distribusi, ref),
                const SizedBox(height: AppSpacing.lg),
                _panelOverdue(context, overdue, ref),
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
    BuildContext context,
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
    BuildContext context,
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
                      Divider(height: 1, color: context.pal.borderSubtle),
                  itemBuilder: (BuildContext context, int i) {
                    final OverdueItem o = list[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.schedule,
                        color: AppColors.overdue,
                        size: AppSizes.iconMd,
                      ),
                      title: Text(
                        o.barcodeAlat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${o.merkAlat} • ${o.namaLokasi}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11),
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
  const _GridKpi({
    required this.kpi,
    required this.kolom,
    required this.aksi,
  });

  /// `null` berarti masih memuat — kartu menampilkan skeleton.
  final DashboardKpi? kpi;
  final int kolom;

  /// Aksi ketuk per kartu, berurutan sesuai urutan di bawah (AC-G6).
  /// Entri `null` berarti kartu itu tidak dapat diketuk.
  final List<VoidCallback?> aksi;

  VoidCallback? _aksi(int i) => i < aksi.length ? aksi[i] : null;

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
        onTap: loading ? null : _aksi(0),
      ),
      KpiCard(
        label: 'Bulan ini',
        value: '${kpi?.pemeliharaanBulanIni ?? 0}',
        icon: Icons.fact_check_outlined,
        color: AppColors.tepatWaktu,
        loading: loading,
        onTap: loading ? null : _aksi(1),
      ),
      KpiCard(
        label: 'Terlambat',
        value: '${kpi?.alatOverdue ?? 0}',
        icon: Icons.warning_amber_rounded,
        color: AppColors.overdue,
        loading: loading,
        onTap: loading ? null : _aksi(2),
      ),
      KpiCard(
        label: 'Teknisi aktif',
        value: '${kpi?.teknisiAktif ?? 0}',
        icon: Icons.people_outline,
        color: AppColors.roleSupervisor,
        loading: loading,
        onTap: loading ? null : _aksi(3),
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

class _GrafikDistribusi extends StatefulWidget {
  const _GrafikDistribusi({required this.data});

  final List<DistributionItem> data;

  @override
  State<_GrafikDistribusi> createState() => _GrafikDistribusiState();
}

class _GrafikDistribusiState extends State<_GrafikDistribusi> {
  /// Indeks irisan yang sedang disentuh/`hover` — `-1` bila tidak ada.
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final List<DistributionItem> data = widget.data;
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Belum ada data',
        message: 'Distribusi muncul setelah alat terdaftar.',
      );
    }

    final bool tanpaAnimasi =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, PieTouchResponse? resp) {
                  final int index =
                      resp?.touchedSection?.touchedSectionIndex ?? -1;
                  if (index < 0 || index >= data.length) {
                    if (_touchedIndex != -1) {
                      setState(() => _touchedIndex = -1);
                    }
                    return;
                  }
                  if (event is FlPointerExitEvent ||
                      event is FlPointerHoverEvent ||
                      event is FlTapUpEvent ||
                      event is FlLongPressEnd) {
                    if (_touchedIndex != index) {
                      setState(() => _touchedIndex = index);
                    }
                  }
                },
              ),
              sections:
                  data.asMap().entries.map((MapEntry<int, DistributionItem> e) {
                final bool aktif = e.key == _touchedIndex;
                final double pct =
                    total == 0 ? 0 : (e.value.jumlah / total) * 100;
                return PieChartSectionData(
                  color: warna[e.key % warna.length],
                  value: e.value.jumlah.toDouble(),
                  // Irisan kecil tetap menampilkan persentase saat disentuh
                  // agar informasinya tetap terbaca (AC-G7).
                  title: (pct < 6 && !aktif) ? '' : '${pct.toStringAsFixed(0)}%',
                  radius: aktif ? 60 : 52,
                  titleStyle: TextStyle(
                    fontSize: aktif ? 12 : 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
            duration: tanpaAnimasi
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: tanpaAnimasi ? Curves.linear : Curves.easeOutCubic,
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
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(
                    '${data[i].jumlah}',
                    style: TextStyle(
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
