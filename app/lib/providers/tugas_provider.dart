import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/tugas_repository.dart';
import '../domain/models/tugas.dart';

/// Instance repository "Tugas Hari Ini" (bisa di-override saat pengujian).
final tugasRepositoryProvider =
    Provider<TugasRepository>((ref) => const TugasRepository());

/// State beranda Teknisi: daftar alat yang perlu dipelihara hari ini.
@immutable
class TugasState {
  const TugasState({this.data, this.isLoading = false, this.error});

  final TugasHariIni? data;
  final bool isLoading;
  final String? error;

  List<TugasItem> get daftar => data?.daftar ?? const <TugasItem>[];

  TugasRingkasan get ringkasan => data?.ringkasan ?? const TugasRingkasan();

  /// Sudah dimuat tetapi tidak ada tugas → tampilkan [EmptyState].
  bool get kosong => data != null && daftar.isEmpty;

  /// Belum pernah berhasil dimuat.
  bool get belumDimuat => data == null && !isLoading && error == null;

  TugasState copyWith({
    TugasHariIni? data,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TugasState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TugasNotifier extends StateNotifier<TugasState> {
  TugasNotifier(this._repo) : super(const TugasState());

  final TugasRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final TugasHariIni hasil = await _repo.getHariIni();
      state = TugasState(data: hasil);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('TugasNotifier.load gagal: $st');
    }
  }

  Future<void> refresh() => load();

  void clearError() => state = state.copyWith(clearError: true);

  String _pesan(Object e) => e is Exception
      ? e.toString().replaceFirst('Exception: ', '')
      : 'Terjadi kesalahan.';
}

final tugasProvider =
    StateNotifierProvider<TugasNotifier, TugasState>((ref) {
  return TugasNotifier(ref.watch(tugasRepositoryProvider));
});
