/// Antrean draf pemeliharaan offline — inti logika **Dart murni**.
///
/// Modul ini TIDAK boleh mengimpor `package:flutter`; seluruhnya diuji lewat
/// `dart.exe` (`tools/modelcheck`). Persistensi nyata (`shared_preferences`)
/// berada di lapisan provider, bukan di sini. Lihat
/// `docs/DESIGN-FEATURES-V3.md` §3.2 & §5.1.
library;

import 'dart:convert';

import 'draft_status.dart';

/// Satu draf pemeliharaan yang belum/telah dikirim ke server.
///
/// Bentuk ini adalah "kembaran" `MaintenancePayload` (POST /maintenance)
/// dengan tambahan metadata antrean: [status], [pesanError], [attempt],
/// [nextAttemptAt], [idMaintenanceServer], dan [fotoPaths].
class DraftRecord {
  const DraftRecord({
    required this.clientUuid,
    required this.barcodeAlat,
    required this.idLokasi,
    required this.waktuMaintenance,
    this.idKategori,
    this.checklist = const <int, String>{},
    this.catatan,
    this.kondisiKeseluruhan,
    this.fotoPaths = const <String>[],
    this.status = DraftStatus.menungguSinkron,
    this.pesanError,
    this.attempt = 0,
    this.nextAttemptAt,
    this.idMaintenanceServer,
    this.terkirimPada,
  });

  /// Kunci idempotensi (UUID v4) — TIDAK pernah dibuat ulang saat retry
  /// (AC-A10). Dibuat sekali oleh pemanggil (`MaintenancePayload._uuid()`).
  final String clientUuid;
  final String barcodeAlat;
  final int idLokasi;
  final int? idKategori;

  /// Waktu pemeliharaan yang dikirim ke server (`waktu_maintenance`).
  final DateTime waktuMaintenance;

  /// Peta `id_spesifikasi → status` hasil checklist dinamis.
  final Map<int, String> checklist;
  final String? catatan;
  final String? kondisiKeseluruhan;

  /// Path lokal foto lampiran (dalam urutan pemilihan).
  final List<String> fotoPaths;

  final DraftStatus status;

  /// Pesan alasan bila [status] `ditolakServer` / `ditahan`.
  final String? pesanError;

  /// Jumlah percobaan kirim (0 = belum pernah).
  final int attempt;

  /// Waktu paling awal percobaan berikutnya (dihitung dari [attempt]).
  final DateTime? nextAttemptAt;

  /// `id_maintenance` yang dikembalikan server setelah berhasil (AC-A10).
  final int? idMaintenanceServer;

  /// Cap waktu saat draf berhasil dikirim; dipakai [DraftQueue.purgeTerkirim]
  /// untuk retensi 7 hari. `null` selama draf belum terkirim.
  final DateTime? terkirimPada;

  /// Salinan dengan sebagian field diganti.
  DraftRecord copyWith({
    String? clientUuid,
    String? barcodeAlat,
    int? idLokasi,
    int? idKategori,
    DateTime? waktuMaintenance,
    Map<int, String>? checklist,
    String? catatan,
    String? kondisiKeseluruhan,
    List<String>? fotoPaths,
    DraftStatus? status,
    String? pesanError,
    int? attempt,
    DateTime? nextAttemptAt,
    int? idMaintenanceServer,
    DateTime? terkirimPada,
    bool clearPesanError = false,
    bool clearNextAttemptAt = false,
    bool clearIdMaintenanceServer = false,
    bool clearTerkirimPada = false,
  }) {
    return DraftRecord(
      clientUuid: clientUuid ?? this.clientUuid,
      barcodeAlat: barcodeAlat ?? this.barcodeAlat,
      idLokasi: idLokasi ?? this.idLokasi,
      idKategori: idKategori ?? this.idKategori,
      waktuMaintenance: waktuMaintenance ?? this.waktuMaintenance,
      checklist: checklist ?? this.checklist,
      catatan: catatan ?? this.catatan,
      kondisiKeseluruhan: kondisiKeseluruhan ?? this.kondisiKeseluruhan,
      fotoPaths: fotoPaths ?? this.fotoPaths,
      status: status ?? this.status,
      pesanError: clearPesanError ? null : (pesanError ?? this.pesanError),
      attempt: attempt ?? this.attempt,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      idMaintenanceServer: clearIdMaintenanceServer
          ? null
          : (idMaintenanceServer ?? this.idMaintenanceServer),
      terkirimPada: clearTerkirimPada ? null : (terkirimPada ?? this.terkirimPada),
    );
  }

