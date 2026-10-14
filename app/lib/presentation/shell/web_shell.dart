import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_nav_provider.dart';
import '../widgets/responsive.dart';
import '../widgets/role_badge.dart';

/// Tata letak dashboard web (lebar >= 768): sidebar navigasi + header + konten.
///
/// Dipakai oleh [RoleShell] sehingga daftar menu otomatis mengikuti role:
/// Admin melihat Dashboard/Data/Riwayat/Profil, Supervisor melihat
/// Dashboard/Verifikasi/Riwayat/Profil, Teknisi melihat Tugas/Scan/Riwayat/Profil.
class WebShellLayout extends ConsumerWidget {
  const WebShellLayout({
    super.key,
    required this.nav,
    required this.index,
    required this.user,
    required this.onSelect,
    required this.child,
  });

  final List<RoleNavDestination> nav;
  final int index;
  final User? user;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool expanded = Responsive.sidebarExpanded(context);
    final double sidebarWidth = expanded ? 248 : 84;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Row(
        children: <Widget>[
          _Sidebar(
            width: sidebarWidth,
            expanded: expanded,
            nav: nav,
            index: index,
            user: user,
            onSelect: onSelect,
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                _Header(user: user, title: nav.isEmpty ? 'Mei-V' : nav[index].label),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      expanded ? AppSpacing.xl : AppSpacing.lg,
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.expanded,
    required this.nav,
    required this.index,
    required this.user,
    required this.onSelect,
    required this.onLogout,
  });

  final double width;
  final bool expanded;
  final List<RoleNavDestination> nav;
  final int index;
  final User? user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: AppCurves.standard,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.black,
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Align(
                alignment: expanded ? Alignment.centerLeft : Alignment.center,
                child: Image.asset(
                  'assets/logos/logoputih.png',
                  height: AppSizes.logoAppBar,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                itemCount: nav.length,
                itemBuilder: (BuildContext context, int i) {
                  final RoleNavDestination d = nav[i];
                  final bool aktif = i == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SidebarItem(
                      destination: d,
                      aktif: aktif,
                      expanded: expanded,
                      onTap: () => onSelect(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF2B2B2B), height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user?.inisial ?? '?',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (expanded) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user?.namaUsers ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.background,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            user?.roleUsers ?? '-',
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Keluar',
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout,
                        color: Color(0xFFBDBDBD),
                        size: AppSizes.iconSm,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.aktif,
    required this.expanded,
    required this.onTap,
  });

  final RoleNavDestination destination;
  final bool aktif;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color warna = aktif ? AppColors.background : const Color(0xFFBDBDBD);

    return Material(
      color: aktif ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: <Widget>[
              Icon(aktif ? destination.activeIcon : destination.icon, color: warna),
              if (expanded) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: warna,
                      fontSize: 14,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.title});

  final User? user;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (user != null) ...<Widget>[
            RoleBadge(role: user!.roleUsers),
            const SizedBox(width: AppSpacing.md),
            Text(
              user!.namaUsers,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.md),
          Image.asset(
            'assets/logos/logotelpro.png',
            height: AppSizes.logoTelproFooter,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
