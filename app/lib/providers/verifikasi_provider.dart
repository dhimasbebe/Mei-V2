import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/verifikasi_repository.dart';
import '../domain/models/dashboard.dart';
import '../domain/models/verifikasi.dart';

/// Instance repository verifikasi (bisa di-override saat testing).
final verifikasiRepositoryProvider = Provider<VerifikasiRepository>(
  (ref) => const VerifikasiRepository(),
);

/// State layar Verifikasi: daftar menunggu + jumlah badge + status submit.
///
/// Memakai kelas state sendiri (bukan [AsyncValue]) karena layar butuh
/// menyimpan daftar DAN jumlah badge DAN status submit sekaligus, tanpa
/// kehilangan daftar saat satu aksi gagal.
@immutable
class VerifikasiState {
  const VerifikasiState({
    this.data,
    this.pendingCount = 0,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isLoadingMore = false,
    this.error,
  });

  /// Halaman yang sedang ditampilkan (null = belum pernah dimuat).
  final PagedResult<VerifikasiItem>? data;

  /// Jumlah antrean menunggu (badge tab Verifikasi).
  final int pendingCount;
  final bool isLoading;
  final bool isSubmitting;
  final bool isLoadingMore;
  final String? error;

  List<VerifikasiItem> get items => data?.data ?? const <VerifikasiItem>[];
  bool get isEmpty => items.isEmpty;
  bool get hasNext => data?.hasNext ?? false;
  int get total => data?.total ?? 0;

  /// Tidak ada antrean menunggu sama sekali → EmptyState.
  bool get kosong => pendingCount <= 0 && isEmpty;

  /// Teks badge (dibatasi "99+").
  String get badge => pendingCount > 99 ? '99+' : '$pendingCount';

  VerifikasiState copyWith({
    PagedResult<VerifikasiItem>? data,
    int? pendingCount,
    bool? isLoading,
    bool? isSubmitting,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return VerifikasiState(
      data: data ?? this.data,
      pendingCount: pendingCount ?? this.pendingCount,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier layar Verifikasi (Supervisor/Admin).
class VerifikasiNotifier extends StateNotifier<VerifikasiState> {
  VerifikasiNotifier(this._repo) : super(const VerifikasiState()) {
    load();
  }

  final VerifikasiRepository _repo;

  /// Muat halaman pertama + jumlah menunggu.
  Future<void> load({int page = 1, int perPage = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final PagedResult<VerifikasiItem> result =
          await _repo.getPending(page: page, perPage: perPage);
      final PendingCount count = await _repo.getCount();
      state = VerifikasiState(data: result, pendingCount: count.menunggu);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('VerifikasiNotifier.load gagal: $st');
    }
  }

  /// Muat ulang dari halaman pertama (pull-to-refresh).
  Future<void> refresh() => load();

  /// Tambah halaman berikutnya (infinite scroll).
  Future<void> loadMore() async {
    final PagedResult<VerifikasiItem>? current = state.data;
    if (current == null || !current.hasNext || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final PagedResult<VerifikasiItem> next =
          await _repo.getPending(page: current.currentPage + 1, perPage: current.perPage);
      state = state.copyWith(
        isLoadingMore: false,
        data: PagedResult<VerifikasiItem>(
          data: <VerifikasiItem>[...current.data, ...next.data],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
          perPage: next.perPage,
        ),
      );
    } catch (e, st) {
      state = state.copyWith(isLoadingMore: false, error: _pesan(e));
      debugPrint('VerifikasiNotifier.loadMore gagal: $st');
    }
  }

  /// Setujui satu item dengan catatan opsional. `true` bila berhasil.
  Future<bool> setujui(int id, {String? komentar}) =>
      verify(id, VerifikasiPayload.setujui(komentar: komentar));

  /// Tolak satu item dengan alasan opsional. `true` bila berhasil.
  Future<bool> tolak(int id, {String? komentar}) =>
      verify(id, VerifikasiPayload.tolak(komentar: komentar));

  /// Kirim aksi verifikasi, lalu segarkan daftar + jumlah menunggu.
  Future<bool> verify(int id, VerifikasiPayload payload) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.verify(id, payload);
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('VerifikasiNotifier.verify gagal: $st');
      return false;
    }
  }

  /// Bersihkan pesan error (mis. setelah snackbar ditutup).
  void clearError() => state = state.copyWith(clearError: true);

  String _pesan(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Terjadi kesalahan.';
}

final verifikasiProvider =
    StateNotifierProvider<VerifikasiNotifier, VerifikasiState>((ref) {
  return VerifikasiNotifier(ref.watch(verifikasiRepositoryProvider));
});

/// Jumlah menunggu verifikasi untuk badge tab.
///
/// Turunan dari [verifikasiProvider] sehingga ikut ter-update otomatis setelah
/// aksi setujui/tolak. Menontonnya akan membangun [verifikasiProvider] (yang
/// langsung memuat daftar + jumlah).
final pendingVerifikasiCountProvider = Provider<int>((ref) {
  return ref.watch(verifikasiProvider).pendingCount;
});