  /// Serialisasi ke JSON yang aman disimpan sebagai satu string.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'client_uuid': clientUuid,
        'barcode_alat': barcodeAlat,
        'id_lokasi': idLokasi,
        'id_kategori': idKategori,
        'waktu_maintenance': waktuMaintenance.toIso8601String(),
        'checklist': checklist.map(
          (int k, String v) => MapEntry<String, String>('$k', v),
        ),
        'catatan': catatan,
        'kondisi_keseluruhan': kondisiKeseluruhan,
        'foto_paths': fotoPaths,
        'status': status.code,
        'pesan_error': pesanError,
        'attempt': attempt,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
        'id_maintenance_server': idMaintenanceServer,
        'terkirim_pada': terkirimPada?.toIso8601String(),
      };

  /// Membangun kembali draf dari JSON. Toleran terhadap field yang hilang
  /// (fail-safe: nilai default dipakai, tidak melempar exception).
  factory DraftRecord.fromJson(Map<String, dynamic> json) {
    final Map<int, String> checklist = <int, String>{};
    final Object? rawChecklist = json['checklist'];
    if (rawChecklist is Map) {
      rawChecklist.forEach((Object? k, Object? v) {
        final int? id = int.tryParse('$k');
        if (id != null) checklist[id] = '$v';
      });
    }

    final Object? fotoRaw = json['foto_paths'] ?? json['fotoPaths'];
    final List<String> fotoPaths = fotoRaw is List
        ? fotoRaw.map((Object? e) => '$e').toList(growable: false)
        : const <String>[];

    final Object? waktu = json['waktu_maintenance'] ?? json['waktuMaintenance'];

    return DraftRecord(
      clientUuid: '${json['client_uuid'] ?? json['clientUuid'] ?? ''}',
      barcodeAlat: '${json['barcode_alat'] ?? json['barcodeAlat'] ?? ''}',
      idLokasi:
          int.tryParse('${json['id_lokasi'] ?? json['idLokasi'] ?? 0}') ?? 0,
      idKategori: (json['id_kategori'] ?? json['idKategori']) == null
          ? null
          : int.tryParse('${json['id_kategori'] ?? json['idKategori']}'),
      waktuMaintenance: waktu == null ? DateTime.now() : (DateTime.tryParse('$waktu') ?? DateTime.now()),
      checklist: checklist,
      catatan: (json['catatan']) as String?,
      kondisiKeseluruhan: (json['kondisi_keseluruhan'] ??
          json['kondisiKeseluruhan']) as String?,
      fotoPaths: fotoPaths,
      status: DraftStatus.fromCode('${json['status']}'),
      pesanError: (json['pesan_error'] ?? json['pesanError']) as String?,
      attempt: int.tryParse('${json['attempt'] ?? 0}') ?? 0,
      nextAttemptAt: (json['next_attempt_at'] ?? json['nextAttemptAt']) == null
          ? null
          : DateTime.tryParse(
              '${json['next_attempt_at'] ?? json['nextAttemptAt']}'),
      idMaintenanceServer: (json['id_maintenance_server'] ??
              json['idMaintenanceServer']) ==
          null
          ? null
          : int.tryParse(
              '${json['id_maintenance_server'] ?? json['idMaintenanceServer']}'),
      terkirimPada: (json['terkirim_pada'] ?? json['terkirimPada']) == null
          ? null
          : DateTime.tryParse(
              '${json['terkirim_pada'] ?? json['terkirimPada']}'),
    );
  }

  /// Bentuk persis `POST /api/v1/maintenance` (lihat `MaintenancePayload`).
  ///
  /// `client_uuid` dikirim apa adanya untuk idempotensi server (AC-A17).
  Map<String, dynamic> toMaintenancePayload() => <String, dynamic>{
        'client_uuid': clientUuid,
        'barcode_alat': barcodeAlat,
        'id_lokasi': idLokasi,
        'waktu_maintenance': waktuMaintenance.toIso8601String(),
        'catatan': catatan,
        'kondisi_keseluruhan': kondisiKeseluruhan,
        'detail': checklist.entries
            .map((MapEntry<int, String> e) => <String, dynamic>{
                  'id_spesifikasi': e.key,
                  'status': e.value,
                })
            .toList(growable: false),
      };
}

