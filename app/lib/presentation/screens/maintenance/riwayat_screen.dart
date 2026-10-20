import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maintenance/draft_template.dart';
import '../../../core/offline/draft_queue.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/alat.dart';
import '../../../domain/models/dashboard.dart';
import '../../../domain/models/maintenance.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/search_history_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/foto_gallery.dart' show FotoCountBadge;
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../../core/theme/app_palette.dart';

/// Layar Riwayat Maintenance.
///
/// Teknisi hanya melihat riwayat miliknya sendiri; Supervisor dan Admin
/// melihat riwayat seluruh teknisi (pemisahan data per role).
class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  final TextEditingController _cari = TextEditingController();
  String _status = 'Semua';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_muat);
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() {
    final bool teknisi = ref.read(authProvider).user?.isTeknisi ?? false;
    return ref.read(maintenanceListProvider.notifier).load(
          barcodeAlat: _cari.text.trim().isEmpty ? null : _cari.text.trim(),
          username: teknisi ? ref.read(authProvider).user?.username : null,
          statusVerifikasi: _status == 'Semua' ? null : _status.toLowerCase(),
        );
  }

  /// Duplikat laporan (WS K): bentuk draf BARU dari laporan lama lewat modul
  /// murni [DraftTemplate] — `client_uuid` baru (bukan kirim ulang) dan foto
  /// sengaja tidak disalin. Form dibuka terisi; teknisi hanya mengubah bagian
  /// yang berbeda lalu mengirim sebagai laporan baru.
  Future<void> _duplikat(Maintenance ringkas) async {
    try {
      // Daftar riwayat tidak memuat detail checklist — ambil versi lengkap.
      final Maintenance lengkap = await ref
          .read(maintenanceDetailProvider(ringkas.idMaintenance).future);
      final Alat alat = await ref
          .read(alatRepositoryProvider)
          .getByBarcode(lengkap.barcodeAlat);

      final DraftRecord draf = DraftTemplate.fromReport(
        lengkap,
        buatUuid: () => MaintenancePayload(
          barcodeAlat: lengkap.barcodeAlat,
          idLokasi: lengkap.idLokasi,
          detail: const <DetailMaintenance>[],
        ).clientUuid,
      );

      if (!mounted) return;
      ref.read(alatDetailProvider.notifier).state = alat;
      ref.read(formSeedProvider.notifier).state = draf;
      ref.read(salinanDariProvider.notifier).state = ringkas.idMaintenance;
      ref.read(maintenanceFormProvider.notifier).init(
            barcodeAlat: draf.barcodeAlat,
            idLokasi: draf.idLokasi,
          );
      context.goMaintenanceForm();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menyiapkan duplikat. Periksa koneksi lalu coba lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PagedResult<Maintenance>> async =
        ref.watch(maintenanceListProvider);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            children: <Widget>[
              SearchHistoryField(
                controller: _cari,
                hint: 'Cari kode alat...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                onSubmitted: (_) => _muat(),
              ),
              const SizedBox(height: AppSpacing.md),
              FilterChipBar(
                items: const <String>[
                  'Semua',
                  'Menunggu',
                  'Disetujui',
                  'Ditolak',
                ],
                selected: <String>[_status],
                multi: false,
                onChanged: (List<String> pilih) {
                  setState(() => _status = pilih.isEmpty ? 'Semua' : pilih.last);
                  _muat();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            data: (PagedResult<Maintenance> result) => _daftar(result),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  SkeletonListTile(),
                  SkeletonListTile(),
                  SkeletonListTile(),
                ],
              ),
            ),
            error: (Object e, _) => ErrorView(
              message: 'Gagal memuat riwayat.\n$e',
              onRetry: _muat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _daftar(PagedResult<Maintenance> result) {
    final String role =
        (ref.read(authProvider).user?.roleUsers ?? '').toLowerCase();
    final bool bolehDuplikat = role == 'teknisi' || role == 'admin';

    if (result.data.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: 'Belum ada riwayat',
        message: _cari.text.trim().isEmpty && _status == 'Semua'
            ? 'Riwayat pemeliharaan akan muncul di sini setelah teknisi mengirim laporan.'
            : 'Tidak ada riwayat yang cocok dengan pencarian atau filter.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: result.data.length +
            (result.currentPage < result.lastPage ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == result.data.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(maintenanceListProvider.notifier).nextPage(),
                  child: Text('Muat lebih banyak'),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _KartuRiwayat(
              m: result.data[index],
              onDuplikat: bolehDuplikat
                  ? () => _duplikat(result.data[index])
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _KartuRiwayat extends StatelessWidget {
  const _KartuRiwayat({required this.m, this.onDuplikat});

  final Maintenance m;

  /// Aksi "Duplikat" (WS K); `null` bila role tidak berhak.
  final VoidCallback? onDuplikat;

  @override
  Widget build(BuildContext context) {
    final (Color warna, Color soft, IconData ikon, String label) status =
        switch (m.statusVerifikasiTampil.toLowerCase()) {
      'disetujui' => (
          AppColors.verifikasiDisetujui,
          AppColors.verifikasiDisetujuiSoft,
          Icons.check_circle_outline,
          'Disetujui',
        ),
      'ditolak' => (
          AppColors.verifikasiDitolak,
          AppColors.verifikasiDitolakSoft,
          Icons.cancel_outlined,
          'Ditolak',
        ),
      _ => (
          AppColors.verifikasiMenunggu,
          AppColors.verifikasiMenungguSoft,
          Icons.hourglass_empty,
          'Menunggu',
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  m.waktuTampil,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.pal.textPrimary,
                  ),
                ),
              ),
              FotoCountBadge(jumlah: m.jumlahFoto),
              if (onDuplikat != null)
                IconButton(
                  tooltip: 'Duplikat laporan',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDuplikat,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: status.$4,
                color: status.$1,
                softColor: status.$2,
                icon: status.$3,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${m.barcodeAlat} • ${m.namaKategori ?? '-'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.pal.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Icon(
                Icons.person_outline,
                size: 14,
                color: context.pal.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                m.namaTeknisi,
                style: TextStyle(
                  fontSize: 11,
                  color: context.pal.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: context.pal.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  m.namaLokasi ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.pal.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (m.detailRingkas.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              m.detailRingkas,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: context.pal.textSecondary,
              ),
            ),
          ],
          if (m.komentarVerifikasi != null &&
              m.komentarVerifikasi!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: status.$2,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.rate_review_outlined, size: 16, color: status.$1),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      m.komentarVerifikasi!,
                      style: TextStyle(fontSize: 11, color: status.$1),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (m.catatan != null && m.catatan!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.pal.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.notes,
                    size: 16,
                    color: context.pal.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      m.catatan!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
