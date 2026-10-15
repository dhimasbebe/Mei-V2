/// Model hasil impor CSV alat (WS M, Fitur Tahap 3) — DART MURNI, tanpa
/// package:flutter sehingga dapat diverifikasi `tools/modelcheck`.
///
/// Kontrak JSON mengikuti respons backend:
/// - `POST /api/v1/alat/impor/preview` → [AlatImportResult]
/// - `POST /api/v1/alat/impor/commit`  → [AlatImportResult] (diimpor/gagal)
///
/// AC-M6: `AlatImportResult.fromJson()` memetakan fixture hasil preview
/// (valid/error per baris) tanpa error. Lihat `docs/DESIGN-FEATURES-V3.md` §C.1.4.
library;

/// Satu baris CSV gagal validasi.
///
/// Backend mengirim `{ "baris": <int>, "pesan": "<string>" }` — nomor baris
/// FISIK berkas (1-based, baris header tetap dihitung) agar admin dapat
/// menemukannya langsung.
class AlatImportError {
  const AlatImportError({required this.baris, required this.pesan});

  /// Nomor baris fisik dalam berkas CSV.
  final int baris;

  /// Penjelasan kegagalan (mis. "Barcode 'AC-001' sudah terdaftar di database").
  final String pesan;

  factory AlatImportError.fromJson(Map<String, dynamic> json) => AlatImportError(
        baris: int.tryParse('${json['baris'] ?? 0}') ?? 0,
        pesan: (json['pesan'] ?? json['message'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'baris': baris, 'pesan': pesan};
}

/// Hasil preview/commit impor CSV — `data` dari endpoint impor.
///
/// `total` = jumlah baris data CSV (baris header tidak dihitung);
/// `jumlahValid` = total dikurangi baris gagal; `error` = daftar per baris.
class AlatImportResult {
  const AlatImportResult({
    required this.total,
    required this.jumlahValid,
    this.error = const <AlatImportError>[],
  });

  /// Jumlah baris CSV.
  final int total;

  /// Jumlah baris valid (siap diimpor / berhasil diimpor).
  final int jumlahValid;

  /// Baris gagal beserta alasannya (kosong bila seluruhnya valid).
  final List<AlatImportError> error;

  int get jumlahGagal => total - jumlahValid;

  bool get semuaValid => error.isEmpty && total > 0;

  bool get tidakAdaBarisValid => total == 0 || jumlahValid == 0;

  /// Teks tombol aksi preview: "Impor N baris valid" (AC-M8).
  String get labelTombolImpor => 'Impor $jumlahValid baris valid';

  factory AlatImportResult.fromJson(Map<String, dynamic> json) {
    final Object? errorRaw = json['error'];
    final List<AlatImportError> error = errorRaw is List
        ? errorRaw
            .whereType<Map<String, dynamic>>()
            .map(AlatImportError.fromJson)
            .toList(growable: false)
        : const <AlatImportError>[];

    final int total = int.tryParse('${json['total'] ?? 0}') ?? 0;
    final int? jumlahValid = json['jumlah_valid'] == null
        ? null
        : int.tryParse('${json['jumlah_valid']}');

    return AlatImportResult(
      total: total,
      // Commit mengirim `diimpor`; preview mengirim `jumlah_valid`.
      jumlahValid: jumlahValid ?? int.tryParse('${json['diimpor'] ?? 0}') ?? 0,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'total': total,
        'jumlah_valid': jumlahValid,
        'error': error.map((AlatImportError e) => e.toJson()).toList(),
      };
}
