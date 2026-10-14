import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
    final Color fg = variant == AppButtonVariant.filled ? AppColors.background : AppColors.primary;
    final Color bg = variant == AppButtonVariant.filled ? AppColors.primary : AppColors.background;
    final Color border = variant == AppButtonVariant.outline ? AppColors.primary : Colors.transparent;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        minimumSize: const Size(double.infinity, AppSizes.touchTarget),
        shape: const StadiumBorder(),
        side: BorderSide(color: border, width: 1.5),
        elevation: variant == AppButtonVariant.filled ? 2 : 0,
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
