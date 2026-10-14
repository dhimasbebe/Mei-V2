import 'routes.dart';

/// Tabel akses rute per role — dipakai guard `redirect` di `app_router.dart`.
///
/// Prinsip: hak akses paling sempit untuk role tak dikenal, dan pelanggaran
/// diarahkan ke `/403` (bukan diam-diam dipindahkan ke beranda) supaya
/// pengguna tahu mengapa halaman tidak terbuka.
abstract class RouteAccess {
  const RouteAccess._();

  /// Rute yang boleh dibuka siapa pun (termasuk yang belum masuk).
  static const List<String> publik = <String>[Routes.login, Routes.forbidden];

  /// True bila [role] boleh membuka [location].
  static bool boleh(String? role, String location) {
    if (publik.contains(location)) return true;

    switch ((role ?? '').trim().toLowerCase()) {
      case 'admin':
        // Admin mengelola seluruh sistem.
        return true;

      case 'supervisor':
        return _cocok(location, Routes.home) ||
            _cocok(location, Routes.dashboard) ||
            _cocok(location, Routes.verifikasi) ||
            _cocok(location, Routes.riwayat) ||
            _cocok(location, Routes.profile) ||
            _cocok(location, Routes.alatPrefix) ||
            _cocok(location, Routes.sinkron);

      case 'teknisi':
      default:
        // Teknisi: hanya pekerjaan lapangan miliknya.
        return _cocok(location, Routes.home) ||
            _cocok(location, Routes.tugas) ||
            _cocok(location, Routes.scan) ||
            _cocok(location, Routes.riwayat) ||
            _cocok(location, Routes.profile) ||
            _cocok(location, Routes.alatPrefix) ||
            _cocok(location, Routes.maintenanceForm) ||
            _cocok(location, Routes.sinkron);
    }
  }

  /// True bila [location] sama dengan [base] atau berada di bawahnya.
  ///
  /// `/` hanya cocok persis supaya tidak menelan seluruh aplikasi.
  static bool _cocok(String location, String base) {
    if (base == Routes.home) return location == Routes.home;
    return location == base || location.startsWith('$base/');
  }
}