/// Antrean FIFO draf pemeliharaan offline.
///
/// Seluruh operasi mengembalikan [bool] (bukan melempar exception) supaya
/// pemanggil dapat mengabaikan operasi yang tidak berdampak. Urutan [items]
/// = urutan masuk (FIFO), sehingga [nextPending] selalu draf tertua
/// (AC-A18).
class DraftQueue {
  DraftQueue([List<DraftRecord> initial = const <DraftRecord>[]])
      : _items = List<DraftRecord>.of(initial, growable: true);

  final List<DraftRecord> _items;

  /// Salinan tak-termutasi dari isi antrean (urutan FIFO).
  List<DraftRecord> get items => List<DraftRecord>.unmodifiable(_items);

  /// Jumlah draf di antrean (AC-A1, AC-A12).
  int get count => _items.length;

  /// Draf `menungguSinkron` TERTUA, atau `null` bila tak ada (AC-A18).
  DraftRecord? get nextPending {
    for (final DraftRecord d in _items) {
      if (d.status == DraftStatus.menungguSinkron) return d;
    }
    return null;
  }

  /// `true` bila ada draf berstatus [DraftStatus.ditahan] (AC-A15).
  bool get perluLoginUlang =>
      _items.any((DraftRecord d) => d.status == DraftStatus.ditahan);

  /// Menambah draf. Dedupe berdasarkan [DraftRecord.clientUuid]: draf dengan
  /// `clientUuid` yang sudah ada TIDAK ditambahkan lagi (AC-A1, AC-A3).
  ///
  /// Dua draf dengan `clientUuid` berbeda untuk barcode yang sama tetap
  /// tersimpan sebagai dua entri (AC-A2).
  void enqueue(DraftRecord draft) {
    final bool sudahAda =
        _items.any((DraftRecord d) => d.clientUuid == draft.clientUuid);
    if (sudahAda) return;
    _items.add(draft);
  }

