import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';

/// W1 — Kartu permukaan standar Mei-V.
///
/// Radius default 12 ([AppRadius.md]), garis [AppPalette.divider], elevasi 0
/// (datar) atau 1 (berbayang lembut). Bila [gradient] diisi, latar warna
/// diabaikan. Bila [onTap] diisi, seluruh area kartu dapat ditekan dengan
/// efek ripple.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.elevation = 0,
    this.borderColor,
    this.gradient,
    this.radius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final Color? borderColor;
  final Gradient? gradient;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final double r = radius ?? AppRadius.md;
    final BorderRadius br = BorderRadius.circular(r);
    final Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    final AppPalette pal = context.pal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? pal.surface : null,
        gradient: gradient,
        borderRadius: br,
        border: Border.all(color: borderColor ?? pal.divider),
        boxShadow: elevation > 0 ? AppShadows.card : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: br,
              child: InkWell(
                onTap: onTap,
                borderRadius: br,
                child: content,
              ),
            ),
    );
  }
}
