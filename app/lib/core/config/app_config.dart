/// Konfigurasi aplikasi Mei-V.
///
/// Base URL diambil dari `--dart-define` supaya satu basis kode bisa dipakai
/// untuk dev / staging / produksi tanpa mengubah kode.
///
/// Contoh menjalankan:
///   flutter run --dart-define=API_BASE_URL=https://api.meiv.example/api/v1
///   flutter build web --dart-define=API_BASE_URL=https://api.meiv.example/api/v1
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Versi API yang dipakai klien. Server wajib menjaga kompatibilitas
  /// versi lama karena aplikasi di HP teknisi tidak selalu ikut ter-update.
  static const String apiVersion = 'v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Ambang default bila kategori belum punya siklus sendiri (hari).
  static const int defaultMaintenanceCycleDays = 30;

  static const bool isWeb = bool.fromEnvironment('dart.library.js_util');
}
