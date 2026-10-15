import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notif/local_notifier.dart';
import '../core/notif/local_notifier_stub.dart'
    if (dart.library.io) '../core/notif/local_notifier_io.dart' as impl;
import '../core/notif/notif_schedule.dart';
import '../data/repositories/pengingat_repository.dart';
import '../domain/models/pengingat.dart';
import 'draft_provider.dart';

/// Kunci preferensi pengingat harian (AC-B9).
const String kNotifHarianKey = 'meiv.notif_harian';

/// Kunci jam pengingat dalam menit sejak tengah malam.
const String kNotifJamKey = 'meiv.notif_jam';

final pengingatRepositoryProvider = Provider<PengingatRepository>(
  (ref) => const PengingatRepository(),
);

/// Ringkasan + daftar pengingat dari `GET /pengingat` (AC-B1/B2/B7).
final pengingatProvider = FutureProvider<PengingatPayload>((ref) async {
  final PengingatRepository repo = ref.watch(pengingatRepositoryProvider);
  return repo.getPengingat();
});

/// Jumlah pengingat yang butuh perhatian (jatuh tempo + terlambat).
final pengingatTotalProvider = Provider<int>((ref) {
  final PengingatPayload? p = ref.watch(pengingatProvider).valueOrNull;
  if (p == null) return 0;
  return p.ringkasan.jatuhTempo + p.ringkasan.terlambat;
});

/// Lapisan notifikasi OS; di web otomatis memakai stub no-op (AC-B7).
final localNotifierProvider = Provider<LocalNotifier>(
  (ref) => impl.buatLocalNotifier(),
);

/// State preferensi pengingat harian.
@immutable
class NotifPrefsState {
  const NotifPrefsState({
    this.aktif = false,
    this.jadwal = const NotifSchedule(
      hour: NotifSchedule.defaultHour,
      minute: NotifSchedule.defaultMinute,
    ),
    this.osDidukung = false,
    this.izinDiberi = false,
    this.pesan,
  });

  /// Sakelar "Pengingat harian" (AC-B9).
  final bool aktif;
  final NotifSchedule jadwal;

  /// `true` bila platform punya notifikasi OS.
  final bool osDidukung;

  /// `true` bila izin notifikasi sudah diberikan.
  final bool izinDiberi;

  /// Keterangan tambahan untuk UI (mis. izin ditolak).
  final String? pesan;

  NotifPrefsState copyWith({
    bool? aktif,
    NotifSchedule? jadwal,
    bool? osDidukung,
    bool? izinDiberi,
    String? pesan,
    bool hapusPesan = false,
  }) {
    return NotifPrefsState(
      aktif: aktif ?? this.aktif,
      jadwal: jadwal ?? this.jadwal,
      osDidukung: osDidukung ?? this.osDidukung,
      izinDiberi: izinDiberi ?? this.izinDiberi,
      pesan: hapusPesan ? null : (pesan ?? this.pesan),
    );
  }
}

/// Menyimpan preferensi pengingat di perangkat dan menyinkronkannya ke
/// penjadwal OS. Kegagalan plugin tidak pernah membuat aplikasi crash.
class NotifPrefsNotifier extends StateNotifier<NotifPrefsState> {
  NotifPrefsNotifier(this._notifier) : super(const NotifPrefsState()) {
    unawaited(muat());
  }

  final LocalNotifier _notifier;

  Future<void> muat() async {
    final bool didukung = _notifier.didukung;
    bool aktif = false;
    int menit = NotifSchedule.defaultHour * 60 + NotifSchedule.defaultMinute;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      aktif = prefs.getBool(kNotifHarianKey) ?? false;
      menit = prefs.getInt(kNotifJamKey) ?? menit;
    } catch (_) {
      // Preferensi tidak terbaca: pakai default (nonaktif).
    }

    final NotifSchedule jadwal = NotifSchedule.dailyAt(
      hour: menit ~/ 60,
      minute: menit % 60,
    );

    if (!didukung) {
      state = state.copyWith(
        aktif: aktif,
        jadwal: jadwal,
        osDidukung: false,
        izinDiberi: false,
        pesan: aktif
            ? 'Notifikasi OS tidak tersedia di perangkat ini — pengingat '
                'tetap tampil di dalam aplikasi.'
            : null,
        hapusPesan: !aktif,
      );
      return;
    }

    final bool siap = await _notifier.init();
    bool izin = false;
    if (siap && aktif) {
      izin = await _notifier.mintaIzin();
      if (izin) {
        await _notifier.jadwalkanHarian(jadwal);
      }
    }
    if (!mounted) return;
    state = state.copyWith(
      aktif: aktif,
      jadwal: jadwal,
      osDidukung: siap,
      izinDiberi: izin,
      pesan: aktif && !izin
          ? 'Izin notifikasi ditolak — pengingat tetap tampil di dalam '
              'aplikasi.'
          : null,
      hapusPesan: !(aktif && !izin),
    );
  }

  /// Menyalakan/mematikan pengingat harian (AC-B9).
  Future<void> setAktif(bool aktif) async {
    NotifSchedule jadwal = state.jadwal;
    bool izin = state.izinDiberi;
    String? pesan;

    if (aktif && _notifier.didukung) {
      final bool siap = await _notifier.init();
      if (siap) {
        izin = await _notifier.mintaIzin();
        if (izin) {
          final bool ok = await _notifier.jadwalkanHarian(jadwal);
          if (!ok) {
            pesan = 'Penjadwalan notifikasi OS gagal — pengingat tetap '
                'tampil di dalam aplikasi.';
          }
        } else {
          pesan = 'Izin notifikasi ditolak — pengingat tetap tampil di '
              'dalam aplikasi.';
        }
      } else {
        pesan = 'Notifikasi OS tidak tersedia di perangkat ini.';
      }
    } else if (!aktif && _notifier.didukung) {
      await _notifier.batalkan();
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kNotifHarianKey, aktif);
    } catch (_) {
      // Gagal menyimpan: preferensi tetap berlaku untuk sesi ini.
    }

    if (!mounted) return;
    state = state.copyWith(
      aktif: aktif,
      izinDiberi: izin,
      pesan: pesan,
      hapusPesan: pesan == null,
    );
  }

  /// Mengubah jam pengingat; langsung dijadwalkan ulang bila sedang aktif.
  Future<void> setJam({required int hour, required int minute}) async {
    final NotifSchedule jadwal =
        NotifSchedule.dailyAt(hour: hour, minute: minute);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kNotifJamKey, jadwal.totalMenit);
    } catch (_) {
      // Diabaikan.
    }
    if (state.aktif && _notifier.didukung) {
      await _notifier.jadwalkanHarian(jadwal);
    }
    if (!mounted) return;
    state = state.copyWith(jadwal: jadwal);
  }
}

final notifPrefsProvider =
    StateNotifierProvider<NotifPrefsNotifier, NotifPrefsState>(
  (ref) => NotifPrefsNotifier(ref.watch(localNotifierProvider)),
);

/// Lencana tab "Tugas" (Teknisi): alat jatuh tempo/terlambat + draf offline
/// yang belum terkirim (AC-B7).
final badgeTugasTeknisiProvider = Provider<int>((ref) {
  final int pengingat = ref.watch(pengingatTotalProvider);
  final int draf = ref.watch(draftQueueProvider).jumlahMenunggu;
  return pengingat + draf;
});
