import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notifier.dart';
import 'notif_schedule.dart';

/// Notifikasi OS lokal (Android/iOS) — Tahap 3 WS B.
///
/// Jalur ganda: bila plugin tidak tersedia, izin ditolak, atau penjadwalan
/// gagal (mis. mode hemat baterai), seluruh metode mengembalikan `false`
/// dan aplikasi tetap berjalan dengan lencana/banner in-app (AC-B7).
/// Zona waktu diikat ke `Asia/Jakarta` (WIB) sesuai [NotifSchedule.zona].
class LocalNotifierIo extends LocalNotifier {
  LocalNotifierIo();

  /// Kanal Android agar pengguna dapat mengatur sendiri di pengaturan OS.
  static const String channelId = 'meiv_pengingat';
  static const String channelName = 'Pengingat Harian';
  static const String channelDesc =
      'Pengingat pemeliharaan alat Mei-V (jatuh tempo & terlambat).';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _siap = false;

  @override
  bool get didukung => !kIsWeb;

  @override
  Future<bool> init({void Function(String? payload)? onTap}) async {
    if (kIsWeb) return false;
    if (_siap) return true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(NotifSchedule.zona));

      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings awal =
          InitializationSettings(android: android, iOS: ios);

      final bool? ok = await _plugin.initialize(
        awal,
        onDidReceiveNotificationResponse: (NotificationResponse r) =>
            onTap?.call(r.payload),
      );
      await _buatKanal();
      _siap = ok ?? true;
      return _siap;
    } catch (_) {
      // Plugin tidak tersedia (mis. desktop tanpa implementasi) — abaikan.
      _siap = false;
      return false;
    }
  }

  Future<void> _buatKanal() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.defaultImportance,
        ),
      );
    } catch (_) {
      // Kanal gagal dibuat: notifikasi tetap memakai kanal default.
    }
  }

  @override
  Future<bool> mintaIzin() async {
    if (kIsWeb) return false;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final bool? diberi = await android.requestNotificationsPermission();
        return diberi ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final bool? diberi = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return diberi ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> jadwalkanHarian(NotifSchedule jadwal) async {
    if (kIsWeb) return false;
    if (!_siap) {
      final bool ok = await init();
      if (!ok) return false;
    }
    try {
      final tz.TZDateTime kapan = _berikutnya(jadwal);
      await _plugin.zonedSchedule(
        NotifSchedule.notifId,
        'Pengingat Pemeliharaan',
        'Periksa alat yang jatuh tempo atau terlambat hari ini.',
        kapan,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'pengingat',
      );
      return true;
    } catch (_) {
      // Penjadwalan tepat gagal (izin/baterai): notifikasi in-app tetap ada.
      return false;
    }
  }

  /// Waktu kemunculan pertama di zona `Asia/Jakarta` (AC-B5).
  tz.TZDateTime _berikutnya(NotifSchedule jadwal) {
    final tz.TZDateTime sekarang = tz.TZDateTime.now(tz.local);
    final DateTime berikut = jadwal.nextOccurrence(sekarang);
    return tz.TZDateTime(
      tz.local,
      berikut.year,
      berikut.month,
      berikut.day,
      berikut.hour,
      berikut.minute,
    );
  }

  @override
  Future<void> batalkan() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(NotifSchedule.notifId);
    } catch (_) {
      // Tidak ada yang perlu dibatalkan.
    }
  }
}

/// Pabrik implementasi OS (dipilih lewat impor bersyarat di `notif_provider`).
LocalNotifier buatLocalNotifier() => LocalNotifierIo();
