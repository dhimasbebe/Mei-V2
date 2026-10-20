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

/// Asal laporan untuk penanda "Salinan dari laporan #N" (AC-K6).
///
/// Diisi layar riwayat bersama [formSeedProvider] saat aksi Duplikat dipakai,
/// lalu dibaca-sekali dan dikosongkan oleh form. Sengaja TIDAK dimasukkan ke
/// [DraftRecord] supaya format draf yang sudah tersimpan di perangkat
/// (`meiv.draft_queue.v1`) tidak berubah.
final salinanDariProvider = StateProvider<int?>((ref) => null);

final maintenanceListProvider =
    StateNotifierProvider<MaintenanceListNotifier, AsyncValue<PagedResult<Maintenance>>>((ref) {
  return MaintenanceListNotifier(ref.watch(maintenanceRepositoryProvider));
});

class MaintenanceListNotifier extends StateNotifier<AsyncValue<PagedResult<Maintenance>>> {
  MaintenanceListNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final MaintenanceRepository _repo;

  /// Filter yang sedang aktif, disimpan supaya [nextPage] memakai himpunan
  /// yang sama. Sebelumnya halaman berikutnya diambil tanpa filter apa pun,
  /// sehingga penyaringan `username`/status hilang dan Teknisi melihat
  /// laporan teknisi lain pada halaman 2 ke atas.
  int _perPage = 20;
  String? _barcodeAlat;
  int? _idKategori;
  String? _username;
  String? _statusVerifikasi;
  DateTime? _dari;
  DateTime? _sampai;

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
    _perPage = perPage;
    _barcodeAlat = barcodeAlat;
    _idKategori = idKategori;
    _username = username;
    _statusVerifikasi = statusVerifikasi;
    _dari = dari;
    _sampai = sampai;

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
      final result = await _repo.getList(
        page: current.currentPage + 1,
        perPage: _perPage,
        barcodeAlat: _barcodeAlat,
        idKategori: _idKategori,
        username: _username,
        statusVerifikasi: _statusVerifikasi,
        dari: _dari,
        sampai: _sampai,
      );
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

  /// Buka sesi form baru untuk satu alat.
  ///
  /// [clientUuid] dan [waktuMaintenance] opsional: dipakai saat memulihkan
  /// draf tersimpan (AC-A6) supaya sesi lanjutan memakai kunci idempotensi
  /// yang SAMA. Tanpa argumen, `MaintenancePayload` membuat kunci baru.
  void init({
    required String barcodeAlat,
    required int idLokasi,
    String? clientUuid,
    DateTime? waktuMaintenance,
  }) {
    state = MaintenancePayload(
      barcodeAlat: barcodeAlat,
      idLokasi: idLokasi,
      detail: const <DetailMaintenance>[],
      clientUuid: clientUuid,
      waktuMaintenance: waktuMaintenance,
    );
  }

  /// Adopsi kunci + waktu dari draf yang dipulihkan (AC-A6).
  ///
  /// Dipakai layar form setelah `FormDraftStore` mengembalikan draf lama:
  /// seluruh isian sesi ini harus terkirim dengan `client_uuid` yang sudah
  /// dipakai saat autosave, bukan kunci baru.
  void adopsiKunci({
    required String clientUuid,
    required DateTime waktuMaintenance,
  }) {
    if (state == null) return;
    state = MaintenancePayload(
      barcodeAlat: state!.barcodeAlat,
      idLokasi: state!.idLokasi,
      detail: state!.detail,
      catatan: state!.catatan,
      kondisiKeseluruhan: state!.kondisiKeseluruhan,
      clientUuid: clientUuid,
      waktuMaintenance: waktuMaintenance,
    );
  }

  /// Setiap pembangunan ulang WAJIB membawa `clientUuid` dan
  /// `waktuMaintenance` dari state sebelumnya.
  ///
  /// `MaintenancePayload` membuat UUID baru pada setiap konstruksi; tanpa
  /// penerusan ini satu sesi form menghasilkan banyak kunci, sehingga kirim
  /// ulang setelah gagal jaringan tidak pernah dicocokkan server sebagai
  /// duplikat (AC-A17) dan berakhir sebagai laporan kedua.
  void updateDetail(List<DetailMaintenance> detail) {
    if (state == null) return;
    state = MaintenancePayload(
      barcodeAlat: state!.barcodeAlat,
      idLokasi: state!.idLokasi,
      detail: detail,
      catatan: state!.catatan,
      kondisiKeseluruhan: state!.kondisiKeseluruhan,
      clientUuid: state!.clientUuid,
      waktuMaintenance: state!.waktuMaintenance,
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
      clientUuid: state!.clientUuid,
      waktuMaintenance: state!.waktuMaintenance,
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
      clientUuid: state!.clientUuid,
      waktuMaintenance: state!.waktuMaintenance,
    );
  }

  Future<Maintenance> submit(MaintenanceRepository repo) async {
    if (state == null) throw Exception('Form belum diinisialisasi.');
    return repo.submit(state!);
  }

  void reset() => state = null;
}
