import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';
import 'skeleton.dart';

/// W11 — Kartu KPI dashboard web (AC-47, I10).
///
/// Saat [loading] menampilkan skeleton. Bila [animate] aktif dan [value]
/// berupa angka, nilai dianimasikan naik dari 0 (opsional P1). [delta] adalah
/// teks perubahan opsional (mis. "+12%").
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.delta,
    this.loading = false,
    this.onTap,
    this.animate = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? delta;
  final bool loading;
  final VoidCallback? onTap;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? AppColors.primary;
    final double? target = double.tryParse(value.replaceAll(',', '.'));

    Widget valueWidget;
    if (loading) {
      valueWidget = const SkeletonBox(width: 88, height: 28);
    } else if (animate && target != null) {
      valueWidget = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: AppDurations.slow,
        curve: AppCurves.standard,
        builder: (BuildContext context, double v, Widget? _) {
          final String shown = target == target.roundToDouble()
              ? v.round().toString()
              : v.toStringAsFixed(1);
          return Text(shown, style: _valueStyle);
        },
      );
    } else {
      valueWidget = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _valueStyle,
      );
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: AppSizes.iconMd, color: accent),
                ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          valueWidget,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _valueStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}
