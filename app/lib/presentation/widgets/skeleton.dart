import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';

/// W5 — Skeleton loading (I3/AC-13/AC-41/AC-47).
///
/// Shimmer dibuat murni dari `AnimationController` + `LinearGradient`
/// (tanpa paket tambahan). Empat kelas disediakan:
///  • [SkeletonBox]      — balok tunggal (width/height/radius)
///  • [SkeletonLine]     — garis teks (default tinggi 12)
///  • [SkeletonCard]     — kartu dengan beberapa garis
///  • [SkeletonListTile] — baris daftar (avatar + dua garis)
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - 2.0 * t, 0),
              end: Alignment(1.0 - 2.0 * t, 0),
              colors: const <Color>[
                AppColors.borderSubtle,
                AppColors.surfaceAlt,
                AppColors.borderSubtle,
              ],
              stops: const <double>[0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Garis teks skeleton.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = AppRadius.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: height, radius: radius);
}

/// Kartu skeleton dengan [lines] baris (baris terakhir lebih pendek).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < lines; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == lines - 1 ? 0.0 : AppSpacing.sm,
              ),
              child: SkeletonLine(
                width: i == lines - 1 ? 160.0 : double.infinity,
                height: i == 0 ? 16.0 : 12.0,
              ),
            ),
        ],
      ),
    );
  }
}

/// Baris daftar skeleton: kotak avatar + dua garis teks.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SkeletonBox(width: 48, height: 48, radius: AppRadius.sm),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonLine(width: double.infinity, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonLine(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
