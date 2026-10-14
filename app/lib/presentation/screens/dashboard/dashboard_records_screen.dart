import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/dashboard.dart';
import '../../../domain/models/maintenance.dart';
import '../../../providers/maintenance_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Dashboard Records — tabel lengkap riwayat pemeliharaan.
///
/// Dilengkapi pencarian barcode, filter status verifikasi, dan paginasi.
class DashboardRecordsScreen extends ConsumerStatefulWidget {
  const DashboardRecordsScreen({super.key});

  @override
  ConsumerState<DashboardRecordsScreen> createState() =>
      _DashboardRecordsScreenState();
}

class _DashboardRecordsScreenState extends ConsumerState<DashboardRecordsScreen> {
  final TextEditingController _cari = TextEditingController();
  static const int _perPage = 15;
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

  Future<void> _muat({int page = 1}) {
    return ref.read(maintenanceListProvider.notifier).load(
          page: page,
          perPage: _perPage,
          barcodeAlat: _cari.text.trim().isEmpty ? null : _cari.text.trim(),
          statusVerifikasi: _status == 'Semua' ? null : _status.toLowerCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PagedResult<Maintenance>> async =
        ref.watch(maintenanceListProvider);

    return Column(
      children: <Widget>[
        const SectionHeader(
          title: 'Data pemeliharaan',
          subtitle: 'Seluruh catatan dari semua teknisi',
          icon: Icons.table_chart_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _cari,
          hint: 'Cari kode alat...',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          onSubmitted: (_) => _muat(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilterChipBar(
          items: const <String>['Semua', 'Menunggu', 'Disetujui', 'Ditolak'],
          selected: <String>[_status],
          multi: false,
          onChanged: (List<String> pilih) {
            setState(() => _status = pilih.isEmpty ? 'Semua' : pilih.last);
            _muat();
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: async.when(
            data: (PagedResult<Maintenance> result) => _tabel(result),
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
              message: 'Gagal memuat data.\n$e',
              onRetry: _muat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabel(PagedResult<Maintenance> result) {
    if (result.data.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Tidak ada catatan',
        message: _cari.text.trim().isEmpty && _status == 'Semua'
            ? 'Belum ada pemeliharaan tercatat.'
            : 'Tidak ada catatan yang cocok dengan filter.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total ${result.total} catatan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: result.currentPage > 1
                    ? () => _muat(page: result.currentPage - 1)
                    : null,
              ),
              Text(
                '${result.currentPage} / ${result.lastPage}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: result.currentPage < result.lastPage
                    ? () => _muat(page: result.currentPage + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.primary.withValues(alpha: 0.08),
                    ),
                    border: TableBorder.all(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    columns: const <DataColumn>[
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Waktu')),
                      DataColumn(label: Text('Teknisi')),
                      DataColumn(label: Text('Barcode')),
                      DataColumn(label: Text('Kategori')),
                      DataColumn(label: Text('Lokasi')),
                      DataColumn(label: Text('Kondisi')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: result.data.map((Maintenance m) {
                      final (Color warna, String label) = _statusVerifikasi(m);
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text('${m.idMaintenance}')),
                          DataCell(Text(m.waktuTampil)),
                          DataCell(Text(m.namaUsers ?? m.username ?? '-')),
                          DataCell(Text(m.barcodeAlat)),
                          DataCell(Text(m.namaKategori ?? '-')),
                          DataCell(Text(m.namaLokasi ?? '-')),
                          DataCell(_badgeKondisi(m.kondisiKeseluruhan)),
                          DataCell(
                            StatusBadge(
                              label: label,
                              color: warna,
                              dense: true,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeKondisi(String? k) {
    final (Color warna, Color soft, String label) = switch (k) {
      'baik' => (AppColors.kondisiBaik, AppColors.kondisiBaikSoft, 'Baik'),
      'kurang_baik' => (
          AppColors.kondisiKurangBaik,
          AppColors.kondisiKurangBaikSoft,
          'Kurang Baik',
        ),
      'rusak' => (AppColors.kondisiRusak, AppColors.kondisiRusakSoft, 'Rusak'),
      _ => (AppColors.statusUnknown, AppColors.surfaceMuted, '-'),
    };

    return StatusBadge(label: label, color: warna, softColor: soft, dense: true);
  }

  (Color, String) _statusVerifikasi(Maintenance m) {
    return switch (m.statusVerifikasiTampil.toLowerCase()) {
      'disetujui' => (AppColors.verifikasiDisetujui, 'Disetujui'),
      'ditolak' => (AppColors.verifikasiDitolak, 'Ditolak'),
      _ => (AppColors.verifikasiMenunggu, 'Menunggu'),
    };
  }
}
