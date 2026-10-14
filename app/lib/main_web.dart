import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Entry point dashboard web Mei-V.
///
/// Jalankan dengan:
///   flutter run -d chrome --target lib/main_web.dart --dart-define=API_BASE_URL=https://api.meiv.example/api/v1
///   flutter build web --target lib/main_web.dart --dart-define=API_BASE_URL=https://api.meiv.example/api/v1
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MeiVWebApp()));
}

class MeiVWebApp extends ConsumerWidget {
  const MeiVWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Mei-V Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
