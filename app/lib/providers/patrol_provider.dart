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
    _muat();
  }

  /// True setelah percobaan muat pertama selesai (berhasil maupun gagal).
  bool _siap = false;
  bool get siap => _siap;

  Future<void> _muat() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final PatrolQueue q =
          PatrolQueue.deserialize(prefs.getString(PatrolQueue.storageKey));
      if (mounted) state = q;
    } catch (_) {
      // Gagal memuat: antrean tetap kosong, aplikasi tidak boleh crash.
    } finally {
      _siap = true;
      if (mounted) state = PatrolQueue(state.items);
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
  Future<bool> tambah(String barcode, {DateTime? pada}) async {
    if (!state.add(barcode, pada: pada)) return false;
    state = PatrolQueue(state.items);
    await _simpan();
    return true;
  }

  Future<void> hapus(String barcode) async {
    state.remove(barcode);
    state = PatrolQueue(state.items);
    await _simpan();
  }

  Future<void> kosongkan() async {
    state.clear();
    state = PatrolQueue();
    await _simpan();
  }

  /// Tandai hasil validasi `GET /alat/{barcode}` (AC-I4).
  Future<void> tandaiTervalidasi(String barcode) async {
    if (state.tandaiTervalidasi(barcode)) {
      state = PatrolQueue(state.items);
      await _simpan();
    }
  }

  Future<void> tandaiBelumValidasi(String barcode) async {
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
