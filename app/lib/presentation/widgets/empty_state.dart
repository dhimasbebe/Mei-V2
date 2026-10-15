import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import 'press_button.dart';

/// W4 — Empty state informatif (I6/AC-15/AC-39).
///
/// Ikon/ilustrasi + penjelasan + tombol aksi. Bila [illustration] diisi, ia
/// menggantikan [icon]. Bila [actionLabel] dan [onAction] diisi, tombol aksi
/// ditampilkan.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final Widget? illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            illustration ??
                Icon(
                  icon ?? Icons.inbox_outlined,
                  size: AppSizes.iconXl,
                  color: pal.textSecondary,
                ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: pal.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              PressButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
