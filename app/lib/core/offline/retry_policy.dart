/// Kebijakan backoff eksponensial untuk antrean sinkron offline.
///
/// Modul **Dart murni** — tanpa `package:flutter`. Lihat
/// `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.1.
library;

/// Perhitungan jeda antar percobaan kirim ulang draf.
///
/// Pola: `base * 2^attempt` dibatasi pada [max], jadi
/// `attempt 0..n → 5s, 10s, 20s, 40s, 60s, 60s, …` (AC-A11).
abstract class RetryPolicy {
  const RetryPolicy._();

  /// Jeda dasar percobaan pertama.
  static const Duration base = Duration(seconds: 5);

  /// Batas atas jeda; hasil [nextDelay] tidak pernah melebihi nilai ini.
  static const Duration max = Duration(seconds: 60);

  /// Jeda sebelum percobaan ke-`attempt` (0-based).
  ///
  /// `attempt < 0` diperlakukan seperti 0. Hasil selalu berada di rentang
  /// `[base, max]` sehingga tidak pernah melebihi batas atas (AC-A11).
  static Duration nextDelay(int attempt) {
    final int a = attempt < 0 ? 0 : attempt;
    // Geser bit dibatasi agar tidak meluap untuk `attempt` besar.
    final int shifted = a >= 32 ? max.inMilliseconds : (1 << a);
    final int ms = base.inMilliseconds * shifted;
    return Duration(milliseconds: ms.clamp(base.inMilliseconds, max.inMilliseconds));
  }
}
