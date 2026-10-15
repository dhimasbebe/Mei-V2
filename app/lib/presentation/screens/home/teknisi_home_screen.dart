import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/tugas.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/tugas_provider.dart';
import '../../shell/role_shell.dart';
import '../../widgets/long_press_menu.dart';
import '../../widgets/app_card.dart';
import '../../widgets/notif_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/sync_banner.dart';
import 'home_header.dart';
import '../../../core/theme/app_palette.dart';

/// Beranda Teknisi — "Tugas Hari Ini".
///
/// Alur kerja teknisi: lihat alat yang jatuh tempo/terlambat, buka detailnya,
/// isi checklist pemeliharaan. Karena itu halaman ini menonjolkan daftar tugas
/// dan tombol scan, bukan grafik.
class TeknisiHomeScreen extends ConsumerStatefulWidget {
  const TeknisiHomeScreen({super.key});

  @override
  ConsumerState<TeknisiHomeScreen> createState() => _TeknisiHomeScreenState();
}

class _TeknisiHomeScreenState extends ConsumerState<TeknisiHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(tugasProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final TugasState state = ref.watch(tugasProvider);
    final TugasRingkasan ringkasan = state.ringkasan;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(tugasProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          HomeHeader(
            user: ref.watch(authProvider).user,
            subtitle: 'Tugas pemeliharaan hari ini',
          ),
          // Pita status sinkron offline (Tahap 3 — WS A): muncul saat ada
          // draf menunggu atau perangkat offline; ketuk → /sinkron.
          const SyncBanner(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NotifBanner(
                  onTap: () => context.goTugas(),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        label: 'Total tugas',
                        value: '${ringkasan.total}',
                        icon: Icons.assignment_outlined,
                        color: AppColors.roleTeknisi,
                        loading: state.isLoading && state.data == null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Terlambat',
                        value: '${ringkasan.overdue}',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.overdue,
                        loading: state.isLoading && state.data == null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Jatuh tempo',
                        value: '${ringkasan.jatuhTempoHariIni}',
                        icon: Icons.today_outlined,
                        color: AppColors.statusWarning,
                        loading: state.isLoading && state.data == null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Perlu dikerjakan',
                  subtitle: 'Urut dari yang paling terlambat',
                  actionLabel: 'Scan',
                  icon: Icons.qr_code_scanner,
                  onAction: () => context.goScan(),
                ),
                const SizedBox(height: AppSpacing.md),
                _IsiTugas(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IsiTugas extends ConsumerWidget {
  const _IsiTugas({required this.state});

  final TugasState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.data == null) {
      return const Column(
        children: <Widget>[
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      );
    }

    if (state.error != null && state.data == null) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(tugasProvider.notifier).load(),
      );
    }

    if (state.kosong) {
      return EmptyState(
        icon: Icons.task_alt,
        title: 'Tidak ada tugas hari ini',
        message:
            'Semua alat dalam siklus pemeliharaannya. Anda tetap bisa memindai '
            'barcode alat kapan saja untuk mencatat pemeliharaan.',
        actionLabel: 'SCAN BARCODE',
        onAction: () => context.goScan(),
      );
    }

    return Column(
      children: state.daftar
          .map((TugasItem t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _TugasCard(tugas: t),
              ))
          .toList(),
    );
  }
}

class _TugasCard extends StatelessWidget {
  const _TugasCard({required this.tugas});

  final TugasItem tugas;

  @override
  Widget build(BuildContext context) {
    final bool overdue = tugas.isOverdue;
    final String? ikon = AppStrings.kategoriIcon[tugas.namaKategori];

    return AppCard(
      onTap: () => context.goAlat(tugas.barcodeAlat),
      onLongPress: () => tampilkanMenuKonteksAlat(
        context,
        barcode: tugas.barcodeAlat,
        onDetail: () => context.goAlat(tugas.barcodeAlat),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: overdue ? AppColors.overdueSoft : context.pal.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: ikon != null
                ? Image.asset(ikon, width: 30, height: 30, fit: BoxFit.contain)
                : Icon(
                    Icons.build_outlined,
                    color: overdue ? AppColors.overdue : context.pal.textSecondary,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tugas.barcodeAlat,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tugas.merkAlat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.pal.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: context.pal.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        tugas.detailLokasi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.pal.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              StatusBadge(
                label: overdue
                    ? 'Terlambat'
                    : (tugas.jatuhTempoHariIni ? 'Hari ini' : 'Terjadwal'),
                color: overdue
                    ? AppColors.overdue
                    : (tugas.jatuhTempoHariIni
                        ? AppColors.statusWarning
                        : AppColors.tepatWaktu),
                softColor: overdue
                    ? AppColors.overdueSoft
                    : (tugas.jatuhTempoHariIni
                        ? AppColors.verifikasiMenungguSoft
                        : AppColors.tepatWaktuSoft),
                icon: overdue ? Icons.warning_amber_rounded : Icons.schedule,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tugas.teksKeterlambatan,
                style: TextStyle(
                  fontSize: 11,
                  color: context.pal.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
