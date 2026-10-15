import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../app_button.dart';
import '../press_button.dart';

/// Panel keadaan layar Scan.
///
/// Setiap state pada `docs/PRD-ROLE-UI-V2.md` §5.1 wajib menampilkan
/// penjelasan DAN minimal satu tombol yang bisa ditekan — inilah yang
/// menggantikan "tanda seru tanpa apa pun" bawaan `mobile_scanner`.
///
/// [actions] diisi tombol aksi dari pemanggil supaya panel ini tetap generik
/// dan bisa dipakai untuk izin ditolak, kamera tidak tersedia, barcode tidak
/// terdaftar, maupun offline.
class ScanStateView extends StatelessWidget {
  const ScanStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.warna = AppColors.primary,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color warna;
  final List<Widget> actions;

  /// Versi ringkas untuk state yang ditumpuk di atas pratinjau kamera.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.raised,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: compact ? 28 : 36, color: warna),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: pal.textSecondary,
                ),
              ),
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                ...actions.map(
                  (Widget a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: a,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol aksi siap pakai untuk [ScanStateView] dengan ikon kecil.
class ScanActionButton extends StatelessWidget {
  const ScanActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return PressButton(
      label: label,
      variant: variant,
      icon: Icon(icon, size: AppSizes.iconSm),
      onPressed: onPressed,
    );
  }
}
