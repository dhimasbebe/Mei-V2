import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/offline/draft_queue.dart';
import '../../../core/offline/draft_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/draft_provider.dart';
import '../../widgets/empty_state.dart';

/// Layar antrean sinkronisasi offline (Tahap 3 — WS A, §7.1).
///
/// Menampilkan seluruh draf beserta statusnya (AC-A6/A7), memungkinkan
/// pengguna mengirim ulang sekarang, mencoba draf yang ditolak, atau
/// menghapus draf.
class SyncQueueScreen extends ConsumerStatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  ConsumerState<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends ConsumerState<SyncQueueScreen> {
  static final DateFormat _fmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final DraftState state = ref.watch(draftQueueProvider);
    final List<DraftRecord> items = state.antrean.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Antrean Sinkron',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Kirim sekarang',
            icon: const Icon(Icons.sync, color: AppColors.primary),
            onPressed: state.sedangSinkron
                ? null
                : () =>
                    ref.read(draftQueueProvider.notifier).syncNow(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _Ringkasan(state: state),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.cloud_done_outlined,
                    title: 'Tidak ada draf',
                    message:
                        'Semua laporan sudah tersinkron. Laporan yang dibuat '
                        'saat offline akan muncul di sini.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int i) =>
                        _KartuDraf(
                      draf: items[i],
                      onCobaLagi: state.sedangSinkron
                          ? null
                          : () => ref
                              .read(draftQueueProvider.notifier)
                              .cobaLagi(items[i].clientUuid),
                      onHapus: state.sedangSinkron
                          ? null
                          : () => ref
                              .read(draftQueueProvider.notifier)
                              .hapusDraf(items[i].clientUuid),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.state});

  final DraftState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surfaceMuted,
      child: Row(
        children: <Widget>[
          Icon(
            state.online ? Icons.cloud_outlined : Icons.cloud_off_outlined,
            size: 18,
            color: state.online ? AppColors.statusOk : AppColors.statusWarning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            state.online ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: state.online
                  ? AppColors.statusOk
                  : AppColors.statusWarning,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            'Menunggu: ${state.jumlahMenunggu}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Terkirim: ${state.jumlahTerkirim}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          if (state.jumlahDitolak > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Text(
              'Ditolak: ${state.jumlahDitolak}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.statusDanger,
              ),
            ),
          ],
          if (state.perluLoginUlang) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.lock_outline,
                size: 14, color: AppColors.statusDanger),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Perlu masuk ulang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.statusDanger,
                ),
              ),
            ),
          ],
          if (state.sedangSinkron) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

class _KartuDraf extends StatelessWidget {
  const _KartuDraf({
    required this.draf,
    required this.onCobaLagi,
    required this.onHapus,
  });

  final DraftRecord draf;
  final VoidCallback? onCobaLagi;
  final VoidCallback? onHapus;

  (Color, Color, IconData, String) get _statusTampil {
    switch (draf.status) {
      case DraftStatus.terkirim:
        return (
          AppColors.verifikasiDisetujui,
          AppColors.verifikasiDisetujuiSoft,
          Icons.check_circle_outline,
          'Terkirim',
        );
      case DraftStatus.sedangKirim:
        return (
          AppColors.roleSupervisor,
          AppColors.roleSupervisorSoft,
          Icons.sync_outlined,
          'Mengirim…',
        );
      case DraftStatus.ditolakServer:
        return (
          AppColors.verifikasiDitolak,
          AppColors.verifikasiDitolakSoft,
          Icons.error_outline,
          'Ditolak server',
        );
      case DraftStatus.ditahan:
        return (
          AppColors.verifikasiMenunggu,
          AppColors.verifikasiMenungguSoft,
          Icons.lock_outline,
          'Ditahan (login ulang)',
        );
      case DraftStatus.menungguSinkron:
        return (
          AppColors.verifikasiMenunggu,
          AppColors.verifikasiMenungguSoft,
          Icons.schedule,
          'Menunggu sinkron',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color warna, Color soft, IconData ikon, String label) =
        _statusTampil;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${draf.barcodeAlat} • ${_fmt.format(draf.waktuMaintenance)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(ikon, size: 12, color: warna),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style:
                          TextStyle(fontSize: 10, color: warna),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Percobaan: ${draf.attempt} • Foto: ${draf.fotoPaths.length}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (draf.pesanError != null && draf.pesanError!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              draf.pesanError!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.statusDanger,
              ),
            ),
          ],
          if (draf.nextAttemptAt != null &&
              draf.status == DraftStatus.menungguSinkron) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Coba lagi otomatis ${_fmt.format(draf.nextAttemptAt!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (draf.status == DraftStatus.ditolakServer ||
              draf.status == DraftStatus.ditahan) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: onHapus,
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: AppColors.statusDanger),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onCobaLagi,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
