import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/user.dart';
import '../../widgets/role_badge.dart';

/// Header beranda role: sapaan, nama, badge role, dan subjudul kontekstual.
///
/// Dipakai ketiga beranda (Teknisi/Supervisor/Admin) supaya identitas visual
/// seragam, sementara isi halaman tetap berbeda per role.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.user,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final User? user;
  final String subtitle;

  /// Aksi cepat opsional di sisi kanan (mis. tombol scan).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: AppSizes.avatarRadius,
            backgroundColor: Colors.white24,
            child: Text(
              user?.inisial ?? '?',
              style: const TextStyle(
                color: AppColors.background,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Selamat datang,',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.background.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.namaUsers ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    if (user != null) RoleBadge(role: user!.roleUsers),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.background.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
