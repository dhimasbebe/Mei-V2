import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/offline/draft_queue.dart';
import '../data/repositories/maintenance_repository.dart';
import '../domain/models/dashboard.dart';
import '../domain/models/maintenance.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => const MaintenanceRepository(),
);

/// Benih isi form untuk aksi "Duplikat laporan" (WS K).
///
/// [DraftTemplate.fromReport] membentuk draf baru (client_uuid baru, foto
/// kosong); layar riwayat menaruh hasilnya di sini SEBELUM membuka form,
/// lalu form membacanya sekali di `initState` untuk mengisi checklist,
/// catatan, dan kondisi keseluruhan. Provider langsung dikosongkan setelah
/// dibaca supaya tidak bocor ke form berikutnya.
final formSeedProvider = StateProvider<DraftRecord?>((ref) => null);

final maintenanceListProvider =
    StateNotifierProvider<MaintenanceListNotifier, AsyncValue<PagedResult<Maintenance>>>((ref) {
  return MaintenanceListNotifier(ref.watch(maintenanceRepositoryProvider));
});

class MaintenanceListNotifier extends StateNotifier<AsyncValue<PagedResult<Maintenance>>> {
  MaintenanceListNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final MaintenanceRepository _repo;

  Future<void> load({
    int page = 1,
    int perPage = 20,
    String? barcodeAlat,
    int? idKategori,
    String? username,
    String? statusVerifikasi,
    DateTime? dari,
    DateTime? sampai,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.getList(
        page: page,
        perPage: perPage,
        barcodeAlat: barcodeAlat,
        idKategori: idKategori,
        username: username,
        statusVerifikasi: statusVerifikasi,
        dari: dari,
        sampai: sampai,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> nextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.currentPage >= current.lastPage) return;
    try {
      final result = await _repo.getList(page: current.currentPage + 1);
      state = AsyncValue.data(
        PagedResult<Maintenance>(
          data: [...current.data, ...result.data],
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          total: result.total,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final maintenanceDetailProvider = FutureProvider.family<Maintenance, int>((ref, id) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getDetail(id);
});

/// State form pemeliharaan aktif (supaya UI bisa rebuild saat isi form berubah).
final maintenanceFormProvider =
    StateNotifierProvider<MaintenanceFormNotifier, MaintenancePayload?>((ref) {
  return MaintenanceFormNotifier();
});

class MaintenanceFormNotifier extends StateNotifier<MaintenancePayload?> {
  MaintenanceFormNotifier() : super(null);

  void init({required String barcodeAlat, required int idLokasi}) {
    state = MaintenancePayload(barcodeAlat: barcodeAlat, idLokasi: idLokasi, detail: const []);
  }

  void updateDetail(List<DetailMaintenance> detail) {
    if (state == null) return;
    state = MaintenancePayload(
      barcodeAlat: state!.barcodeAlat,
      idLokasi: state!.idLokasi,
      detail: detail,
      catatan: state!.catatan,
      kondisiKeseluruhan: state!.kondisiKeseluruhan,
    );
  }

  void updateCatatan(String? catatan) {
    if (state == null) return;
    state = MaintenancePayload(
      barcodeAlat: state!.barcodeAlat,
      idLokasi: state!.idLokasi,
      detail: state!.detail,
      catatan: catatan,
      kondisiKeseluruhan: state!.kondisiKeseluruhan,
    );
  }

  void updateKondisi(String? kondisi) {
    if (state == null) return;
    state = MaintenancePayload(
      barcodeAlat: state!.barcodeAlat,
      idLokasi: state!.idLokasi,
      detail: state!.detail,
      catatan: state!.catatan,
      kondisiKeseluruhan: kondisi,
    );
  }

  Future<Maintenance> submit(MaintenanceRepository repo) async {
    if (state == null) throw Exception('Form belum diinisialisasi.');
    return repo.submit(state!);
  }

  void reset() => state = null;
}
