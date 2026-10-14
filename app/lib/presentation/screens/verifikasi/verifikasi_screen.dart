import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/verifikasi.dart';
import '../../../providers/verifikasi_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';

/// Layar Verifikasi (Supervisor & Admin).
///
/// Inti pekerjaan pengawas: meninjau laporan pemeliharaan yang dikirim teknisi,
/// lalu menyetujui atau menolaknya beserta catatan. Sebelum perubahan ini fitur
/// tersebut tidak ada sama sekali di aplikasi.
class VerifikasiScreen extends ConsumerStatefulWidget {
  const VerifikasiScreen({super.key});

  @override
  ConsumerState<VerifikasiScreen> createState() => _VerifikasiScreenState();
}

class _VerifikasiScreenState extends ConsumerState<VerifikasiScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(verifikasiProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final VerifikasiState state = ref.watch(verifikasiProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(verifikasiProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Menunggu',
                  value: state.badge,
                  icon: Icons.hourglass_empty,
                  color: AppColors.verifikasiMenunggu,
                  loading: state.isLoading && state.data == null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Total ditinjau',
                  value: '${state.total}',
                  icon: Icons.fact_check_outlined,
                  color: AppColors.roleSupervisor,
                  loading: state.isLoading && state.data == null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Antrean verifikasi',
            subtitle: 'Laporan teknisi yang menunggu keputusan Anda',
            icon: Icons.rule_folder_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          _Isi(state: state),
        ],
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.state});

  final VerifikasiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.data == null) {
      return const Column(
        children: <Widget>[
          SkeletonCard(),
          SkeletonCard(),
        ],
      );
    }

    if (state.error != null && state.data == null) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(verifikasiProvider.notifier).load(),
      );
    }

    if (state.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_outlined,
        title: 'Tidak ada yang menunggu',
        message:
            'Semua laporan teknisi sudah ditinjau. Antrean akan terisi saat '
            'teknisi mengirim pemeliharaan baru.',
      );
    }

    return Column(
      children: <Widget>[
        ...state.items.map(
          (VerifikasiItem v) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _KartuVerifikasi(item: v),
          ),
        ),
        if (state.hasNext)
          TextButton(
            onPressed: state.isLoadingMore
                ? null
                : () => ref.read(verifikasiProvider.notifier).loadMore(),
            child: Text(state.isLoadingMore ? 'Memuat...' : 'Muat lebih banyak'),
          ),
      ],
    );
  }
}

class _KartuVerifikasi extends ConsumerStatefulWidget {
  const _KartuVerifikasi({required this.item});

  final VerifikasiItem item;

  @override
  ConsumerState<_KartuVerifikasi> createState() => _KartuVerifikasiState();
}

class _KartuVerifikasiState extends ConsumerState<_KartuVerifikasi> {
  bool _terbuka = false;

  @override
  Widget build(BuildContext context) {
    final VerifikasiItem v = widget.item;
    final bool sibuk = ref.watch(verifikasiProvider).isSubmitting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      v.barcodeAlat,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.merkAlat ?? '-'} • ${v.namaKategori ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'Menunggu',
                color: AppColors.verifikasiMenunggu,
                softColor: AppColors.verifikasiMenungguSoft,
                icon: Icons.hourglass_empty,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Baris(icon: Icons.person_outline, teks: v.teknisi),
          _Baris(icon: Icons.location_on_outlined, teks: v.detailLokasi),
          _Baris(icon: Icons.schedule, teks: _waktu(v.waktuMaintenance)),
          if (v.kondisiKeseluruhan != null)
            _Baris(
              icon: Icons.health_and_safety_outlined,
              teks: 'Kondisi: ${_kondisi(v.kondisiKeseluruhan!)}',
            ),
          if (v.detailRingkas.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => setState(() => _terbuka = !_terbuka),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.checklist_rtl,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _terbuka ? 'Sembunyikan checklist' : 'Lihat checklist',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      _terbuka ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: AppDurations.normal,
              crossFadeState: _terbuka
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  v.detailRingkas,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: sibuk ? null : () => _tolak(v),
                  icon: const Icon(Icons.close, size: AppSizes.iconSm),
                  label: const Text('TOLAK'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: sibuk ? null : () => _setujui(v),
                  icon: const Icon(Icons.check, size: AppSizes.iconSm),
                  label: const Text('SETUJUI'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setujui(VerifikasiItem v) async {
    final String? komentar = await _dialogKomentar(
      judul: 'Setujui laporan',
      labelTombol: 'SETUJUI',
      wajib: false,
      keterangan: 'Laporan ${v.barcodeAlat} dari ${v.teknisi} akan disetujui.',
    );
    if (komentar == null) return;
    await _kirim(() => ref.read(verifikasiProvider.notifier).setujui(
          v.idMaintenance,
          komentar: komentar.isEmpty ? null : komentar,
        ), 'Laporan disetujui.');
  }

  Future<void> _tolak(VerifikasiItem v) async {
    final String? komentar = await _dialogKomentar(
      judul: 'Tolak laporan',
      labelTombol: 'TOLAK',
      wajib: true,
      keterangan:
          'Jelaskan alasan penolakan agar teknisi dapat memperbaiki laporannya.',
    );
    if (komentar == null) return;
    await _kirim(() => ref.read(verifikasiProvider.notifier).tolak(
          v.idMaintenance,
          komentar: komentar,
        ), 'Laporan ditolak.');
  }

  Future<void> _kirim(Future<bool> Function() aksi, String pesanSukses) async {
    final bool ok = await aksi();
    if (!mounted) return;
    AppSnackbar.show(
      context,
      ok ? pesanSukses : (ref.read(verifikasiProvider).error ?? 'Gagal memproses.'),
      type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
    );
  }

  Future<String?> _dialogKomentar({
    required String judul,
    required String labelTombol,
    required bool wajib,
    required String keterangan,
  }) async {
    final TextEditingController ctrl = TextEditingController();
    String? pesanError;

    final String? hasil = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(judul),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                keterangan,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: ctrl,
                label: wajib ? 'Catatan (wajib)' : 'Catatan (opsional)',
                hint: 'Tulis catatan untuk teknisi...',
                autofocus: true,
              ),
              if (pesanError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  pesanError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.statusDanger,
                  ),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('BATAL'),
            ),
            TextButton(
              onPressed: () {
                final String teks = ctrl.text.trim();
                if (wajib && teks.isEmpty) {
                  setLocal(() => pesanError = 'Catatan wajib diisi saat menolak.');
                  return;
                }
                Navigator.of(ctx).pop(teks);
              },
              child: Text(labelTombol),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return hasil;
  }

  static String _waktu(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _kondisi(String k) => switch (k) {
        'baik' => 'Baik',
        'kurang_baik' => 'Kurang Baik',
        'rusak' => 'Rusak',
        _ => k,
      };
}

class _Baris extends StatelessWidget {
  const _Baris({required this.icon, required this.teks});

  final IconData icon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
