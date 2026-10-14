/// Tabel aksi geser (swipe) per peran & layar — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2
/// & §5.5.
library;

/// Jenis aksi geser yang tersedia.
enum SwipeActionType {
  /// Menyetujui laporan verifikasi (Supervisor).
  setujui,

  /// Menolak laporan verifikasi (Supervisor); wajib isi komentar.
  tolak,

  /// Menghapus baris data (Admin); wajib dialog konfirmasi ganda.
  hapus,
}

/// Penentu aksi geser berdasarkan peran pengguna & nama layar.
abstract class SwipeAction {
  const SwipeAction._();

  /// Layar verifikasi (Supervisor).
  static const Set<String> _layarVerifikasi = <String>{'verifikasi'};

  /// Layar manajemen data (Admin).
  static const Set<String> _layarData = <String>{
    'data',
    'user_management',
    'master_data',
    'alat_management',
  };

  /// Aksi yang boleh digeser oleh [role] pada [layar].
  ///
  /// * `('Supervisor','verifikasi')` → `[setujui, tolak]` (AC-H2).
  /// * `('Admin','data')` → `[hapus]` (AC-H2).
  /// * Teknisi / kombinasi lain → daftar kosong (AC-H2).
  static List<SwipeActionType> forRole(String role, String layar) {
    final String r = role.trim().toLowerCase();
    final String l = layar.trim().toLowerCase();

    if (r == 'supervisor' && _layarVerifikasi.contains(l)) {
      return const <SwipeActionType>[
        SwipeActionType.setujui,
        SwipeActionType.tolak,
      ];
    }
    if (r == 'admin' && _layarData.contains(l)) {
      return const <SwipeActionType>[SwipeActionType.hapus];
    }
    return const <SwipeActionType>[];
  }

  /// `true` bila [aksi] memerlukan dialog konfirmasi sebelum dijalankan.
  ///
  /// Hanya [SwipeActionType.hapus] yang butuh konfirmasi ganda; `setujui`
  /// dan `tolak` tidak (AC-H3).
  static bool confirmRequired(SwipeActionType aksi) =>
      aksi == SwipeActionType.hapus;
}
