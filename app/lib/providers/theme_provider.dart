import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/theme_mode_codec.dart';

/// Kunci `SharedPreferences` untuk pilihan mode tema (AC-E7).
const String kThemeModeKey = 'meiv.theme_mode';

/// Pemilih tema Terang/Gelap/Sistem (Tahap 3 — WS E).
///
/// Kode tersimpan dinormalisasi [ThemeModeCodec] (modul pure-Dart yang sudah
/// diverifikasi); default `system` mengikuti OS.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    unawaited(_muat());
  }

  Future<void> _muat() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      state = _dariKode(prefs.getString(kThemeModeKey));
    } catch (_) {
      // Gagal membaca: tetap system.
    }
  }

  /// Mengganti mode dan menyimpan pilihannya.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemeModeKey, _keKode(mode));
    } catch (_) {
      // Gagal menyimpan: pilihan tetap berlaku untuk sesi ini.
    }
  }

  static ThemeMode _dariKode(String? kode) => switch (ThemeModeCodec.fromString(kode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _keKode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => ThemeModeCodec.system,
      };
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
    (ref) => ThemeModeNotifier());
