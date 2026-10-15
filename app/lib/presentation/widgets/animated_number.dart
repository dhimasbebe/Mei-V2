import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Angka yang beranimasi naik dari 0 ke nilai akhir (Tahap 3 — WS F, AC-F6).
///
/// * Nilai non-numerik (mis. `"-"`, `"3 alat"`) ditampilkan apa adanya.
/// * Menghormati *reduce motion*: bila animasi dimatikan pengguna, nilai
///   akhir langsung tampil tanpa animasi.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 400),
    this.suffix = '',
  });

  /// Nilai tampilan; angka (dengan `,`/`.` sebagai desimal) akan dianimasikan.
  final String value;

  /// Gaya teks; bila `null` memakai `textTheme.titleLarge` + warna teks utama.
  final TextStyle? style;

  /// Durasi animasi (default 400 ms — AC-F6).
  final Duration duration;

  /// Teks yang ditempel setelah angka (mis. `"%"`).
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final TextStyle gaya = style ??
        TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: context.pal.textPrimary,
        );

    final double? angka = double.tryParse(value.replaceAll(',', '.'));
    final bool tanpaAnimasi =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (angka == null || tanpaAnimasi) {
      return Text(
        '$value$suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: gaya,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: angka),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? _) {
        final bool bulat = angka == angka.roundToDouble();
        final String tampil = bulat ? v.round().toString() : v.toStringAsFixed(1);
        return Text(
          '$tampil$suffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: gaya,
        );
      },
    );
  }
}
