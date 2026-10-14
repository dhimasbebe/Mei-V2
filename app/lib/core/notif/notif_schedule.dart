/// Jadwal pengingat harian — **Dart murni** (tanpa `package:flutter`).
///
/// Modul ini hanya memodelkan *jam* pengingat pada zona `Asia/Jakarta`.
/// Penjadwalan OS yang sesungguhnya (paket `flutter_local_notifications` +
/// `timezone`, bila disetujui) dibungkus di `core/notif/local_notifier.dart`.
/// Lihat `docs/DESIGN-FEATURES-V3.md` §5 (WS B).
library;

/// Spesifikasi satu jadwal pengingat harian.
class NotifSchedule {
  const NotifSchedule({
    required this.hour,
    required this.minute,
    this.timezone = zona,
  });

  /// Zona waktu acuan pengingat (WIB).
  static const String zona = 'Asia/Jakarta';

  /// Jam default pengingat pagi.
  static const int defaultHour = 7;

  /// Menit default pengingat.
  static const int defaultMinute = 0;

  /// Jam (0–23) pengingat harian.
  final int hour;

  /// Menit (0–59) pengingat harian.
  final int minute;

  /// Zona waktu (nama IANA), default [zona].
  final String timezone;

  /// Jadwal harian pada [hour]:[minute] zona [timezone] (AC-B5).
  ///
  /// Nilai `hour`/`minute` di-clamp ke rentang valid.
  static NotifSchedule dailyAt({
    int hour = defaultHour,
    int minute = defaultMinute,
    String timezone = zona,
  }) {
    return NotifSchedule(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
      timezone: timezone,
    );
  }

  /// Pengingat ini berulang tiap hari.
  bool get harian => true;

  /// Total menit sejak tengah malam (untuk perbandingan/pengurutan).
  int get totalMenit => hour * 60 + minute;

  /// Label tampilan, mis. `"07:00 (Asia/Jakarta)"`.
  String get label {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(hour)}:${p(minute)} ($timezone)';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hour': hour,
        'minute': minute,
        'timezone': timezone,
      };

  factory NotifSchedule.fromJson(Map<String, dynamic> json) {
    return NotifSchedule(
      hour: (int.tryParse('${json['hour'] ?? defaultHour}') ?? defaultHour)
          .clamp(0, 23),
      minute:
          (int.tryParse('${json['minute'] ?? defaultMinute}') ?? defaultMinute)
              .clamp(0, 59),
      timezone: (json['timezone'] as String?) ?? zona,
    );
  }
}
