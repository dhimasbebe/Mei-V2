import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/draft_provider.dart';

/// Pita status sinkronisasi offline (Tahap 3 — WS A, §7.1).
///
/// Ditampilkan di atas konten beranda ketika:
///  - ada draf yang belum tersinkron (`jumlahMenunggu > 0`), atau
///  - perangkat sedang offline.
///
/// Ketuk pita → buka layar antrean `/sinkron`.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DraftState draft = ref.watch(draftQueueProvider);
    final int menunggu = draft.jumlahMenunggu;
    final bool tampilkan = menunggu > 0 || !draft.online;
    if (!tampilkan) return const SizedBox.shrink();

    final bool offline = !draft.online;
    final (Color warna, Color latar, IconData ikon) = offline
        ? (AppColors.verifikasiMenunggu, AppColors.verifikasiMenungguSoft,
            Icons.cloud_off_outlined)
        : (AppColors.primary, AppColors.primarySoft, Icons.sync_outlined);

    final String teks = offline
        ? 'Anda offline — laporan tersimpan lokal dan dikirim otomatis saat online.'
        : menunggu == 1
            ? '1 laporan menunggu sinkronisasi.'
            : '$menunggu laporan menunggu sinkronisasi.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: latar,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => context.go(Routes.sinkron),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(ikon, size: 18, color: warna),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    teks,
                    style: TextStyle(fontSize: 12, color: warna),
                  ),
                ),
                if (draft.sedangSinkron)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right, size: 18, color: warna),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
