/// Codec string untuk preferensi mode tema — **Dart murni**.
///
/// Menyembunyikan perbedaan antara nilai yang disimpan (`shared_preferences`)
/// dan nilai yang dipakai UI. TIDAK mengimpor `package:flutter`.
/// Lihat `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.4.
library;

/// Normalisasi kode mode tema ke salah satu dari `light` / `dark` / `system`.
abstract class ThemeModeCodec {
  const ThemeModeCodec._();

  /// Kode default saat nilai tidak dikenal / `null`.
  static const String system = 'system';

  /// Kode yang dianggap valid.
  static const Set<String> valid = <String>{'light', 'dark', system};

  /// Membaca kode tersimpan menjadi kode kanonik.
  ///
  /// `null`, string kosong, atau nilai tak dikenal → [system] (AC-E5).
  static String fromString(String? raw) {
    final String kode = (raw ?? '').trim().toLowerCase();
    return valid.contains(kode) ? kode : system;
  }

  /// Menormalkan kode sebelum disimpan (round-trip stabil — AC-E5).
  static String toStorage(String code) => fromString(code);
}
