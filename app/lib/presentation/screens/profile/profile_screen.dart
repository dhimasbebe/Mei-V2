import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_codec.dart';
import '../../../core/locale/teks.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/notif_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/press_button.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/section_header.dart';
import '../../../core/theme/app_palette.dart';

/// Layar Profil — isi menu menyesuaikan role.
///
/// Teknisi melihat pintasan pekerjaannya, Supervisor melihat pintasan
/// pengawasan, Admin melihat pintasan pengelolaan data. Ini bagian dari
/// permintaan "tampilan setiap role berbeda".
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(authProvider).user;

    if (user == null) {
      return const Center(child: Text('Tidak ada data pengguna.'));
    }

    // Teks dwibahasa khusus seksi bahasa (WS P). Seksi lain pada layar ini
    // masih berbahasa Indonesia — penerjemahan menyeluruh di luar rilis ini.
    final Teks teks = Teks(ref.watch(localeProvider));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: AppSizes.avatarRadiusLg,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              user.inisial,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            user.namaUsers,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.pal.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(child: RoleBadge(role: user.roleUsers, size: 30)),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader(
          title: 'Informasi pribadi',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoTile(icon: Icons.badge_outlined, label: 'NIP', value: user.username),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.emailUsers ?? '-',
        ),
        _InfoTile(
          icon: Icons.verified_user_outlined,
          label: 'Peran',
          value: user.roleTampil,
        ),

        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(
          title: 'Pintasan',
          subtitle: 'Sesuai peran Anda',
          icon: Icons.bolt_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        ..._pintasan(context, user),

        const SizedBox(height: AppSpacing.xl),
        // Tahap 3 WS E (AC-E7): sakelar tema Terang/Gelap/Sistem. Pilihan
        // disimpan di shared_preferences dan bertahan setelah ditutup.
        const SectionHeader(
          title: 'Tampilan',
          subtitle: 'Mode terang, gelap, atau ikut sistem',
          icon: Icons.dark_mode_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _PemilihTema(),

        const SizedBox(height: AppSpacing.xl),
        // Tahap 3 WS P (AC-P4/AC-P6): pemilih bahasa Indonesia/English.
        // Preferensi disimpan di perangkat dan tetap berlaku setelah aplikasi
        // ditutup. Judul & keterangan seksi ini ikut dwibahasa karena
        // pengguna harus bisa menemukan jalan kembali ke bahasa Indonesia.
        SectionHeader(
          title: teks.labelBahasa,
          subtitle: teks.subjudulBahasa,
          icon: Icons.translate,
        ),
        const SizedBox(height: AppSpacing.md),
        const _PemilihBahasa(),

        const SizedBox(height: AppSpacing.xl),
        // Tahap 3 WS B (AC-B9): sakelar pengingat harian. Bila izin notifikasi
        // OS ditolak, pengingat tetap tampil sebagai lencana/banner in-app.
        const SectionHeader(
          title: 'Pengingat',
          subtitle: 'Notifikasi harian alat jatuh tempo',
          icon: Icons.notifications_active_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _PemilihPengingat(),

        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Tentang', icon: Icons.info_outline),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.apps, color: AppColors.primary),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      AppStrings.appName,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'v2.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.pal.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Image.asset(
                    'assets/logos/logotelpro.png',
                    height: AppSizes.logoTelproFooter,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Telkom Property Surabaya Utara',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.pal.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        PressButton(
          label: 'KELUAR',
          variant: AppButtonVariant.outline,
          icon: Icon(Icons.logout, size: AppSizes.iconSm),
          onPressed: () => _konfirmasiKeluar(context, ref),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  List<Widget> _pintasan(BuildContext context, User user) {
    if (user.isAdmin) {
      return <Widget>[
        _Pintasan(
          icon: Icons.people_outline,
          label: 'Manajemen User',
          warna: AppColors.roleAdmin,
          onTap: () => context.go(Routes.dataUsers),
        ),
        _Pintasan(
          icon: Icons.storage_outlined,
          label: 'Master Data',
          warna: AppColors.roleSupervisor,
          onTap: () => context.go(Routes.dataMaster),
        ),
        _Pintasan(
          icon: Icons.qr_code_2,
          label: 'Manajemen Alat',
          warna: AppColors.roleTeknisi,
          onTap: () => context.go(Routes.dataAlat),
        ),
      ];
    }
    if (user.isSupervisor) {
      return <Widget>[
        _Pintasan(
          icon: Icons.fact_check_outlined,
          label: 'Verifikasi Laporan',
          warna: AppColors.roleSupervisor,
          onTap: () => context.go(Routes.verifikasi),
        ),
        _Pintasan(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard KPI',
          warna: AppColors.primaryDark,
          onTap: () => context.go(Routes.dashboard),
        ),
        // Tahap 3 WS D (AC-D10): menu riwayat audit untuk Supervisor.
        _Pintasan(
          icon: Icons.receipt_long_outlined,
          label: 'Riwayat Audit',
          warna: AppColors.statusWarning,
          onTap: () => context.go(Routes.auditLog),
        ),
      ];
    }
    return <Widget>[
      _Pintasan(
        icon: Icons.assignment_outlined,
        label: 'Tugas Hari Ini',
        warna: AppColors.roleTeknisi,
        onTap: () => context.go(Routes.tugas),
      ),
      _Pintasan(
        icon: Icons.qr_code_scanner,
        label: 'Scan Barcode',
        warna: AppColors.roleSupervisor,
        onTap: () => context.go(Routes.scan),
      ),
    ];
  }

  Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
    final bool? ya = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Keluar dari Mei-V?'),
        content: Text('Anda perlu masuk kembali untuk memakai aplikasi.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('KELUAR'),
          ),
        ],
      ),
    );
    if (ya ?? false) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _Pintasan extends StatelessWidget {
  const _Pintasan({
    required this.icon,
    required this.label,
    required this.warna,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: warna, size: AppSizes.iconMd),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.pal.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.pal.textSecondary,
              size: AppSizes.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.primary, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.pal.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.pal.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris pilihan tema (Terang / Gelap / Sistem) — AC-E7.
class _PemilihTema extends ConsumerWidget {
  const _PemilihTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);

    return AppCard(
      child: Column(
        children: <Widget>[
          _BarisTema(
            ikon: Icons.light_mode_outlined,
            label: 'Terang',
            terpilih: mode == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
          ),
          Divider(height: 1),
          _BarisTema(
            ikon: Icons.dark_mode_outlined,
            label: 'Gelap',
            terpilih: mode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
          ),
          Divider(height: 1),
          _BarisTema(
            ikon: Icons.settings_suggest_outlined,
            label: 'Sistem',
            terpilih: mode == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _BarisTema extends StatelessWidget {
  const _BarisTema({
    required this.ikon,
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              ikon,
              size: 20,
              color: terpilih ? AppColors.primary : context.pal.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: terpilih ? FontWeight.w700 : FontWeight.w400,
                  color: terpilih
                      ? AppColors.primary
                      : context.pal.textPrimary,
                ),
              ),
            ),
            if (terpilih)
              Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Sakelar "Pengingat harian" + pemilih jam (Tahap 3 WS B, AC-B9).
///
/// Preferensi disimpan di perangkat (`notifPrefsProvider`). Bila platform
/// tidak punya notifikasi OS atau izin ditolak, keterangan ditampilkan dan
/// pengingat in-app tetap aktif — tidak ada crash (AC-B7).
class _PemilihPengingat extends ConsumerWidget {
  const _PemilihPengingat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotifPrefsState prefs = ref.watch(notifPrefsProvider);
    final NotifPrefsNotifier notifier = ref.read(notifPrefsProvider.notifier);
    final AppPalette pal = context.pal;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: prefs.aktif,
            onChanged: (bool v) => notifier.setAktif(v),
            secondary: Icon(
              Icons.alarm,
              color: prefs.aktif ? AppColors.primary : pal.textSecondary,
            ),
            title: Text(
              'Pengingat harian',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
            subtitle: Text(
              prefs.jadwal.label,
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            ),
          ),
          if (prefs.aktif)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final TimeOfDay? pilih = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: prefs.jadwal.hour,
                      minute: prefs.jadwal.minute,
                    ),
                  );
                  if (pilih == null) return;
                  await notifier.setJam(
                    hour: pilih.hour,
                    minute: pilih.minute,
                  );
                },
                icon: Icon(Icons.schedule, size: AppSizes.iconSm),
                label: const Text('Ubah jam pengingat'),
              ),
            ),
          if (prefs.pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: AppSizes.iconSm,
                    color: AppColors.statusWarning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      prefs.pesan!,
                      style: TextStyle(fontSize: 11, color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pemilih bahasa Indonesia/English (Tahap 3 WS P, AC-P4/AC-P6).
///
/// Nilai terpilih dibaca dari `localeProvider`, yang memulihkan preferensi
/// tersimpan saat dibuat — jadi pemilih selalu mencerminkan pilihan terakhir
/// ketika layar dibuka. Perubahan ditulis lewat notifier yang sama sehingga
/// `MaterialApp.locale` (dan layar Login) langsung ikut berubah.
class _PemilihBahasa extends ConsumerWidget {
  const _PemilihBahasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocale aktif = ref.watch(localeProvider);
    final Teks teks = Teks(aktif);
    final AppPalette pal = context.pal;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.translate,
                color: AppColors.primary,
                size: AppSizes.iconMd,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '${teks.bahasaAktif}: ${LocaleCodec.labelSendiri(aktif)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLocale>(
              // Endonim: nama bahasa ditulis dalam bahasanya sendiri agar
              // tetap terbaca oleh penutur yang tidak memahami bahasa aktif.
              segments: <ButtonSegment<AppLocale>>[
                for (final AppLocale bahasa in LocaleCodec.didukung)
                  ButtonSegment<AppLocale>(
                    value: bahasa,
                    label: Text(LocaleCodec.label(bahasa)),
                  ),
              ],
              selected: <AppLocale>{aktif},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: pal.surfaceMuted,
                foregroundColor: pal.textPrimary,
                selectedBackgroundColor: AppColors.primarySoft,
                selectedForegroundColor: AppColors.primary,
                side: BorderSide(color: pal.divider),
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
              onSelectionChanged: (Set<AppLocale> pilihan) {
                final AppLocale? baru = pilihan.isEmpty ? null : pilihan.first;
                if (baru == null || baru == aktif) return;
                ref.read(localeProvider.notifier).ubah(baru);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Kejujuran cakupan: hanya Login yang sudah dwibahasa pada rilis ini.
          Text(
            teks.catatanBahasa,
            style: TextStyle(fontSize: 11, color: pal.textSecondary),
          ),
        ],
      ),
    );
  }
}
