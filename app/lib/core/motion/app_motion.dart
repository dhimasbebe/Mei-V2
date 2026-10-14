/// Durasi & kurva animasi bersama — **Dart murni**.
///
/// Hanya angka; kurva nyata (`Curves.*`) dipetakan di lapisan UI. TIDAK
/// mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.
library;

/// Durasi transisi per halaman, dijamin dalam rentang 200–300 ms (AC-F2).
abstract class AppMotion {
  const AppMotion._();

  /// Durasi (ms) transisi masuk halaman, per `pageId`.
  static const Map<String, int> durations = <String, int>{
    'home': 250,
    'detail': 250,
    'form': 250,
    'riwayat': 220,
    'verifikasi': 220,
    'dashboard': 260,
    'profile': 200,
    'audit': 240,
  };

  /// Batas bawah rentang durasi yang diizinkan (ms).
  static const int minMs = 200;

  /// Batas atas rentang durasi yang diizinkan (ms).
  static const int maxMs = 300;

  /// Durasi transisi default bila `pageId` tak dikenal.
  static const int defaultMs = 250;

  /// Durasi (ms) transisi untuk [pageId], selalu di-clamp ke `[minMs, maxMs]`
  /// sehingga hasilnya dijamin 200–300 ms (AC-F2).
  static int transitionMs(String pageId) {
    final int raw = durations[pageId] ?? defaultMs;
    return raw.clamp(minMs, maxMs);
  }

  /// `true` bila [pageId] terdaftar pada tabel durasi.
  static bool dikenal(String pageId) => durations.containsKey(pageId);
}
