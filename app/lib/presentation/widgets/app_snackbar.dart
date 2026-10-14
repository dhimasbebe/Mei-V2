import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Jenis snackbar: sukses (hijau), gagal (merah), info (hitam).
enum AppSnackbarType { sukses, gagal, info }

/// W9 — Snackbar terpadu ber-ikon + aksi lanjutan (I5).
///
/// Pemakaian:
/// ```dart
/// AppSnackbar.show(context, 'Data tersimpan',
///     type: AppSnackbarType.sukses,
///     actionLabel: 'Lihat Riwayat', onAction: () { ... });
/// ```
class AppSnackbar {
  const AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final Color color = switch (type) {
      AppSnackbarType.sukses => AppColors.statusOk,
      AppSnackbarType.gagal => AppColors.statusDanger,
      AppSnackbarType.info => AppColors.black,
    };
    final IconData icon = switch (type) {
      AppSnackbarType.sukses => Icons.check_circle_outline,
      AppSnackbarType.gagal => Icons.error_outline,
      AppSnackbarType.info => Icons.info_outline,
    };

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.background, size: AppSizes.iconSm),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.background),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.background,
                onPressed: onAction ?? () {},
              ),
      ),
    );
  }
}
