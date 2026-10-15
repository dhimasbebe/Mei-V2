import 'notif_schedule.dart';

/// Antarmuka lapisan notifikasi OS (Tahap 3 — WS B).
///
/// Implementasi nyata (`local_notifier_io.dart`, paket
/// `flutter_local_notifications` + `timezone`) dipilih lewat impor bersyarat;
/// di web `local_notifier_stub.dart` dipakai sehingga tidak ada panggilan
/// plugin (AC-B6, AC-B7: jalur ganda — bila plugin gagal/izin ditolak,
/// aplikasi tetap berjalan dengan notifikasi in-app saja).
abstract class LocalNotifier {
  const LocalNotifier();

  /// `true` bila lapisan OS benar-benar tersedia di platform ini.
  bool get didukung;

  /// Menyiapkan plugin & zona waktu. Selalu aman dipanggil; kegagalan
  /// dikembalikan sebagai `false`, bukan exception.
  Future<bool> init({void Function(String? payload)? onTap});

  /// Meminta izin notifikasi (Android 13+ / iOS). `true` bila diberikan.
  Future<bool> mintaIzin();

  /// Menjadwalkan pengingat harian berulang pada jam [jadwal].
  Future<bool> jadwalkanHarian(NotifSchedule jadwal);

  /// Membatalkan pengingat harian yang aktif.
  Future<void> batalkan();
}
