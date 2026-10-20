import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/patrol/patrol_queue.dart';

/// State antrean patroli (WS I) + persistensi `shared_preferences`.
///
/// Modul murni [PatrolQueue] tidak menyentuh storage; seluruh efek samping
/// (baca/tulis `meiv.patrol_queue.v1`) berada di notifier ini supaya
/// `PatrolQueue` tetap dapat diuji lewat `dart.exe` (lihat `tools/modelcheck`).
class PatrolNotifier extends StateNotifier<PatrolQueue> {
  PatrolNotifier() : super(PatrolQueue()) {
    _muatSelesai = _muat();
  }

  /// Selesai setelah percobaan muat pertama rampung (berhasil maupun gagal).
  /// Semua mutator menunggu ini supaya tidak menimpa hasil muat — tanpa ini,
  /// pemindaian yang terjadi sebelum muat selesai bisa menghapus antrean lama
  /// di disk sekaligus membuang barcode yang baru masuk dari memori.
  late final Future<void> _muatSelesai;

  Future<void> _muat() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final PatrolQueue q =
          PatrolQueue.deserialize(prefs.getString(PatrolQueue.storageKey));
      if (mounted) state = q;
    } catch (_) {
      // Gagal memuat: antrean tetap kosong, aplikasi tidak boleh crash.
    }
  }

  Future<void> _simpan() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(PatrolQueue.storageKey, state.serialize());
    } catch (_) {
      // Persistensi gagal bukan alasan menghentikan patroli.
    }
  }

  /// Tambah barcode ke antrean. `false` = duplikat (AC-I1), tanpa perubahan.
  ///
  /// Menunggu [_muatSelesai] lebih dulu: menulis sebelum muat rampung akan
  /// menimpa antrean tersimpan dengan antrean kosong + satu barcode baru.
  Future<bool> tambah(String barcode, {DateTime? pada}) async {
    await _muatSelesai;
    if (!state.add(barcode, pada: pada)) return false;
    state = PatrolQueue(state.items);
    await _simpan();
    return true;
  }

  Future<void> hapus(String barcode) async {
    await _muatSelesai;
    state.remove(barcode);
    state = PatrolQueue(state.items);
    await _simpan();
  }

  /// Kosongkan antrean. Menunggu muat dulu supaya tidak mengosongkan antrean
  /// kosong yang kemudian diisi ulang oleh hasil muat (aksi jadi tak berefek).
  Future<void> kosongkan() async {
    await _muatSelesai;
    state.clear();
    state = PatrolQueue();
    await _simpan();
  }

  /// Tandai hasil validasi `GET /alat/{barcode}` (AC-I4).
  Future<void> tandaiTervalidasi(String barcode) async {
    await _muatSelesai;
    if (state.tandaiTervalidasi(barcode)) {
      state = PatrolQueue(state.items);
      await _simpan();
    }
  }

  Future<void> tandaiBelumValidasi(String barcode) async {
    await _muatSelesai;
    if (state.tandaiBelumValidasi(barcode)) {
      state = PatrolQueue(state.items);
      await _simpan();
    }
  }
}

/// Antrean patroli satu sesi kerja teknisi (WS I).
final patrolQueueProvider =
    StateNotifierProvider<PatrolNotifier, PatrolQueue>((ref) {
  return PatrolNotifier();
});
