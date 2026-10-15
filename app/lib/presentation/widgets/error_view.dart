import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import 'press_button.dart';

/// W12 — Error state dengan aksi "Coba Lagi" (I7/AC-47).
///
/// Dipakai di setiap `when(error:)` agar selalu ada jalur keluar. [compact]
/// memakai ikon lebih kecil untuk area sempit (mis. di dalam kartu).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: compact ? AppSizes.iconLg : AppSizes.iconXl,
              color: AppColors.statusDanger,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 13.0 : 14.0,
                color: pal.textSecondary,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              PressButton(
                label: AppStrings.labelCobaLagi,
                icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
