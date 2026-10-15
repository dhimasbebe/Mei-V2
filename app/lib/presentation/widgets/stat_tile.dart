import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import 'animated_number.dart';
import 'app_card.dart';
import 'skeleton.dart';

/// W2 — Tile statistik mikro (jumlah tugas, overdue milik sendiri, teknisi aktif).
///
/// Dipakai di beranda tiga role. Saat [loading] menampilkan skeleton alih-alih
/// angka polos (I3). [trend] adalah teks kecil opsional (mis. "+2", "-12%").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    this.loading = false,
    this.trend,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool loading;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    final Color accent = color ?? AppColors.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: AppSizes.iconSm, color: accent),
                ),
              const Spacer(),
              if (trend != null)
                Text(
                  trend!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const SkeletonBox(width: 64, height: 24)
          else
            // AC-F6: angka beranimasi naik dari 0 saat kartu pertama tampil.
            AnimatedNumber(
              value: value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
