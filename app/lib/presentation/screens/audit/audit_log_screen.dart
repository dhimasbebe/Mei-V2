import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_aksi.dart';
import '../../../core/audit/audit_detail.dart';
import '../../../core/audit/audit_filter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/audit_log.dart';
import '../../../domain/models/dashboard.dart';
import '../../../providers/audit_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Layar Riwayat Audit Log (Tahap 3 — WS D, `docs/DESIGN-FEATURES-V3.md` §7).
///
/// Admin & Supervisor melihat seluruh perubahan sistem: siapa, kapan, aksi
/// apa, dan detail perubahan kunci–nilai (bentuk flat lama maupun
/// `{lama, baru}` diurai oleh `AuditDetail.format` — modul pure-Dart yang
/// sudah diverifikasi). Filter tanggal `dari`/`sampai` memakai endpoint
/// `GET /audit-log?dari=&sampai=`.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  DateTime? _dari;
  DateTime? _sampai;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PagedResult<AuditLogEntry>> async =
        ref.watch(auditLogProvider);

    return AppScaffold(
      useRedAppBar: true,
      title: 'Riwayat Audit',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        children: <Widget>[
          _BarisFilter(
            dari: _dari,
            sampai: _sampai,
            onPilih: (DateTime? dari, DateTime? sampai) {
              setState(() {
                _dari = dari;
                _sampai = sampai;
              });
              ref.read(auditLogProvider.notifier).load(
                    dari: dari,
                    sampai: sampai,
                  );
            },
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: async.when(
              data: (PagedResult<AuditLogEntry> hasil) => _daftar(hasil),
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
                message: 'Gagal memuat audit log.\n$e',
                onRetry: () =>
                    ref.read(auditLogProvider.notifier).load(dari: _dari, sampai: _sampai),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _daftar(PagedResult<AuditLogEntry> hasil) {
    if (hasil.data.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada catatan audit',
        message: (_dari == null && _sampai == null)
            ? 'Catatan perubahan sistem (buat, ubah, hapus, verifikasi) akan '
                'muncul di sini.'
            : 'Tidak ada catatan dalam rentang tanggal terpilih.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(auditLogProvider.notifier).load(dari: _dari, sampai: _sampai),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: hasil.data.length +
            (hasil.currentPage < hasil.lastPage ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == hasil.data.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(auditLogProvider.notifier).nextPage(),
                  child: const Text('Muat lebih banyak'),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _KartuAudit(entry: hasil.data[index]),
          );
        },
      ),
    );
  }
}

class _BarisFilter extends StatelessWidget {
  const _BarisFilter({
    required this.dari,
    required this.sampai,
    required this.onPilih,
  });

  final DateTime? dari;
  final DateTime? sampai;
  final void Function(DateTime? dari, DateTime? sampai) onPilih;

  Future<void> _pilih(BuildContext context, bool isDari) async {
    final DateTime awal = DateTime(2024);
    final DateTime? hasil = await showDatePicker(
      context: context,
      initialDate: (isDari ? dari : sampai) ??
          (isDari
              ? (sampai ?? DateTime.now()).subtract(const Duration(days: 7))
              : DateTime.now()),
      firstDate: awal,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: isDari ? 'Pilih tanggal mulai' : 'Pilih tanggal sampai',
    );
    if (hasil == null) return;
    final DateTime? dBaru = isDari ? hasil : sampai;
    final DateTime? sBaru = isDari ? sampai : hasil;
    if (!AuditFilter.valid(dBaru, sBaru)) {
      // Tanggal mulai setelah tanggal sampai — tolak diam-diam diperjelas.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tanggal mulai tidak boleh setelah tanggal sampai.'),
        ),
      );
      return;
    }
    onPilih(dBaru, sBaru);
  }

  @override
  Widget build(BuildContext context) {
    final String teksDari =
        dari == null ? 'Dari tanggal' : AuditFilter.keQuery(dari)!;
    final String teksSampai =
        sampai == null ? 'Sampai tanggal' : AuditFilter.keQuery(sampai)!;
    final bool adaFilter = dari != null || sampai != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surfaceMuted,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                side: BorderSide.none,
              ),
              icon: const Icon(Icons.date_range,
                  size: 16, color: AppColors.primary),
              label: Text(teksDari, overflow: TextOverflow.ellipsis),
              onPressed: () => _pilih(context, true),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surfaceMuted,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                side: BorderSide.none,
              ),
              icon: const Icon(Icons.date_range,
                  size: 16, color: AppColors.primary),
              label: Text(teksSampai, overflow: TextOverflow.ellipsis),
              onPressed: () => _pilih(context, false),
            ),
          ),
          if (adaFilter) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Hapus filter',
              icon: const Icon(Icons.filter_alt_off_outlined,
                  size: 20, color: AppColors.textSecondary),
              onPressed: () => onPilih(null, null),
            ),
          ],
        ],
      ),
    );
  }
}

class _KartuAudit extends StatelessWidget {
  const _KartuAudit({required this.entry});

  final AuditLogEntry entry;

  (Color, Color, IconData) get _stail {
    switch (entry.aksi.toLowerCase()) {
      case 'create':
        return (
          AppColors.statusOk,
          AppColors.kondisiBaikSoft,
          Icons.add_circle_outline,
        );
      case 'update':
        return (
          AppColors.statusWarning,
          AppColors.kondisiKurangBaikSoft,
          Icons.edit_outlined,
        );
      case 'delete':
        return (
          AppColors.statusDanger,
          AppColors.kondisiRusakSoft,
          Icons.delete_outline,
        );
      case 'verify':
        return (
          AppColors.roleSupervisor,
          AppColors.roleSupervisorSoft,
          Icons.verified_outlined,
        );
      default:
        return (
          AppColors.textSecondary,
          AppColors.surfaceMuted,
          Icons.info_outline,
        );
    }
  }

  void _bukaDetail(BuildContext context) {
    final List<String> baris = AuditDetail.format(entry.detail);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          'Perubahan #${entry.idAudit}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: baris.isEmpty
            ? const Text('Tidak ada detail perubahan.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(baris.length, (int i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      baris[i],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }),
              ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (Color warna, Color soft, IconData ikon) = _stail;
    final List<String> perubahan = AuditDetail.format(entry.detail);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatusBadge(
                  label: AuditAksi.label(entry.aksi),
                  color: warna,
                  softColor: soft,
                  icon: ikon,
                  dense: true,
                ),
              ),
              Text(
                entry.waktuTampil,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${entry.entitas} • ${entry.entitasId}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  entry.actorUsername,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (perubahan.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.visibility_outlined, size: 15),
              label: const Text('Lihat perubahan'),
              onPressed: () => _bukaDetail(context),
            ),
          ],
        ],
      ),
    );
  }
}
