import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/pengingat.dart';
import '../../providers/notif_provider.dart';

/// Banner pengingat in-app (Tahap 3 — WS B, AC-B7/B8).
///
/// Selalu tampil dari data `GET /pengingat` — tidak bergantung pada izin
/// notifikasi OS. Menekan banner membuka layar tujuan ([onTap]);
/// [onSegarkan] dipakai pull-to-refresh daftar pengingat.
class NotifBanner extends ConsumerWidget {
  const NotifBanner({super.key, this.onTap, this.ringkas = false});

  /// Aksi saat banner ditekan (mis. menuju layar Verifikasi/Tugas).
  final VoidCallback? onTap;

  /// Versi ringkas tanpa daftar item (dipakai di beranda).
  final bool ringkas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PengingatPayload> async = ref.watch(pengingatProvider);
    final PengingatPayload? data = async.valueOrNull;

    if (async.isLoading && data == null) {
      return const SizedBox.shrink();
    }
    if (data == null || data.kosong) {
      return const SizedBox.shrink();
    }

    final AppPalette pal = context.pal;
    final PengingatRingkasan r = data.ringkasan;
    final bool adaTerlambat = r.terlambat > 0;
    final Color aksen =
        adaTerlambat ? AppColors.statusDanger : AppColors.statusWarning;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: aksen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      adaTerlambat
                          ? Icons.warning_amber_rounded
                          : Icons.notifications_active_outlined,
                      size: AppSizes.iconMd,
                      color: aksen,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _judul(r),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        size: AppSizes.iconMd,
                        color: pal.textSecondary,
                      ),
                  ],
                ),
                if (!ringkas && data.daftar.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  for (final PengingatItem it in data.daftar.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            it.terlambat
                                ? Icons.schedule
                                : Icons.event_available_outlined,
                            size: 14,
                            color: it.terlambat
                                ? AppColors.statusDanger
                                : pal.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _baris(it),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: pal.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref.invalidate(pengingatProvider),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.touchTarget),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    child: Text(
                      'Segarkan',
                      style: TextStyle(fontSize: 12, color: aksen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _judul(PengingatRingkasan r) {
    if (r.terlambat > 0) {
      return '${r.terlambat} alat terlambat pemeliharaan';
    }
    if (r.jatuhTempo > 0) {
      return '${r.jatuhTempo} alat jatuh tempo';
    }
    return '${r.menungguVerifikasi} laporan menunggu verifikasi';
  }

  static String _baris(PengingatItem it) {
    final String tempat = it.namaLokasi ?? it.namaKategori ?? '-';
    if (it.terlambat) {
      return '${it.barcodeAlat} • terlambat ${it.terlambatHari} hari • $tempat';
    }
    return '${it.barcodeAlat} • jatuh tempo • $tempat';
  }
}