  /// Menandai draf sedang dikirim.
  ///
  /// Mengembalikan `false` (dan tidak mengubah apa pun) bila draf tidak ada
  /// atau statusnya sudah [DraftStatus.sedangKirim] / [DraftStatus.terkirim]
  /// — mencegah kiriman ganda (AC-A13). [attempt] dinaikkan saat transisi.
  bool markSending(String uuid) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    final DraftRecord d = _items[i];
    if (d.status == DraftStatus.sedangKirim || d.status == DraftStatus.terkirim) {
      return false;
    }
    _items[i] = d.copyWith(
      status: DraftStatus.sedangKirim,
      attempt: d.attempt + 1,
      clearPesanError: true,
    );
    return true;
  }

  /// Menandai draf terkirim dan menyimpan `id_maintenance` server (AC-A10).
  ///
  /// Mengembalikan `false` bila draf tidak ditemukan.
  bool onSent(String uuid, int idMaintenance) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    _items[i] = _items[i].copyWith(
      status: DraftStatus.terkirim,
      idMaintenanceServer: idMaintenance,
      terkirimPada: DateTime.now(),
      clearPesanError: true,
      clearNextAttemptAt: true,
    );
    return true;
  }

  /// Jaringan putus di tengah unggah: kembalikan ke [DraftStatus.menungguSinkron]
  /// (bukan terkirim / ditolakServer) dan pertahankan `clientUuid` asli
  /// (AC-A10).
  bool onUploadFailed(String uuid, String reason) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    _items[i] = _items[i].copyWith(
      status: DraftStatus.menungguSinkron,
      pesanError: reason,
    );
    return true;
  }

  /// Server menolak dengan validasi (422): status [DraftStatus.ditolakServer],
  /// pesan error disimpan, dan TIDAK dikirim ulang otomatis (AC-A14).
  ///
  /// [errors] berbentuk `{field: [pesan, …]}`; dirangkai menjadi satu pesan.
  bool onRejected(String uuid, Map<String, List<String>> errors) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    final String pesan = _ringkasError(errors);
    _items[i] = _items[i].copyWith(
      status: DraftStatus.ditolakServer,
      pesanError: pesan.isEmpty ? 'Ditolak server.' : pesan,
      clearNextAttemptAt: true,
    );
    return true;
  }

  /// Token kedaluwarsa (401): tahan draf dan hentikan seluruh antrean;
  /// [perluLoginUlang] menjadi `true` (AC-A15).
  bool onUnauthorized(String uuid) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    _items[i] = _items[i].copyWith(
      status: DraftStatus.ditahan,
      pesanError: 'Sesi berakhir. Silakan masuk kembali.',
      clearNextAttemptAt: true,
    );
    return true;
  }

  /// Mengganti draf ber-`clientUuid` sama dengan [draft] di tempat (posisi
  /// FIFO dipertahankan). Mengembalikan `false` bila draf tidak ditemukan.
  bool replace(DraftRecord draft) {
    final int i = _indexOf(draft.clientUuid);
    if (i < 0) return false;
    _items[i] = draft;
    return true;
  }

  /// Menghapus draf ber-`clientUuid` [uuid]. `false` bila tidak ditemukan.
  bool remove(String uuid) {
    final int i = _indexOf(uuid);
    if (i < 0) return false;
    _items.removeAt(i);
    return true;
  }

  /// Menghapus draf berstatus [DraftStatus.terkirim] yang lebih tua dari  /// [simpan] (retensi default 7 hari — §12 U3). Umur dihitung dari
  /// [DraftRecord.terkirimPada]; draf terkirim tanpa cap waktu dibiarkan.
  void purgeTerkirim({Duration simpan = const Duration(days: 7)}) {
    final DateTime batas = DateTime.now().subtract(simpan);
    _items.removeWhere((DraftRecord d) {
      if (d.status != DraftStatus.terkirim) return false;
      final DateTime? selesai = d.terkirimPada;
      // Tanpa cap waktu selesai, tetap simpan (tidak bisa dinilai umurnya).
      if (selesai == null) return false;
      return selesai.isBefore(batas);
    });
  }

  /// Serialisasi seluruh antrean menjadi satu string JSON (untuk satu
  /// `setString` atomik — §5.1).
  String serialize() => jsonEncode(<String, dynamic>{
        'version': 1,
        'items': _items.map((DraftRecord d) => d.toJson()).toList(),
      });

  /// Membangun kembali antrean dari string JSON. String `null`/kosong atau
  /// rusak menghasilkan antrean kosong (tidak melempar exception) — round-trip
  /// dengan [serialize] menghasilkan antrean identik (AC-A4).
  factory DraftQueue.deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DraftQueue();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        final Object? items = decoded['items'];
        if (items is List) {
          final List<DraftRecord> drafts = items
              .whereType<Map<String, dynamic>>()
              .map(DraftRecord.fromJson)
              .toList(growable: false);
          return DraftQueue(drafts);
        }
      }
      // Bentuk lama: array langsung.
      if (decoded is List) {
        final List<DraftRecord> drafts = decoded
            .whereType<Map<String, dynamic>>()
            .map(DraftRecord.fromJson)
            .toList(growable: false);
        return DraftQueue(drafts);
      }
    } catch (_) {
      // Abaikan: kembalikan antrean kosong.
    }
    return DraftQueue();
  }

  int _indexOf(String uuid) =>
      _items.indexWhere((DraftRecord d) => d.clientUuid == uuid);

  static String _ringkasError(Map<String, List<String>> errors) {
    final List<String> bagian = <String>[];
    errors.forEach((String field, List<String> pesan) {
      for (final String p in pesan) {
        bagian.add('$field: $p');
      }
    });
    return bagian.join('; ');
  }
}
