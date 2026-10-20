import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';

/// Tombol utama gaya Mei-V: pill-shaped, warna merah / hitam / outline.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final bool filled = variant == AppButtonVariant.filled;
    final bool outline = variant == AppButtonVariant.outline;

    final Color fg = filled ? AppColors.background : AppColors.primary;

    // Latar mengikuti peran varian. `outline` sengaja TRANSPARAN agar
    // permukaan halaman yang tampil — sebelumnya putih solid, sehingga di
    // mode gelap tampak seperti slab putih dengan teks merah.
    final Color bg = switch (variant) {
      AppButtonVariant.filled => AppColors.primary,
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.dark => AppColors.background,
    };

    // Status nonaktif memakai aturan latar yang SAMA (bukan selalu pink 50%
    // yang menimpa varian outline), dengan teks redup yang tetap terbaca di
    // kedua tema.
    final Color bgDisabled = switch (variant) {
      AppButtonVariant.filled => AppColors.primary.withValues(alpha: 0.5),
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.dark => AppColors.background.withValues(alpha: 0.6),
    };
    final Color fgDisabled =
        filled ? AppColors.background : context.pal.textSecondary;

    final Color border = outline ? AppColors.primary : Colors.transparent;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        disabledBackgroundColor: bgDisabled,
        disabledForegroundColor: fgDisabled,
        minimumSize: const Size(double.infinity, AppSizes.touchTarget),
        shape: const StadiumBorder(),
        side: BorderSide(color: border, width: 1.5),
        elevation: filled ? 2 : 0,
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[icon!, const SizedBox(width: AppSpacing.sm)],
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}

enum AppButtonVariant { filled, outline, dark }
