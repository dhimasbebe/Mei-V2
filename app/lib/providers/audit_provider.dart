import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audit/audit_filter.dart';
import '../data/repositories/maintenance_repository.dart';
import '../domain/models/audit_log.dart';
import '../domain/models/dashboard.dart';
import 'maintenance_provider.dart';

/// StateNotifier daftar audit log (Tahap 3 — WS D, §5.3).
///
/// Mendukung filter tanggal `dari`/`sampai` (endpoint sudah mendukung) dan
/// paging "muat lebih banyak" — pola yang sama dengan
/// [MaintenanceListNotifier].
class AuditLogNotifier
    extends StateNotifier<AsyncValue<PagedResult<AuditLogEntry>>> {
  AuditLogNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final MaintenanceRepository _repo;

  // Filter aktif — dipertahankan saat paging.
  DateTime? _dari;
  DateTime? _sampai;

  DateTime? get dari => _dari;
  DateTime? get sampai => _sampai;

  Future<void> load({DateTime? dari, DateTime? sampai}) async {
    if (dari != null) _dari = AuditFilter.normalisasiDari(dari);
    if (sampai != null) _sampai = AuditFilter.normalisasiSampai(sampai);
    if (dari == null && sampai == null) {
      // Reset filter (panggilan tanpa argumen dari refresh).
      _dari = null;
      _sampai = null;
    }

    state = const AsyncValue.loading();
    try {
      final PagedResult<AuditLogEntry> hasil = await _repo.getAuditLog(
        dari: AuditFilter.keQuery(_dari),
        sampai: AuditFilter.keQuery(_sampai),
      );
      state = AsyncValue.data(hasil);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> nextPage() async {
    final PagedResult<AuditLogEntry>? current = state.valueOrNull;
    if (current == null || current.currentPage >= current.lastPage) return;
    try {
      final PagedResult<AuditLogEntry> hasil = await _repo.getAuditLog(
        page: current.currentPage + 1,
        dari: AuditFilter.keQuery(_dari),
        sampai: AuditFilter.keQuery(_sampai),
      );
      state = AsyncValue.data(
        PagedResult<AuditLogEntry>(
          data: [...current.data, ...hasil.data],
          currentPage: hasil.currentPage,
          lastPage: hasil.lastPage,
          total: hasil.total,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final auditLogProvider =
    StateNotifierProvider<AuditLogNotifier, AsyncValue<PagedResult<AuditLogEntry>>>(
        (ref) {
  return AuditLogNotifier(ref.watch(maintenanceRepositoryProvider));
});
