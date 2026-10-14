import 'package:flutter/services.dart';

/// Jembatan ke kode platform Android untuk membuka Pengaturan aplikasi.
///
/// Dibutuhkan agar pengguna yang menolak izin kamera secara permanen
/// ("Jangan tanya lagi") tetap punya jalan keluar — lihat state SC-3 pada
/// `docs/PRD-ROLE-UI-V2.md` §5.1.
///
/// Sengaja dibuat tanpa paket pub tambahan: kanal ini hanya memanggil
/// `MainActivity.kt`. Bila kanal tidak tersedia (mis. di web atau unit test),
/// pemanggilan mengembalikan `false` dan layar menampilkan pesan alternatif
/// alih-alih gagal diam-diam.
class SettingsChannel {
  const SettingsChannel._();

  static const MethodChannel _channel = MethodChannel('meiv/settings');

  /// Buka halaman Pengaturan aplikasi. `true` bila berhasil dibuka.
  static Future<bool> openAppSettings() async {
    try {
      final bool? hasil = await _channel.invokeMethod<bool>('openAppSettings');
      return hasil ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
