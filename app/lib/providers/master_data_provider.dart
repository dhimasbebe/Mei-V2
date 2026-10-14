import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/master_data_repository.dart';
import '../domain/models/alat.dart';
import '../domain/models/kategori.dart';
import '../domain/models/lokasi.dart';
import '../domain/models/spesifikasi.dart';

/// Instance repository master data (bisa di-override saat testing).
final masterDataRepositoryProvider = Provider<MasterDataRepository>(
  (ref) => const MasterDataRepository(),
);

/// State daftar generik untuk layar Master Data.
///
/// Memakai kelas state sendiri (bukan [AsyncValue]) supaya kegagalan satu aksi
/// tulis TIDAK menghapus daftar yang sedang tampil — hanya mengisi [error].
@immutable
class MasterListState<T> {
  const MasterListState({
    this.items = const <Never>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final List<T> items;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  bool get isEmpty => items.isEmpty;
  int get jumlah => items.length;

  MasterListState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return MasterListState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

String _pesan(Object e) =>
    e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Terjadi kesalahan.';

// ============================================================================
// Kategori
// ============================================================================

class MasterKategoriNotifier extends StateNotifier<MasterListState<Kategori>> {
  MasterKategoriNotifier(this._repo) : super(const MasterListState<Kategori>()) {
    load();
  }

  final MasterDataRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<Kategori> list = await _repo.getKategoriList();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('MasterKategoriNotifier.load gagal: $st');
    }
  }

  Future<void> refresh() => load();

  Future<bool> create({
    required String nama,
    String? deskripsi,
    int? maintenanceCycleDays,
    String? iconAsset,
  }) =>
      _mutasi(() => _repo.createKategori(
            nama: nama,
            deskripsi: deskripsi,
            maintenanceCycleDays: maintenanceCycleDays,
            iconAsset: iconAsset,
          ));

  Future<bool> update({
    required int id,
    String? nama,
    String? deskripsi,
    String? iconAsset,
  }) =>
      _mutasi(() => _repo.updateKategori(
            id: id,
            nama: nama,
            deskripsi: deskripsi,
            iconAsset: iconAsset,
          ));

  Future<bool> delete(int id) => _mutasi(() => _repo.deleteKategori(id));

  Future<bool> updateCycle({required int id, required int maintenanceCycleDays}) =>
      _mutasi(() => _repo.updateKategoriCycle(
            id: id,
            maintenanceCycleDays: maintenanceCycleDays,
          ));

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _mutasi(Future<void> Function() aksi) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await aksi();
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('MasterKategoriNotifier mutasi gagal: $st');
      return false;
    }
  }
}

final masterKategoriProvider =
    StateNotifierProvider<MasterKategoriNotifier, MasterListState<Kategori>>((ref) {
  return MasterKategoriNotifier(ref.watch(masterDataRepositoryProvider));
});

// ============================================================================
// Lokasi
// ============================================================================

class MasterLokasiNotifier extends StateNotifier<MasterListState<Lokasi>> {
  MasterLokasiNotifier(this._repo) : super(const MasterListState<Lokasi>()) {
    load();
  }

  final MasterDataRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<Lokasi> list = await _repo.getLokasiList();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('MasterLokasiNotifier.load gagal: $st');
    }
  }

  Future<void> refresh() => load();

  Future<bool> create({required String namaLokasi, int? lantai}) =>
      _mutasi(() => _repo.createLokasi(namaLokasi: namaLokasi, lantai: lantai));

  Future<bool> update({required int id, String? namaLokasi, int? lantai}) =>
      _mutasi(() => _repo.updateLokasi(id: id, namaLokasi: namaLokasi, lantai: lantai));

  Future<bool> delete(int id) => _mutasi(() => _repo.deleteLokasi(id));

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _mutasi(Future<void> Function() aksi) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await aksi();
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('MasterLokasiNotifier mutasi gagal: $st');
      return false;
    }
  }
}

final masterLokasiProvider =
    StateNotifierProvider<MasterLokasiNotifier, MasterListState<Lokasi>>((ref) {
  return MasterLokasiNotifier(ref.watch(masterDataRepositoryProvider));
});

