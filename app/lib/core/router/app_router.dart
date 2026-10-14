import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/dashboard/dashboard_analytics_screen.dart';
import '../../presentation/screens/dashboard/dashboard_overview_screen.dart';
import '../../presentation/screens/dashboard/dashboard_records_screen.dart';
import '../../presentation/screens/data/alat_management_screen.dart';
import '../../presentation/screens/data/data_screen.dart';
import '../../presentation/screens/data/master_data_screen.dart';
import '../../presentation/screens/data/user_management_screen.dart';
import '../../presentation/screens/error/forbidden_screen.dart';
import '../../presentation/screens/home/role_home_screen.dart';
import '../../presentation/screens/maintenance/detail_alat_screen.dart';
import '../../presentation/screens/maintenance/maintenance_form_screen.dart';
import '../../presentation/screens/maintenance/riwayat_screen.dart';
import '../../presentation/screens/maintenance/scan_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/verifikasi/verifikasi_screen.dart';
import '../../presentation/shell/role_shell.dart';
import '../../providers/auth_provider.dart';
import 'route_access.dart';
import 'routes.dart';

/// Konstanta rute dipakai luas oleh layar; diteruskan agar berkas lama yang
/// mengimpor `app_router.dart` tetap bisa memakai `Routes.xxx`.
export 'routes.dart';

/// Helper navigasi (`context.goScan()` dan sejenisnya) juga diteruskan.
export '../../presentation/shell/role_shell.dart' show GoRouterHelper;

/// Router Mei-V2 dengan guard ganda: autentikasi DAN hak akses per role.
///
/// Guard role memakai [RouteAccess]; pelanggaran diarahkan ke `/403` supaya
/// pengguna mendapat penjelasan, bukan dipindahkan diam-diam ke beranda.
final routerProvider = Provider<GoRouter>((ref) {
  final AuthState auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (BuildContext context, GoRouterState state) {
      final bool masuk = auth.isAuthenticated;
      final String lokasi = state.matchedLocation;
      final bool diLogin = lokasi == Routes.login;

      if (!masuk && !diLogin) return Routes.login;
      if (masuk && diLogin) return Routes.home;
      if (!masuk) return null;

      if (!RouteAccess.boleh(auth.user?.roleUsers, lokasi)) {
        return Routes.forbidden;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),

      // Shell navigasi role-aware: satu definisi rute, tab berbeda per role.
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            RoleShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.home,
            builder: (BuildContext context, GoRouterState state) =>
                const RoleHomeScreen(),
          ),
          GoRoute(
            path: Routes.tugas,
            builder: (BuildContext context, GoRouterState state) =>
                const RoleHomeScreen(),
          ),
          GoRoute(
            path: Routes.scan,
            builder: (BuildContext context, GoRouterState state) =>
                const ScanScreen(),
          ),
          GoRoute(
            path: Routes.riwayat,
            builder: (BuildContext context, GoRouterState state) =>
                const RiwayatScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (BuildContext context, GoRouterState state) =>
                const ProfileScreen(),
          ),
          GoRoute(
            path: Routes.verifikasi,
            builder: (BuildContext context, GoRouterState state) =>
                const VerifikasiScreen(),
          ),
          GoRoute(
            path: Routes.data,
            builder: (BuildContext context, GoRouterState state) =>
                const DataScreen(),
          ),
          GoRoute(
            path: Routes.dataUsers,
            builder: (BuildContext context, GoRouterState state) =>
                const UserManagementScreen(),
          ),
          GoRoute(
            path: Routes.dataMaster,
            builder: (BuildContext context, GoRouterState state) =>
                const MasterDataScreen(),
          ),
          GoRoute(
            path: Routes.dataAlat,
            builder: (BuildContext context, GoRouterState state) =>
                const AlatManagementScreen(),
          ),
          GoRoute(
            path: Routes.dashboard,
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardOverviewScreen(),
          ),
          GoRoute(
            path: Routes.dashboardAnalytics,
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardAnalyticsScreen(),
          ),
          GoRoute(
            path: Routes.dashboardRecords,
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardRecordsScreen(),
          ),
        ],
      ),

      // Layar penuh (tanpa shell) — detail alat & form butuh seluruh area.
      GoRoute(
        path: Routes.detailAlat,
        builder: (BuildContext context, GoRouterState state) {
          final String barcode = state.pathParameters['barcode']!;
          return DetailAlatScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: Routes.maintenanceForm,
        builder: (BuildContext context, GoRouterState state) =>
            const MaintenanceFormScreen(),
      ),
      GoRoute(
        path: Routes.forbidden,
        builder: (BuildContext context, GoRouterState state) =>
            const ForbiddenScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Text('Halaman tidak ditemukan: ${state.uri.path}'),
      ),
    ),
  );
});

/// Bridge agar GoRouter bisa mendengarkan perubahan auth state.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
