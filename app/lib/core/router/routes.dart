/// Nama rute Mei-V2 (deep linking friendly).
///
/// Dipisah dari `app_router.dart` supaya lapisan navigasi (provider
/// `role_nav_provider`, `role_shell`) bisa memakai konstanta ini tanpa
/// menimbulkan impor melingkar: `app_router.dart` mengimpor shell, shell
/// mengimpor daftar rute, dan daftar rute tidak mengimpor apa pun.
///
/// `app_router.dart` melakukan `export` berkas ini sehingga kode lama yang
/// menulis `import '.../app_router.dart';` lalu memakai `Routes.xxx` tetap
/// berjalan tanpa perubahan.
abstract class Routes {
  static const String login = '/login';

  /// Beranda role — isinya ditentukan oleh role pengguna (lihat `RoleShell`).
  static const String home = '/';
  static const String tugas = '/tugas';
  static const String scan = '/scan';

  /// Patroli scan berkelanjutan (Teknisi — Tahap 3 WS I).
  static const String patrol = '/patroli';
  static const String riwayat = '/riwayat';
  static const String profile = '/profil';

  /// Antrean sinkronisasi offline (draf menunggu kirim — Tahap 3 §5.1).
  static const String sinkron = '/sinkron';

  /// Riwayat audit log (Admin & Supervisor — Tahap 3 WS D).
  static const String auditLog = '/audit-log';

  /// Supervisor & Admin.
  static const String verifikasi = '/verifikasi';

  /// Admin — pusat data (user, master data, alat).
  static const String data = '/data';
  static const String dataUsers = '/data/users';
  static const String dataMaster = '/data/master';
  static const String dataAlat = '/data/alat';

  /// Admin — impor massal alat dari CSV (WS M, Fitur Tahap 3).
  ///
  /// Sengaja DI LUAR prefiks `/data/alat`: `RouteAccess._cocok` memberi Teknisi
  /// akses ke seluruh `/data/alat/...`, sehingga rute impor di bawah prefiks itu
  /// akan ikut terbuka bagi Teknisi. Endpoint backend-nya Admin-only.
  static const String alatImpor = '/impor-alat';

  /// Dashboard web (Supervisor & Admin).
  static const String dashboard = '/dashboard';
  static const String dashboardAnalytics = '/dashboard/analytics';
  static const String dashboardRecords = '/dashboard/records';

  /// Daftar alat melewati siklus pemeliharaan (AC-G6: kartu "Terlambat").
  static const String dashboardOverdue = '/dashboard/overdue';

  /// Layar penuh (di luar shell navigasi).
  static const String detailAlat = '/alat/:barcode';
  static const String maintenanceForm = '/maintenance/form';
  static const String forbidden = '/403';

  /// Awalan path detail alat — dipakai tabel akses rute (bukan pola `:barcode`).
  static const String alatPrefix = '/alat';

  static String alat(String barcode) => '/alat/$barcode';
}
