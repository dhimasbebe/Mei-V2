import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_nav_provider.dart';
import '../../providers/notif_provider.dart';
import '../../providers/verifikasi_provider.dart';
import '../widgets/responsive.dart';
import '../widgets/role_badge.dart';
import 'web_shell.dart';

/// Shell navigasi Mei-V2 — kerangka bersama untuk beranda tiap role.
///
/// Tab yang tampil berasal dari [roleNavProvider], jadi Admin, Supervisor, dan
/// Teknisi benar-benar memakai navigasi berbeda (bukan sekadar ganti label).
/// Pada lebar >= 768 shell beralih ke tata letak sidebar ([WebShellLayout])
/// sehingga berkas ini melayani aplikasi mobile dan dashboard web sekaligus.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RoleNavDestination> nav = ref.watch(roleNavProvider);
    final AuthState auth = ref.watch(authProvider);
    final User? user = auth.user;

    final String location = GoRouterState.of(context).uri.path;
    final int index = RoleNav.indexFor(nav, location);

    if (Responsive.useSidebar(context)) {
      return WebShellLayout(
        nav: nav,
        index: index,
        user: user,
        onSelect: (int i) => context.go(nav[i].path),
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: <Widget>[
            Image.asset('assets/logos/logoputih.png', height: AppSizes.logoAppBar),
            const SizedBox(width: AppSpacing.md),
            Text(
              nav.isEmpty ? '' : nav[index].label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.background,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Center(child: RoleBadge(role: user.roleUsers)),
            ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, size: AppSizes.iconMd),
            onPressed: () => _konfirmasiKeluar(context, ref),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int i) => context.go(nav[i].path),
        height: AppSizes.bottomNavHeight,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: nav.map((RoleNavDestination d) {
          final Widget icon = Icon(d.icon);
          final Widget activeIcon = Icon(d.activeIcon, color: AppColors.primary);
          return NavigationDestination(
            icon: _beriBadge(ref, d, icon),
            selectedIcon: _beriBadge(ref, d, activeIcon),
            label: d.label,
            tooltip: d.label,
          );
        }).toList(),
      ),
    );
  }

  /// Bungkus ikon dengan badge angka bila tab meminta (mis. antrean verifikasi).
  Widget _beriBadge(WidgetRef ref, RoleNavDestination d, Widget icon) {
    if (d.badge == RoleNavBadge.none) return icon;

    final int jumlah = jumlahBadge(ref, d.badge);
    if (jumlah <= 0) return icon;

    return Badge(
      label: Text(jumlah > 99 ? '99+' : '$jumlah'),
      backgroundColor: AppColors.primary,
      child: icon,
    );
  }
}

/// Konfirmasi keluar — mencegah sentuhan tak sengaja pada ikon di app bar.
Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
  final bool? ya = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Keluar dari Mei-V?'),
      content: const Text('Anda perlu masuk kembali untuk memakai aplikasi.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('BATAL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('KELUAR'),
        ),
      ],
    ),
  );

  if (ya ?? false) {
    await ref.read(authProvider.notifier).logout();
  }
}

/// Helper navigasi Mei-V2.
extension GoRouterHelper on BuildContext {
  void goHome() => go(Routes.home);
  void goTugas() => go(Routes.tugas);
  void goScan() => go(Routes.scan);
  void goAlat(String barcode) => go(Routes.alat(barcode));
  void goMaintenanceForm() => push(Routes.maintenanceForm);
  void goRiwayat() => go(Routes.riwayat);
  void goProfile() => go(Routes.profile);
  void goVerifikasi() => go(Routes.verifikasi);
  void goData() => go(Routes.data);
  void goDashboard() => go(Routes.dashboard);
  void goLogin() => go(Routes.login);
}
