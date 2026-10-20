import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Daftar lengkap alat yang melewati siklus pemeliharaan.
///
/// Tujuan kartu KPI "Terlambat" (AC-G6). Beranda hanya menampilkan 8 baris
/// pertama; layar ini meminta himpunan terbesar yang diizinkan server.
class DashboardOverdueScreen extends ConsumerWidget {
  const DashboardOverdueScreen({super.key});

  /// Server membatasi `limit` ke maksimum 100 (`DashboardController::overdue`).
  static const int batas = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OverdueItem>> async =
        ref.watch(dashboardOverdueProvider(batas));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Alat terlambat',
          subtitle: 'Melewati siklus pemeliharaan',
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            data: (List<OverdueItem> list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.thumb_up_alt_outlined,
                  title: 'Semua tepat waktu',
                  message:
                      'Tidak ada alat yang melewati siklus pemeliharaan.',
                );
              }
              return AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: context.pal.borderSubtle),
                  itemBuilder: (BuildContext context, int i) {
                    final OverdueItem o = list[i];
                    return ListTile(
                      dense: true,
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
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  SkeletonListTile(),
                  SkeletonListTile(),
                  SkeletonListTile(),
                ],
              ),
            ),
            error: (Object e, _) => ErrorView(
              message: 'Gagal memuat daftar keterlambatan.\n$e',
              onRetry: () => ref.invalidate(dashboardOverdueProvider(batas)),
            ),
          ),
        ),
      ],
    );
  }
}
