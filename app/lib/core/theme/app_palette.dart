/// `AppPalette` — ThemeExtension warna permukaan/teks dua mode (Tahap 3 WS E).
///
/// Hanya **membaca** nilai ARGB dari `PaletteSpec` (modul pure-Dart yang sudah
/// diverifikasi `tools/modelcheck`) — tidak ada duplikasi nilai. Token brand
/// (`primary`) tetap konstan di kedua mode; warna brand lain tetap di
/// `AppColors` (fallback tidak dihapus).
///
/// Pemakaian: `context.pal.background`, `context.pal.textPrimary`, dst.
/// Lihat `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.4.
library;

import 'package:flutter/material.dart';

import 'app_palette_spec.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.borderSubtle,
    required this.fieldDark,
    required this.shadowColor,
    required this.primary,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color borderSubtle;
  final Color fieldDark;
  final Color shadowColor;

  /// Brand — konstan di kedua mode (AC-E2/E3, sumber: `PaletteSpec`).
  final Color primary;

  static Color _warna(PaletteTheme t, String token) =>
      Color(PaletteSpec.value(t, token));

  /// Palet mode terang — identik dengan fallback `AppColors`.
  factory AppPalette.light() => AppPalette.dari(PaletteTheme.light);

  /// Palet mode gelap.
  factory AppPalette.dark() => AppPalette.dari(PaletteTheme.dark);

  /// Bentuk yang dipakai `ThemeData.extensions` (terpasang per mode).
  ///
  /// Semua nilai dibaca dari `PaletteSpec` — satu sumber kebenaran.
  static AppPalette dari(PaletteTheme t) => AppPalette(
        background: _warna(t, 'background'),
        surface: _warna(t, 'surface'),
        surfaceAlt: _warna(t, 'surfaceAlt'),
        surfaceMuted: _warna(t, 'surfaceMuted'),
        textPrimary: _warna(t, 'textPrimary'),
        textSecondary: _warna(t, 'textSecondary'),
        divider: _warna(t, 'divider'),
        borderSubtle: _warna(t, 'borderSubtle'),
        fieldDark: _warna(t, 'fieldDark'),
        shadowColor: _warna(t, 'shadowColor'),
        primary: _warna(t, 'primary'),
      );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? borderSubtle,
    Color? fieldDark,
    Color? shadowColor,
    Color? primary,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      fieldDark: fieldDark ?? this.fieldDark,
      shadowColor: shadowColor ?? this.shadowColor,
      primary: primary ?? this.primary,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color? campur(Color a, Color b) => Color.lerp(a, b, t);
    return AppPalette(
      background: campur(background, other.background)!,
      surface: campur(surface, other.surface)!,
      surfaceAlt: campur(surfaceAlt, other.surfaceAlt)!,
      surfaceMuted: campur(surfaceMuted, other.surfaceMuted)!,
      textPrimary: campur(textPrimary, other.textPrimary)!,
      textSecondary: campur(textSecondary, other.textSecondary)!,
      divider: campur(divider, other.divider)!,
      borderSubtle: campur(borderSubtle, other.borderSubtle)!,
      fieldDark: campur(fieldDark, other.fieldDark)!,
      shadowColor: campur(shadowColor, other.shadowColor)!,
      primary: campur(primary, other.primary)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppPalette &&
        other.background == background &&
        other.surface == surface &&
        other.surfaceAlt == surfaceAlt &&
        other.surfaceMuted == surfaceMuted &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.divider == divider &&
        other.borderSubtle == borderSubtle &&
        other.fieldDark == fieldDark &&
        other.shadowColor == shadowColor &&
        other.primary == primary;
  }

  @override
  int get hashCode => Object.hash(background, surface, surfaceAlt, surfaceMuted,
      textPrimary, textSecondary, divider, borderSubtle, fieldDark, shadowColor,
      primary);

  @override
  String toString() => 'AppPalette(bg: $background, surface: $surface)';
}

extension AppPaletteX on BuildContext {
  /// Palet aktif dari tema; fallback light bila extension belum terpasang.
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light();
}
