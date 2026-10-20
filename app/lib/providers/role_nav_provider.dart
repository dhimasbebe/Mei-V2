import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/router/routes.dart';
import 'auth_provider.dart';
import 'notif_provider.dart';
import 'verifikasi_provider.dart';

/// Satu tujuan navigasi pada shell role.
@immutable
class RoleNavDestination {
  const RoleNavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
    this.badge = RoleNavBadge.none,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  /// Sumber angka badge pada tab (mis. jumlah antrean verifikasi).
  final RoleNavBadge badge;
}

/// Jenis badge yang boleh dipasang pada tab.
enum RoleNavBadge {
  none,

  /// Jumlah maintenance yang menunggu verifikasi (Supervisor / Admin).
  menungguVerifikasi,

  /// Alat jatuh tempo/terlambat + draf offline (Teknisi) — WS B AC-B7.
  pengingatAlat,
}

/// Definisi tab per role.
///
/// Tiga role memang memakai tab yang berbeda — ini inti permintaan pengguna
/// ("pastikan tampilan setiap role berbeda"), bukan sekadar ganti label:
///  * Teknisi    — fokus kerja lapangan: Tugas, Scan, Riwayat, Profil.
///  * Supervisor — fokus pengawasan: Dashboard, Verifikasi, Riwayat, Profil.
///  * Admin      — fokus pengelolaan: Dashboard, Data, Riwayat, Profil.
abstract class RoleNav {
  static const List<RoleNavDestination> teknisi = <RoleNavDestination>[
    RoleNavDestination(
      label: 'Tugas',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      path: Routes.tugas,
      badge: RoleNavBadge.pengingatAlat,
    ),
    RoleNavDestination(
      label: 'Scan',
      icon: Icons.qr_code_scanner_outlined,
      activeIcon: Icons.qr_code_scanner,
      path: Routes.scan,
    ),
    RoleNavDestination(
      label: 'Patroli',
      icon: Icons.playlist_add_outlined,
      activeIcon: Icons.playlist_add_check,
      path: Routes.patrol,
    ),
    RoleNavDestination(
      label: 'Riwayat',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      path: Routes.riwayat,
    ),
    RoleNavDestination(
      label: 'Profil',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      path: Routes.profile,
    ),
  ];

  static const List<RoleNavDestination> supervisor = <RoleNavDestination>[
    RoleNavDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      path: Routes.home,
    ),
    RoleNavDestination(
      label: 'Verifikasi',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check,
      path: Routes.verifikasi,
      badge: RoleNavBadge.menungguVerifikasi,
    ),
    RoleNavDestination(
      label: 'Riwayat',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      path: Routes.riwayat,
    ),
    RoleNavDestination(
      label: 'Profil',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      path: Routes.profile,
    ),
  ];

  static const List<RoleNavDestination> admin = <RoleNavDestination>[
    RoleNavDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      path: Routes.home,
    ),
    RoleNavDestination(
      label: 'Data',
      icon: Icons.storage_outlined,
      activeIcon: Icons.storage,
      path: Routes.data,
    ),
    RoleNavDestination(
      label: 'Riwayat',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      path: Routes.riwayat,
    ),
    RoleNavDestination(
      label: 'Profil',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      path: Routes.profile,
    ),
  ];

  /// Tab untuk sebuah role. Role tak dikenal diperlakukan sebagai Teknisi
  /// (hak akses paling sempit) supaya tidak pernah menaikkan hak akses.
  static List<RoleNavDestination> forRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'admin':
        return admin;
      case 'supervisor':
        return supervisor;
      case 'teknisi':
      default:
        return teknisi;
    }
  }

  /// Indeks tab yang cocok dengan [location] (hasil `GoRouterState.uri.path`).
  ///
  /// Pencocokan memakai awalan terpanjang supaya `/data/users` tetap
  /// menyorot tab `/data`, dan `/dashboard/analytics` menyorot `/dashboard`.
  static int indexFor(List<RoleNavDestination> nav, String location) {
    int best = -1;
    int bestLength = -1;
    for (int i = 0; i < nav.length; i++) {
      final String path = nav[i].path;
      final bool cocok = path == Routes.home
          ? location == Routes.home
          : (location == path || location.startsWith('$path/'));
      if (cocok && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    if (best >= 0) return best;

    // Beranda role berada di beberapa path; pilih tab pertama sebagai
    // fallback supaya NavigationBar tidak pernah kehilangan seleksi.
    return 0;
  }

  /// True bila [location] adalah salah satu beranda role.
  static bool isHomeLocation(String location) =>
      location == Routes.home ||
      location == Routes.tugas ||
      location == Routes.verifikasi ||
      location == Routes.data;
}

/// Tab aktif sesuai role pengguna yang sedang login.
final roleNavProvider = Provider<List<RoleNavDestination>>((ref) {
  final String? role = ref.watch(authProvider).user?.roleUsers;
  return RoleNav.forRole(role);
});

/// Jumlah badge untuk [badge] pada tab/sidebar (dipakai shell mobile & web).
///
/// Satu tempat agar lencana mobile ([RoleShell]) dan sidebar web
/// ([WebShellLayout]) selalu konsisten (AC-B7).
int jumlahBadge(WidgetRef ref, RoleNavBadge badge) => switch (badge) {
      RoleNavBadge.menungguVerifikasi =>
        ref.watch(pendingVerifikasiCountProvider),
      RoleNavBadge.pengingatAlat => ref.watch(badgeTugasTeknisiProvider),
      RoleNavBadge.none => 0,
    };
