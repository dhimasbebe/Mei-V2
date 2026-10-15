import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gesture/swipe_action.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';

/// Pembungkus kartu daftar dengan aksi geser (Tahap 3 — WS H, AC-H6/H7).
///
/// Aksi ditentukan tabel pure-Dart [SwipeAction.forRole] sesuai peran & layar:
///  * Supervisor pada `verifikasi` → geser kanan = Setujui, kiri = Tolak.
///  * Admin pada layar data → geser kiri = Hapus (dengan konfirmasi).
///  * Peran lain → kartu tampil apa adanya tanpa `Dismissible`.
///
/// [onAksi] dipanggil HANYA setelah aturan konfirmasi terpenuhi.
class SwipeActionWrapper extends ConsumerWidget {
  const SwipeActionWrapper({
    super.key,
    required this.layar,
    required this.child,
    required this.onAksi,
  });

  /// Nama layar sesuai tabel [SwipeAction] (`verifikasi`, `data`, …).
  final String layar;

  final Widget child;

  /// Dipanggil setelah geser (dan konfirmasi, bila perlu).
  final void Function(SwipeActionType aksi) onAksi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? role = ref.watch(authProvider).user?.roleUsers;
    if (role == null) return child;

    final List<SwipeActionType> aksi = SwipeAction.forRole(role, layar);
    if (aksi.isEmpty) return child;

    final bool bolehSetujui = aksi.contains(SwipeActionType.setujui);
    final bool bolehTolak = aksi.contains(SwipeActionType.tolak);
    final bool bolehHapus = aksi.contains(SwipeActionType.hapus);

    Future<void> jalankan(SwipeActionType a) async {
      if (SwipeAction.confirmRequired(a)) {
        final bool? ya = await _konfirmasi(context, a);
        if (ya != true) return;
      }
      onAksi(a);
    }

    return Dismissible(
      key: ValueKey<String>(
        'swipe-$layar-${identityHashCode(child)}',
      ),
      background: bolehSetujui
          ? _Latar(
              alignment: Alignment.centerLeft,
              warna: AppColors.statusOk,
              ikon: Icons.check,
              label: 'Setujui',
            )
          : null,
      secondaryBackground: bolehTolak
          ? _Latar(
              alignment: Alignment.centerRight,
              warna: AppColors.statusDanger,
              ikon: Icons.close,
              label: 'Tolak',
            )
          : (bolehHapus
              ? _Latar(
                  alignment: Alignment.centerRight,
                  warna: AppColors.statusDanger,
                  ikon: Icons.delete_outline,
                  label: 'Hapus',
                )
              : null),
      confirmDismiss: (DismissDirection arah) async {
        final SwipeActionType a;
        if (arah == DismissDirection.startToEnd && bolehSetujui) {
          a = SwipeActionType.setujui;
        } else if (arah == DismissDirection.endToStart && bolehTolak) {
          a = SwipeActionType.tolak;
        } else if (arah == DismissDirection.endToStart && bolehHapus) {
          a = SwipeActionType.hapus;
        } else {
          return false;
        }

        if (SwipeAction.confirmRequired(a)) {
          final bool? ya = await _konfirmasi(context, a);
          if (ya != true) return false;
        }
        onAksi(a);
        // Kartu tidak dihapus dari daftar — perubahan status ditangani
        // provider (list dimuat ulang). Kembalikan false agar widget utuh.
        return false;
      },
      child: child,
    );
  }

  Future<bool?> _konfirmasi(BuildContext context, SwipeActionType aksi) {
    final String judul = switch (aksi) {
      SwipeActionType.hapus => 'Hapus data ini?',
      SwipeActionType.setujui => 'Setujui laporan ini?',
      SwipeActionType.tolak => 'Tolak laporan ini?',
    };
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(judul),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'YA',
              style: TextStyle(
                color: aksi == SwipeActionType.hapus
                    ? AppColors.statusDanger
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Latar extends StatelessWidget {
  const _Latar({
    required this.alignment,
    required this.warna,
    required this.ikon,
    required this.label,
  });

  final Alignment alignment;
  final Color warna;
  final IconData ikon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ikon, size: AppSizes.iconMd, color: warna),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}
