import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/master_data_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

/// Pusat Data (Admin) — pintu masuk ke manajemen user, master data, dan alat.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(masterKategoriProvider.notifier).load();
      ref.read(masterLokasiProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int jumlahKategori = ref.watch(masterKategoriProvider).jumlah;
    final int jumlahLokasi = ref.watch(masterLokasiProvider).jumlah;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const SectionHeader(
          title: 'Pusat data',
          subtitle: 'Sumber kebenaran seluruh aplikasi',
          icon: Icons.storage_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _Kartu(
          icon: Icons.people_outline,
          warna: AppColors.roleAdmin,
          judul: 'Manajemen User',
          keterangan: 'Tambah, ubah, hapus akun; atur role; reset password.',
          onTap: () => context.go(Routes.dataUsers),
        ),
        const SizedBox(height: AppSpacing.md),
        _Kartu(
          icon: Icons.tune,
          warna: AppColors.roleSupervisor,
          judul: 'Master Data',
          keterangan:
              'Kategori, lokasi, dan checklist pemeliharaan. '
              'Saat ini $jumlahKategori kategori dan $jumlahLokasi lokasi.',
          onTap: () => context.go(Routes.dataMaster),
        ),
        const SizedBox(height: AppSpacing.md),
        _Kartu(
          icon: Icons.qr_code_2,
          warna: AppColors.roleTeknisi,
          judul: 'Manajemen Alat',
          keterangan: 'Daftar alat beserta barcode, kategori, dan lokasinya.',
          onTap: () => context.go(Routes.dataAlat),
        ),
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.icon,
    required this.warna,
    required this.judul,
    required this.keterangan,
    required this.onTap,
  });

  final IconData icon;
  final Color warna;
  final String judul;
  final String keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: warna, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  keterangan,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
            size: AppSizes.iconMd,
          ),
        ],
      ),
    );
  }
}
