package com.meiv.meiv2

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity utama Mei-V2.
 *
 * Menyediakan kanal "meiv/settings" yang dipakai Dart
 * (`lib/core/services/settings_channel.dart`) untuk membuka halaman Pengaturan
 * aplikasi. Ini jalan keluar bagi pengguna yang menolak izin kamera secara
 * permanen: sistem tidak akan menampilkan dialog izin lagi, jadi satu-satunya
 * cara adalah mengaktifkannya manual di Pengaturan.
 *
 * Sengaja tidak memakai paket pub tambahan supaya ukuran APK tetap kecil dan
 * tidak ada dependensi baru yang perlu dipantau.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL_SETTINGS = "meiv/settings"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SETTINGS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null)
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
