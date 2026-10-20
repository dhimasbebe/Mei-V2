import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/media/photo_store.dart';
import '../core/offline/draft_queue.dart';
import '../core/offline/draft_status.dart';
import '../core/offline/retry_policy.dart';
import '../data/api/api_exception.dart';
import '../data/repositories/foto_repository.dart';
import '../domain/models/maintenance.dart';
import 'auth_provider.dart';
import 'maintenance_provider.dart';

/// Kunci `SharedPreferences` tempat seluruh antrean draf disimpan sebagai
/// SATU string JSON (`docs/DESIGN-FEATURES-V3.md` §5.1).
const String kDraftQueueKey = 'meiv.draft_queue.v1';

/// State UI antrean offline.
///
/// [antrean] selalu instansi `DraftQueue` BARU setiap notifikasi agar
/// `StateNotifier` memberi tahu pendengar bahwa isi berubah.
@immutable
class DraftState {
  const DraftState({
    required this.antrean,
    this.sedangSinkron = false,
    this.online = true,
  });

  final DraftQueue antrean;
  final bool sedangSinkron;
  final bool online;

  /// Draf yang masih menunggu / tertahan sinkron.
  int get jumlahMenunggu => antrean.items
      .where((DraftRecord d) =>
          d.status == DraftStatus.menungguSinkron ||
          d.status == DraftStatus.sedangKirim ||
          d.status == DraftStatus.ditahan)
      .length;

  int get jumlahTerkirim => antrean.items
      .where((DraftRecord d) => d.status == DraftStatus.terkirim)
      .length;

  int get jumlahDitolak => antrean.items
      .where((DraftRecord d) => d.status == DraftStatus.ditolakServer)
      .length;

  bool get perluLoginUlang => antrean.perluLoginUlang;
}

/// Notifier antrean draf offline.
///
/// Tanggung jawab (`docs/DESIGN-FEATURES-V3.md` §3.2, §5.1):
/// - memuat/menyimpan antrean ke `shared_preferences` (satu kunci JSON);
/// - memantau konektivitas (`connectivity_plus`) dan mengirim otomatis
///   saat kembali online (AC-A19);
/// - mengirim draf tertua lebih dulu (FIFO, AC-A18) dengan idempotensi
///   `client_uuid`, unggah foto setelah laporan berhasil dibuat;
/// - menerapkan backoff [RetryPolicy] pada kegagalan jaringan, menghentikan
///   seluruh antrean saat 401 (AC-A15), dan tidak mengulang otomatis draf
///   yang ditolak server 422/403 (AC-A14, AC-A16).
class DraftNotifier extends StateNotifier<DraftState> {
  DraftNotifier(this._ref) : super(DraftState(antrean: DraftQueue())) {
    // Muat antrean tersimpan tanpa menunda konstruksi provider.
    unawaited(_init());
  }

  final Ref _ref;

  DraftQueue _queue = DraftQueue();
  bool _sedangSinkron = false;
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _subKoneksi;

