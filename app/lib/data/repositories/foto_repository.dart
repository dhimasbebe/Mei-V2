import '../../domain/models/maintenance.dart';
import '../api/api_service.dart';

/// Akses endpoint foto lampiran (`/maintenance/{id}/foto`).
///
/// Fitur Tahap 3 (WS C). Semua pengunggahan lewat [ApiService.uploadFotoBytes]
/// sehingga jalur mobile (path lokal) dan web (bytes) memakai kode yang sama.
class FotoRepository {
  const FotoRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  /// Unggah satu foto (bytes) ke laporan [idMaintenance].
  Future<FotoLampiran> upload(
    int idMaintenance, {
    required List<int> bytes,
    required String namaFile,
  }) =>
      _api.uploadFotoBytes(idMaintenance, bytes: bytes, namaFile: namaFile);

  /// Daftar foto lampiran sebuah laporan.
  Future<List<FotoLampiran>> list(int idMaintenance) =>
      _api.getFotos(idMaintenance);

  /// Hapus foto (Supervisor/Admin).
  Future<void> hapus(int idFoto) => _api.deleteFoto(idFoto);
}
