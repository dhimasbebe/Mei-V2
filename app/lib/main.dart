import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/draft_provider.dart';
import 'providers/notif_provider.dart';
import 'providers/theme_provider.dart';

/// Entry point aplikasi Mei-V mobile.
///
/// Jalankan dengan:
///   flutter run --dart-define=API_BASE_URL=https://api.meiv.example/api/v1
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MeiVApp()));
}

class MeiVApp extends ConsumerWidget {
  const MeiVApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Muat antrean draf offline sejak aplikasi dibuka: memulihkan draf dari
    // shared_preferences, memasang listener konektivitas, dan mengirim
    // otomatis saat online (Tahap 3 — AC-A19).
    ref.watch(draftQueueProvider);

    // Muat preferensi pengingat harian & sinkronkan ke penjadwal OS
    // (web: stub no-op; kegagalan plugin tidak pernah membuat crash) —
    // Tahap 3 WS B, AC-B9.
    ref.watch(notifPrefsProvider);

    return MaterialApp.router(
      title: 'Mei-V',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
