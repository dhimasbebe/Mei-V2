import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../domain/models/verifikasi.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/verifikasi_provider.dart';
import '../../shell/role_shell.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';
import 'home_header.dart';
import '../../../core/theme/app_palette.dart';

/// Beranda Supervisor — "Pengawasan Eksekusi".
///
/// Supervisor tidak mengerjakan checklist; ia memastikan pekerjaan teknisi
/// benar. Karena itu halaman ini menonjolkan antrean verifikasi dan papan
/// keterlambatan, bukan daftar tugas pribadi.
class SupervisorHomeScreen extends ConsumerStatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  ConsumerState<SupervisorHomeScreen> createState() =>
      _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends ConsumerState<SupervisorHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(verifikasiProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final VerifikasiState verif = ref.watch(verifikasiProvider);
    final AsyncValue<DashboardKpi> kpi = ref.watch(dashboardKpiProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await ref.read(verifikasiProvider.notifier).refresh();
        ref.invalidate(dashboardKpiProvider);
        ref.invalidate(dashboardOverdueProvider(5));
      },
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          HomeHeader(
            user: ref.watch(authProvider).user,
            subtitle: 'Pengawasan pemeliharaan',
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        label: 'Menunggu verifikasi',
                        value: verif.badge,
                        icon: Icons.fact_check_outlined,
                        color: AppColors.roleSupervisor,
                        loading: verif.isLoading && verif.data == null,
                        onTap: () => context.goVerifikasi(),
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
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Pemeliharaan bulan ini',
                        value: kpi.maybeWhen(
                          data: (DashboardKpi k) => '${k.pemeliharaanBulanIni}',
                          orElse: () => '-',
                        ),
                        icon: Icons.fact_check,
                        color: AppColors.tepatWaktu,
                        loading: kpi.isLoading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Perlu diverifikasi',
                  subtitle: 'Laporan teknisi yang menunggu persetujuan',
                  actionLabel: 'Lihat semua',
                  icon: Icons.rule_folder_outlined,
                  onAction: () => context.goVerifikasi(),
                ),
                const SizedBox(height: AppSpacing.md),
                _AntreanVerifikasi(state: verif),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Alat terlambat',
                  subtitle: 'Perlu tindak lanjut segera',
                  icon: Icons.schedule,
                  onAction: () => context.goDashboard(),
                  actionLabel: 'Dashboard',
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

class _AntreanVerifikasi extends ConsumerWidget {
  const _AntreanVerifikasi({required this.state});

  final VerifikasiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.data == null) {
      return const Column(
        children: <Widget>[
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      );
    }

    if (state.error != null && state.data == null) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(verifikasiProvider.notifier).load(),
      );
    }

    if (state.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_outlined,
        title: 'Tidak ada yang menunggu',
        message: 'Semua laporan teknisi sudah Anda tinjau.',
      );
    }

    final List<VerifikasiItem> items = state.items.take(3).toList();
    return Column(
      children: items
          .map((VerifikasiItem v) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  onTap: () => context.goVerifikasi(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.pending_actions,
                        color: AppColors.verifikasiMenunggu,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              v.barcodeAlat,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${v.teknisi} • ${v.detailLokasi}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.pal.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _waktu(v.waktuMaintenance),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.pal.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(
                        label: 'Menunggu',
                        color: AppColors.verifikasiMenunggu,
                        softColor: AppColors.verifikasiMenungguSoft,
                        icon: Icons.hourglass_empty,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  static String _waktu(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
          return const EmptyState(
            icon: Icons.thumb_up_alt_outlined,
            title: 'Semua tepat waktu',
            message: 'Tidak ada alat yang melewati siklus pemeliharaan.',
          );
        }
        return Column(
          children: list
              .map((OverdueItem o) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      onTap: () => context.goAlat(o.barcodeAlat),
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
