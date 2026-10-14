import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import 'admin_home_screen.dart';
import 'supervisor_home_screen.dart';
import 'teknisi_home_screen.dart';

/// Pemilih beranda sesuai role pengguna yang sedang masuk.
///
/// Router memakai widget ini untuk rute `/` dan `/tugas` sehingga ketiga role
/// benar-benar mendapat halaman berbeda tanpa menggandakan definisi rute.
class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (user.isAdmin) return const AdminHomeScreen();
    if (user.isSupervisor) return const SupervisorHomeScreen();
    return const TeknisiHomeScreen();
  }
}
