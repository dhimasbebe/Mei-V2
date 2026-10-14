/// Spesifikasi palet ARGB untuk mode terang & gelap — **Dart murni**.
///
/// Satu sumber kebenaran untuk nilai warna permukaan/teks. `AppPalette`
/// (lapisan Flutter, `core/theme/app_palette.dart`) hanya **membaca** nilai di
/// sini, jadi tidak ada duplikasi. Modul ini TIDAK mengimpor `package:flutter`
/// (hanya `dart:math` dari pustaka inti).
/// Lihat `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.4.
library;

import 'dart:math' as math;

/// Pilihan tema yang dipakai [PaletteSpec].
enum PaletteTheme { light, dark }

/// Nilai inti (ARGB) token permukaan/teks untuk kedua tema.
///
/// Aturan mengikat: token brand (`primary`) **konstan** di kedua tema.
abstract class PaletteSpec {
  const PaletteSpec._();

  /// Palet mode terang — nilainya identik dengan `AppColors` lama (fallback).
  static const Map<String, int> light = <String, int>{
    'background': 0xFFFFFFFF,
    'surface': 0xFFFFFFFF,
    'surfaceAlt': 0xFFF5F6FA,
    'surfaceMuted': 0xFFF4F4F4,
    'textPrimary': 0xFF1A1A1A,
    'textSecondary': 0xFF6B6B6B,
    'divider': 0xFFE0E0E0,
    'borderSubtle': 0xFFEEEEEE,
    'fieldDark': 0xFF2B2B2B,
    'shadowColor': 0x14000000,
    'primary': 0xFFCB2400,
  };

  /// Palet mode gelap — varian gelap baru; `primary` tetap sama.
  static const Map<String, int> dark = <String, int>{
    'background': 0xFF121212,
    'surface': 0xFF1E1E1E,
    'surfaceAlt': 0xFF181818,
    'surfaceMuted': 0xFF2A2A2A,
    'textPrimary': 0xFFEDEDED,
    'textSecondary': 0xFFAFAFAF,
    'divider': 0xFF2E2E2E,
    'borderSubtle': 0xFF262626,
    'fieldDark': 0xFF2B2B2B,
    'shadowColor': 0x40000000,
    'primary': 0xFFCB2400,
  };

  /// Seluruh nama token yang dikenal [value].
  static const Set<String> tokens = <String>{
    'background',
    'surface',
    'surfaceAlt',
    'surfaceMuted',
    'textPrimary',
    'textSecondary',
    'divider',
    'borderSubtle',
    'fieldDark',
    'shadowColor',
    'primary',
  };

  /// Nilai ARGB token [token] untuk [theme]. Token tak dikenal → `0x00000000`.
  static int value(PaletteTheme theme, String token) {
    final Map<String, int> palet = theme == PaletteTheme.dark ? dark : light;
    return palet[token] ?? 0x00000000;
  }

  /// Rasio kontras WCAG 2.1 antara dua warna ARGB, dihitung murni (AC-E4).
  ///
  /// Rentang hasil `1.0` (identik) … `21.0` (hitam vs putih). Formula resmi:
  /// `(L1 + 0.05) / (L2 + 0.05)` dengan `L` = luminansi relatif.
  static double contrastRatio(int argbA, int argbB) {
    final double la = _relativeLuminance(argbA);
    final double lb = _relativeLuminance(argbB);
    final double terang = math.max(la, lb);
    final double gelap = math.min(la, lb);
    return (terang + 0.05) / (gelap + 0.05);
  }

  /// Luminansi relatif WCAG dari warna ARGB (0.0 … 1.0).
  static double _relativeLuminance(int argb) {
    final double r = _kanal((argb >> 16) & 0xFF);
    final double g = _kanal((argb >> 8) & 0xFF);
    final double b = _kanal(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Konversi satu kanal 0..255 ke komponen linier sRGB.
  static double _kanal(int c) {
    final double s = c / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
}
