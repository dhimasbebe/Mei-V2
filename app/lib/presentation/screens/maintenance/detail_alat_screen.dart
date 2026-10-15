import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/alat.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_scaffold.dart';
import '../../../core/theme/app_palette.dart';

/// Layar Detail Alat setelah scan / pencarian.
/// Menampilkan: Kode Alat, Merk Alat, Detail Lokasi, status overdue.
class DetailAlatScreen extends ConsumerWidget {
  const DetailAlatScreen({super.key, required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alatAsync = ref.watch(alatByBarcodeProvider(barcode));

    return AppScaffold(
      useRedAppBar: true,
      title: 'Detail Alat',
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => context.goHome(),
      ),
      body: alatAsync.when(
        data: (Alat alat) => _DetailBody(alat: alat),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.error_outline, color: AppColors.primary, size: 48),
              const SizedBox(height: 12),
              Text('Barcode tidak ditemukan.\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'Scan Ulang',
                onPressed: () => context.goScan(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.alat});

  final Alat alat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOverdue = alat.overdue;
    final int? sisa = alat.sisaHari;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _HeroAlat(alat: alat),
          const SizedBox(height: 20),
          _InfoCard(
            label: 'Kode Alat',
            value: alat.barcodeAlat,
            icon: Icons.qr_code,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: 'Merk Alat',
            value: alat.merkAlat,
            icon: Icons.build_circle_outlined,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: 'Kategori',
            value: alat.namaKategori ?? '-',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: 'Detail Lokasi',
            value: alat.detailLokasi,
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOverdue ? AppColors.overdueSoft : AppColors.tepatWaktuSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverdue ? AppColors.overdue : AppColors.tepatWaktu,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: isOverdue ? AppColors.overdue : AppColors.tepatWaktu,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isOverdue ? 'Maintenance Terlambat' : 'Maintenance Tepat Waktu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? AppColors.overdue : AppColors.tepatWaktu,
                        ),
                      ),
                      if (sisa != null)
                        Text(
                          isOverdue
                              ? 'Terlambat ${sisa.abs()} hari'
                              : 'Sisa $sisa hari menuju jadwal',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? AppColors.overdue : AppColors.tepatWaktu,
                          ),
                        ),
                      if (alat.terakhirMaintenance != null)
                        Text(
                          'Terakhir: ${_fmt(alat.terakhirMaintenance!)}',
                          style: TextStyle(fontSize: 11, color: context.pal.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'ISI FORM MAINTENANCE',
            icon: Icon(Icons.edit_document, size: 18, color: Colors.white),
            onPressed: () {
              ref.read(maintenanceFormProvider.notifier).init(
                    barcodeAlat: alat.barcodeAlat,
                    idLokasi: alat.idLokasi ?? 0,
                  );
              context.goMaintenanceForm();
            },
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'LIHAT RIWAYAT',
            variant: AppButtonVariant.outline,
            onPressed: () => context.goRiwayat(),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Header hero detail alat: ikon kategori asli + identitas alat + status.
///
/// Membuat layar terasa hidup dan langsung memberi konteks sebelum teknisi
/// membaca rincian — pengganti deretan kartu abu yang datar.
class _HeroAlat extends StatelessWidget {
  const _HeroAlat({required this.alat});

  final Alat alat;

  @override
  Widget build(BuildContext context) {
    final String? ikon = AppStrings.kategoriIcon[alat.namaKategori];
    final bool overdue = alat.overdue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: <Widget>[
          // AC-F3: Hero memakai tag unik per barcode sehingga ikon alat
          // "terbang" dari kartu daftar ke header detail.
          Hero(
            tag: 'alat-${alat.barcodeAlat}',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ikon != null
                  ? Image.asset(ikon, fit: BoxFit.contain)
                  : Icon(
                      Icons.build_outlined,
                      color: AppColors.primary,
                      size: AppSizes.iconLg,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alat.barcodeAlat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alat.merkAlat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.background.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        overdue
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color: AppColors.background,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        overdue ? 'Perlu pemeliharaan' : 'Dalam siklus',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.background,
                        ),
                      ),
                    ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.pal.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: TextStyle(fontSize: 11, color: context.pal.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
