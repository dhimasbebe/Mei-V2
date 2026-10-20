import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale/locale_codec.dart';

/// Bahasa antarmuka aplikasi (Tahap 3 — WS P).
///
/// Pilihan disimpan di `shared_preferences` dengan kunci
/// [LocaleCodec.storageKey]; bila belum pernah memilih atau penyimpanan gagal
/// dibaca, aplikasi tampil dalam bahasa Indonesia (AC-P2). Kegagalan plugin
/// tidak pernah membuat UI crash (pola sama dengan `notifPrefsProvider`).
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(LocaleCodec.bawaan) {
    unawaited(muat());
  }

  /// Membaca preferensi tersimpan (AC-P4).
  ///
  /// Dipanggil otomatis saat provider dibuat; aman dipanggil ulang.
  Future<void> muat() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppLocale locale =
          LocaleCodec.fromKode(prefs.getString(LocaleCodec.storageKey));
      if (!mounted) return;
      state = locale;
    } catch (error) {
      // Preferensi tidak terbaca: tetap bahasa bawaan (Indonesia).
      debugPrint(
        'Mei-V: gagal membaca preferensi bahasa ($error) — memakai '
        '${LocaleCodec.keKode(LocaleCodec.bawaan)}.',
      );
    }
  }

  /// Mengganti bahasa aktif lalu menyimpannya (AC-P4).
  ///
  /// Alias eksplisit dari [ubah] agar pemanggil dapat memakai nama yang
  /// paling terbaca di layarnya.
  Future<void> set(AppLocale locale) => ubah(locale);

  /// Mengubah bahasa: UI langsung berubah, penyimpanan menyusul.
  ///
  /// Bila penyimpanan gagal, pilihan tetap berlaku untuk sesi ini — pengguna
  /// tidak melihat galat dan tidak kehilangan sesi.
  Future<void> ubah(AppLocale locale) async {
    if (state != locale) {
      state = locale;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocaleCodec.storageKey,
        LocaleCodec.keKode(locale),
      );
    } catch (error) {
      debugPrint(
        'Mei-V: gagal menyimpan preferensi bahasa ($error) — pilihan '
        '${LocaleCodec.keKode(locale)} tetap berlaku untuk sesi ini.',
      );
    }
  }
}

/// Bahasa aktif aplikasi; dibaca `main.dart` / `main_web.dart` untuk mengisi
/// `MaterialApp.locale` dan oleh layar lewat `Teks`.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>(
  (ref) => LocaleNotifier(),
);