  Future<void> _init() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DraftQueue q =
          DraftQueue.deserialize(prefs.getString(kDraftQueueKey));
      q.purgeTerkirim(); // retensi 7 hari (§12 U3)
      _queue = q;
      _publish();
    } catch (_) {
      // Gagal memuat: antrean tetap kosong, jangan pernah crash aplikasi.
    }

    _mulaikanListenerKoneksi();
    unawaited(syncNow());
  }

  /// Berlangganan perubahan konektivitas; kembali online → kirim otomatis
  /// (AC-A19).
  void _mulaikanListenerKoneksi() {
    try {
      _subKoneksi?.cancel();
      _subKoneksi = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> hasil) {
        final bool online =
            hasil.any((ConnectivityResult r) => r != ConnectivityResult.none);
        final bool sebelumnya = _online;
        _online = online;
        _publish();
        if (online && !sebelumnya) {
          unawaited(syncNow());
        }
      });
    } catch (_) {
      // Plugin tidak tersedia (mis. platform tak didukung): abaikan.
    }
  }

  // ------------------------------------------------------------------
  // API publik untuk UI
  // ------------------------------------------------------------------

  /// Menyimpan draf ke antrean (AC-A12: draf belum lengkap pun boleh
  /// disimpan). Langsung dicoba kirim bila online.
  Future<void> simpanDraf(DraftRecord draf) async {
    _queue.enqueue(draf);
    _publish();
    await _persist();
    unawaited(syncNow());
  }

  /// Mengganti isi draf (mis. foto bertambah sebelum laporan terkirim).
  Future<void> perbaruiDraf(DraftRecord draf) async {
    _queue.replace(draf);
    _publish();
    await _persist();
  }

  /// Menghapus draf dari antrean (dibatalkan pengguna).
  Future<void> hapusDraf(String clientUuid) async {
    _queue.remove(clientUuid);
    _publish();
    await _persist();
  }

  /// Mengosongkan draf terkirim (pembersihan manual).
  Future<void> bersihkanTerkirim() async {
    _queue.purgeTerkirim();
    _publish();
    await _persist();
  }

  /// Pengguna meminta draf yang ditolak server dicoba lagi:
  /// status kembali `menungguSinkron` dan sinkron dijalankan.
  Future<void> cobaLagi(String clientUuid) async {
    final DraftRecord? draf = _cari(clientUuid);
    if (draf == null) return;
    _queue.replace(draf.copyWith(
      status: DraftStatus.menungguSinkron,
      clearPesanError: true,
      clearNextAttemptAt: true,
    ));
    _publish();
    await _persist();
    unawaited(syncNow());
  }

  /// Mengirim seluruh draf yang memenuhi syarat (FIFO, AC-A18).
  ///
  /// Aman dipanggil berkali-kali: reentrant call diabaikan.
  Future<void> syncNow() async {
    if (_sedangSinkron || !_online) return;
    if (!_ref.read(authProvider).isAuthenticated) return;

    _sedangSinkron = true;
    _publish();
    try {
      while (true) {
        final DraftRecord? draf = _queue.nextPending;
        if (draf == null) break;
        // Draf terdepan masih menunggu backoff — hentikan (FIFO adil).
        final DateTime? jeda = draf.nextAttemptAt;
        if (jeda != null && jeda.isAfter(DateTime.now())) break;

        if (!_queue.markSending(draf.clientUuid)) break;
        _publish();

        try {
          final Maintenance laporan =
              await _ref.read(maintenanceRepositoryProvider).submit(
                    _payloadDari(draf),
                  );
          _queue.onSent(draf.clientUuid, laporan.idMaintenance);

          // Unggah foto lampiran setelah laporan ada (butuh id_maintenance).
          await _unggahFoto(laporan.idMaintenance, draf.fotoPaths);

          _publish();
          await _persist();
        } catch (e) {
          final bool lanjutkan = _tanganiKegagalan(draf, e);
          if (!lanjutkan) break; // 401 / 422 / 403 → antrean berhenti.
        }
      }
    } finally {
      _sedangSinkron = false;
      _publish();
    }
  }

  @override
  void dispose() {
    _subKoneksi?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Internal
  // ------------------------------------------------------------------

  FotoRepository get _fotoRepo => _ref.read(fotoRepositoryProvider);

  /// Memetakan [DraftRecord] ke payload `POST /maintenance` — `client_uuid`
  /// asli diteruskan agar kirim ulang bersifat idempoten (AC-A17).
  MaintenancePayload _payloadDari(DraftRecord d) => MaintenancePayload(
        barcodeAlat: d.barcodeAlat,
        idLokasi: d.idLokasi,
        detail: d.checklist.entries
            .map((MapEntry<int, String> e) => DetailMaintenance(
                  idSpesifikasi: e.key,
                  status: e.value,
                ))
            .toList(growable: false),
        catatan: d.catatan,
        kondisiKeseluruhan: d.kondisiKeseluruhan,
        waktuMaintenance: d.waktuMaintenance,
        clientUuid: d.clientUuid,
      );

  Future<void> _unggahFoto(int idMaintenance, List<String> paths) async {
    for (final String kunci in paths) {
      final List<int>? bytes = await PhotoStore.baca(kunci);
      if (bytes == null) continue; // berkas hilang: lewati, jangan gagalkan.
      await _fotoRepo.upload(
        idMaintenance,
        bytes: bytes,
        namaFile: _namaBerkas(kunci),
      );
    }
  }

  /// Mengklasifikasikan kegagalan kirim. Mengembalikan `true` bila antrean
  /// boleh melanjutkan ke draf berikutnya.
  bool _tanganiKegagalan(DraftRecord draf, Object e) {
    ApiException? api;
    if (e is DioException) {
      final Object? err = e.error;
      if (err is ApiException) api = err;
    } else if (e is ApiException) {
      api = e;
    }

    if (api is UnauthorizedException) {
      // 401: tahan draf ini dan HENTIKAN seluruh antrean (AC-A15).
      _queue.onUnauthorized(draf.clientUuid);
      _publish();
      _persist();
      return false;
    }
    if (api is ForbiddenException) {
      // 403: peran tidak berhak — tidak diulang otomatis (AC-A16).
      _queue.onRejected(draf.clientUuid, <String, List<String>>{
        'role': <String>[api.message],
      });
      _publish();
      _persist();
      return false;
    }
    if (api is ValidationException) {
      // 422: data ditolak — tidak diulang otomatis (AC-A14).
      _queue.onRejected(
        draf.clientUuid,
        api.errors ??
            <String, List<String>>{'validasi': <String>[api.message]},
      );
      _publish();
      _persist();
      return false;
    }

    // Jaringan / server: kembali `menungguSinkron`, jadwalkan backoff
    // eksponensial (AC-A10, AC-A11) lalu lanjutkan antrean berikutnya.
    //
    // `attempt` sudah dinaikkan oleh `DraftQueue.markSending` sebelum unggah,
    // jadi `attempt - 1` adalah indeks percobaan 0-based yang dipakai
    // `RetryPolicy` (5s, 10s, 20s, 40s, lalu mentok 60s).
    _queue.onUploadFailed(
        draf.clientUuid, api?.message ?? 'Koneksi terputus.');
    final DraftRecord? terkini = _cari(draf.clientUuid);
    if (terkini != null) {
      _queue.replace(terkini.copyWith(
        nextAttemptAt:
            DateTime.now().add(RetryPolicy.nextDelay(terkini.attempt - 1 < 0 ? 0 : terkini.attempt - 1)),
      ));
    }
    _publish();
    _persist();
    return true;
  }

  DraftRecord? _cari(String clientUuid) {
    for (final DraftRecord d in _queue.items) {
      if (d.clientUuid == clientUuid) return d;
    }
    return null;
  }

  void _publish() {
    state = DraftState(
      antrean: DraftQueue(_queue.items),
      sedangSinkron: _sedangSinkron,
      online: _online,
    );
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(kDraftQueueKey, _queue.serialize());
    } catch (_) {
      // Penyimpanan penuh/terkunci: draf tetap ada di memori untuk sesi ini.
    }
  }

  static String _namaBerkas(String kunci) {
    final String bersih = kunci.replaceAll('\\', '/');
    final int i = bersih.lastIndexOf('/');
    return i < 0 ? bersih : bersih.substring(i + 1);
  }
}

final fotoRepositoryProvider = Provider<FotoRepository>((ref) {
  return const FotoRepository();
});

final draftQueueProvider =
    StateNotifierProvider<DraftNotifier, DraftState>((ref) {
  return DraftNotifier(ref);
});
