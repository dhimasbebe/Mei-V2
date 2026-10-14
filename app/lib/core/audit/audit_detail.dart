/// Pengurai `detail` audit log menjadi baris terbaca — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2
/// & §5.3.
library;

import 'dart:convert';

/// Mengubah JSON string `detail` menjadi daftar baris "kunci: nilai" atau
/// "kunci: lama → baru".
abstract class AuditDetail {
  const AuditDetail._();

  /// Kunci alternatif yang menandai bentuk perubahan (diff) pada sebuah nilai.
  static const String _kunciLama = 'lama';
  static const String _kunciBaru = 'baru';
  static const String _kunciFrom = 'from';
  static const String _kunciTo = 'to';

  /// Panah pemisah nilai lama → baru (spasi di kiri-kanan).
  static const String panah = '→';

  /// Menguraikan [jsonString]:
  ///
  /// * `{"merk_alat":"Daikin"}` → `["merk_alat: Daikin"]` (AC-D5).
  /// * `{"status":{"lama":"menunggu","baru":"disetujui"}}`
  ///   → `["status: menunggu → disetujui"]` (AC-D5).
  /// * Bentuk `{lama, baru}` atau `{from, to}` sama-sama dikenali.
  /// * JSON tidak valid / bukan objek → satu baris berisi teks mentah,
  ///   tanpa melempar exception (AC-D6).
  /// * `null` / string kosong → daftar kosong (tidak ada yang ditampilkan).
  static List<String> format(String? jsonString) {
    final String raw = (jsonString ?? '').trim();
    if (raw.isEmpty) return const <String>[];

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <String>[raw];
    }

    if (decoded is! Map) {
      // Bukan objek (mis. array / angka / string JSON) → teks mentah.
      return <String>[raw];
    }
    if (decoded.isEmpty) return const <String>[];

    final List<String> baris = <String>[];
    decoded.forEach((Object? key, Object? value) {
      baris.add(_baris('$key', value));
    });
    return baris;
  }

  /// Membentuk satu baris dari pasangan kunci–nilai.
  static String _baris(String kunci, Object? value) {
    final String? diff = _diff(value);
    if (diff != null) return '$kunci: $diff';
    return '$kunci: ${_teks(value)}';
  }

  /// Bila [value] adalah map perubahan yang dikenali, kembalikan
  /// `"lama → baru"`; selain itu `null`.
  static String? _diff(Object? value) {
    if (value is! Map) return null;
    final bool punyaLamaBaru =
        value.containsKey(_kunciLama) && value.containsKey(_kunciBaru);
    final bool punyaFromTo =
        value.containsKey(_kunciFrom) && value.containsKey(_kunciTo);
    if (!punyaLamaBaru && !punyaFromTo) return null;

    final Object? lama =
        punyaLamaBaru ? value[_kunciLama] : value[_kunciFrom];
    final Object? baru = punyaLamaBaru ? value[_kunciBaru] : value[_kunciTo];
    return '${_teks(lama)} $panah ${_teks(baru)}';
  }

  /// Representasi teks nilai: string apa adanya; `null` → `"-"`; lainnya
  /// di-encode agar objek/array tetap terbaca satu baris.
  static String _teks(Object? value) {
    if (value == null) return '-';
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return jsonEncode(value);
  }
}
