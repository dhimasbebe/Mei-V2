import 'notif_schedule.dart';
import 'local_notifier.dart';

/// Implementasi cadangan untuk platform tanpa notifikasi OS (web/desktop
/// tanpa plugin) — semua operasi no-op (Tahap 3 WS B, AC-B7 jalur ganda).
class LocalNotifierStub extends LocalNotifier {
  const LocalNotifierStub();

  @override
  bool get didukung => false;

  @override
  Future<bool> init({void Function(String? payload)? onTap}) async => false;

  @override
  Future<bool> mintaIzin() async => false;

  @override
  Future<bool> jadwalkanHarian(NotifSchedule jadwal) async => false;

  @override
  Future<void> batalkan() async {}
}

/// Pabrik implementasi (dipilih lewat impor bersyarat di `notif_provider`).
LocalNotifier buatLocalNotifier() => const LocalNotifierStub();
