import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/press_button.dart';
import '../../widgets/role_badge.dart';
import '../../../core/theme/app_palette.dart';

/// Layar 403 — dibuka saat role mencoba mengakses rute di luar haknya.
///
/// Sengaja menampilkan penjelasan dan jalan keluar, bukan layar kosong.
class ForbiddenScreen extends ConsumerWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String role = ref.watch(authProvider).user?.roleUsers ?? '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Image.asset('assets/logos/logoputih.png', height: AppSizes.logoAppBar),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.overdueSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: AppColors.overdue,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Akses ditolak',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.pal.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Halaman ini tidak tersedia untuk peran Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.pal.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              RoleBadge(role: role),
              const SizedBox(height: AppSpacing.xxl),
              PressButton(
                label: 'KEMBALI KE BERANDA',
                icon: Icon(Icons.home_outlined, size: 18),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