// ============================================================================
// Spesifikasi (per kategori)
// ============================================================================

class MasterSpesifikasiNotifier extends StateNotifier<MasterListState<Spesifikasi>> {
  MasterSpesifikasiNotifier(this._repo, this.idKategori)
      : super(const MasterListState<Spesifikasi>()) {
    load();
  }

  final MasterDataRepository _repo;

  /// Kategori yang checklist-nya sedang dikelola.
  final int idKategori;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<Spesifikasi> list = await _repo.getSpesifikasiList(idKategori: idKategori);
      state = state.copyWith(isLoading: false, items: list);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('MasterSpesifikasiNotifier.load gagal: $st');
    }
  }

  Future<void> refresh() => load();

  Future<bool> create({
    required String namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) =>
      _mutasi(() => _repo.createSpesifikasi(
            idKategori: idKategori,
            namaSpesifikasi: namaSpesifikasi,
            tipeInput: tipeInput,
            satuan: satuan,
            opsi: opsi,
            urutan: urutan,
          ));

  Future<bool> update({
    required int id,
    String? namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) =>
      _mutasi(() => _repo.updateSpesifikasi(
            id: id,
            namaSpesifikasi: namaSpesifikasi,
            tipeInput: tipeInput,
            satuan: satuan,
            opsi: opsi,
            urutan: urutan,
          ));

  Future<bool> delete(int id) => _mutasi(() => _repo.deleteSpesifikasi(id));

  /// Simpan urutan baru checklist untuk kategori ini.
  Future<bool> reorder(List<int> urutanIds) =>
      _mutasi(() => _repo.reorderSpesifikasi(idKategori: idKategori, urutanIds: urutanIds));

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _mutasi(Future<void> Function() aksi) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await aksi();
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('MasterSpesifikasiNotifier mutasi gagal: $st');
      return false;
    }
  }
}

final masterSpesifikasiProvider = StateNotifierProvider.family<MasterSpesifikasiNotifier,
    MasterListState<Spesifikasi>, int>((ref, idKategori) {
  return MasterSpesifikasiNotifier(ref.watch(masterDataRepositoryProvider), idKategori);
});

// ============================================================================
// Alat
// ============================================================================

class MasterAlatNotifier extends StateNotifier<MasterListState<Alat>> {
  MasterAlatNotifier(this._repo) : super(const MasterListState<Alat>()) {
    load();
  }

  final MasterDataRepository _repo;

  /// Kata kunci pencarian alat (barcode/merk).
  String query = '';

  Future<void> load({String? query, int? idKategori, int? idLokasi}) async {
    if (query != null) this.query = query;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<Alat> list = await _repo.searchAlat(
        query: this.query.trim().isEmpty ? null : this.query.trim(),
        idKategori: idKategori,
        idLokasi: idLokasi,
      );
      state = state.copyWith(isLoading: false, items: list);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('MasterAlatNotifier.load gagal: $st');
    }
  }

  /// Ubah kata kunci lalu muat ulang.
  Future<void> search(String q) => load(query: q);

  Future<void> refresh() => load();

  Future<bool> create({
    required String barcodeAlat,
    required String merkAlat,
    required int idKategori,
    int? idLokasi,
  }) =>
      _mutasi(() => _repo.createAlat(
            barcodeAlat: barcodeAlat,
            merkAlat: merkAlat,
            idKategori: idKategori,
            idLokasi: idLokasi,
          ));

  Future<bool> update({
    required String barcode,
    String? merkAlat,
    int? idKategori,
    int? idLokasi,
  }) =>
      _mutasi(() => _repo.updateAlat(
            barcode: barcode,
            merkAlat: merkAlat,
            idKategori: idKategori,
            idLokasi: idLokasi,
          ));

  Future<bool> delete(String barcode) => _mutasi(() => _repo.deleteAlat(barcode));

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _mutasi(Future<void> Function() aksi) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await aksi();
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('MasterAlatNotifier mutasi gagal: $st');
      return false;
    }
  }
}

final masterAlatProvider =
    StateNotifierProvider<MasterAlatNotifier, MasterListState<Alat>>((ref) {
  return MasterAlatNotifier(ref.watch(masterDataRepositoryProvider));
});
