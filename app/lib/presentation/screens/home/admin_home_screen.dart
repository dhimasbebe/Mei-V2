import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/notif_provider.dart';
import '../../../providers/verifikasi_provider.dart';
import '../../shell/role_shell.dart';
import '../../widgets/long_press_menu.dart';
import '../../widgets/app_card.dart';
import '../../widgets/notif_banner.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';
import 'home_header.dart';
import '../../../core/theme/app_palette.dart';

/// Beranda Admin — "Pusat Kendali".
///
/// Admin tidak memelihara alat dan tidak memverifikasi laporan; tugasnya
/// menjaga data induk dan akun tetap benar. Karena itu halaman ini
/// menonjolkan pintasan pengelolaan data, bukan daftar tugas.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardKpi> kpi = ref.watch(dashboardKpiProvider);
    final int menungguVerifikasi = ref.watch(pendingVerifikasiCountProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // AC-B7: banner pengingat memakai provider yang sama di ketiga
        // beranda, jadi ia harus ikut disegarkan di sini juga.
        ref.invalidate(pengingatProvider);
        final Future<void> pengingat = ref
            .read(pengingatProvider.future)
            .then<void>((_) {}, onError: (Object _) {});
        await pengingat;
        ref.invalidate(dashboardKpiProvider);
        ref.invalidate(dashboardOverdueProvider(5));
      },
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          HomeHeader(
            user: ref.watch(authProvider).user,
            subtitle: 'Pengelolaan data & akun',
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NotifBanner(
                  onTap: () => context.goVerifikasi(),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        label: 'Total alat',
                        value: kpi.maybeWhen(
                          data: (DashboardKpi k) => '${k.totalAlat}',
                          orElse: () => '-',
                        ),
                        icon: Icons.build_outlined,
                        color: AppColors.roleAdmin,
                        loading: kpi.isLoading,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Kategori',
                        value: kpi.maybeWhen(
                          data: (DashboardKpi k) => '${k.totalKategori}',
                          orElse: () => '-',
                        ),
                        icon: Icons.category_outlined,
                        color: AppColors.roleSupervisor,
                        loading: kpi.isLoading,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Alat terlambat',
                        value: kpi.maybeWhen(
                          data: (DashboardKpi k) => '${k.alatOverdue}',
                          orElse: () => '-',
                        ),
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.overdue,
                        loading: kpi.isLoading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Pusat data',
                  subtitle: 'Kelola sumber kebenaran aplikasi',
                  icon: Icons.storage_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.45,
                  children: <Widget>[
                    _AksiCepat(
                      icon: Icons.people_outline,
                      label: 'Manajemen User',
                      keterangan: 'Akun & role',
                      warna: AppColors.roleAdmin,
                      onTap: () => context.go(Routes.dataUsers),
                    ),
                    _AksiCepat(
                      icon: Icons.tune,
                      label: 'Master Data',
                      keterangan: 'Kategori, lokasi, checklist',
                      warna: AppColors.roleSupervisor,
                      onTap: () => context.go(Routes.dataMaster),
                    ),
                    _AksiCepat(
                      icon: Icons.qr_code_2,
                      label: 'Manajemen Alat',
                      keterangan: 'Barcode & penempatan',
                      warna: AppColors.roleTeknisi,
                      onTap: () => context.go(Routes.dataAlat),
                    ),
                    _AksiCepat(
                      icon: Icons.fact_check_outlined,
                      label: 'Verifikasi',
                      keterangan: menungguVerifikasi > 0
                          ? '$menungguVerifikasi menunggu'
                          : 'Tidak ada antrean',
                      warna: AppColors.verifikasiMenunggu,
                      onTap: () => context.goVerifikasi(),
                    ),
                    _AksiCepat(
                      icon: Icons.history,
                      label: 'Riwayat',
                      keterangan: 'Seluruh pemeliharaan',
                      warna: AppColors.statusOk,
                      onTap: () => context.goRiwayat(),
                    ),
                    _AksiCepat(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      keterangan: 'KPI & analitik',
                      warna: AppColors.primaryDark,
                      onTap: () => context.goDashboard(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Alat terlambat',
                  subtitle: 'Butuh perhatian',
                  icon: Icons.schedule,
                  actionLabel: 'Dashboard',
                  onAction: () => context.goDashboard(),
                ),
                const SizedBox(height: AppSpacing.md),
                const _PapanOverdue(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AksiCepat extends StatelessWidget {
  const _AksiCepat({
    required this.icon,
    required this.label,
    required this.keterangan,
    required this.warna,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String keterangan;
  final Color warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: warna),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.pal.textPrimary,
            ),
          ),
          Text(
            keterangan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: context.pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PapanOverdue extends ConsumerWidget {
  const _PapanOverdue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OverdueItem>> overdue =
        ref.watch(dashboardOverdueProvider(5));

    return overdue.when(
      loading: () => const Column(
        children: <Widget>[
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      ),
      error: (Object e, _) => ErrorView(
        message: 'Gagal memuat daftar keterlambatan.',
        compact: true,
        onRetry: () => ref.invalidate(dashboardOverdueProvider(5)),
      ),
      data: (List<OverdueItem> list) {
        if (list.isEmpty) {
          return AppCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.thumb_up_alt_outlined, color: AppColors.tepatWaktu),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Tidak ada alat yang melewati siklus pemeliharaan.',
                    style: TextStyle(fontSize: 13, color: context.pal.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: list
              .map((OverdueItem o) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      onTap: () => context.goAlat(o.barcodeAlat),
                      onLongPress: () => tampilkanMenuKonteksAlat(
                        context,
                        barcode: o.barcodeAlat,
                        onDetail: () => context.goAlat(o.barcodeAlat),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.schedule, color: AppColors.overdue),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  o.barcodeAlat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${o.merkAlat} • ${o.namaLokasi}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: '${o.terlambatHari} hari',
                            color: AppColors.overdue,
                            softColor: AppColors.overdueSoft,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
