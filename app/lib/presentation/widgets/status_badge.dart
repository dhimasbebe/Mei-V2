import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// W7 — Badge status (overdue/tepat waktu AC-29, kondisi, verifikasi).
///
/// [color] warna teks/ikon utama; [softColor] latar (default = [color] dengan
/// alpha 0.12). [dense] memakai tinggi & font lebih kecil untuk tabel.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.softColor,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final Color? softColor;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color solid = color ?? AppColors.textSecondary;
    final Color bg = softColor ?? solid.withValues(alpha: 0.12);
    final double h = dense ? 20.0 : 26.0;
    final double fontSize = dense ? 11.0 : 12.0;
    final double iconSize = dense ? 12.0 : 14.0;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: dense ? AppSpacing.sm : 10.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: iconSize, color: solid),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: solid,
            ),
          ),
        ],
      ),
    );
  }
}
