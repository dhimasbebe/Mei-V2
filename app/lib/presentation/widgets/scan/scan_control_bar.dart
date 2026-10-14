import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Panel kendali kamera di bawah kotak pandu (I5, I6).
///
/// Berisi: senter, ganti kamera (hanya bila perangkat punya lebih dari satu),
/// penggeser zoom, dan tombol Input Manual sebagai jalan keluar yang selalu
/// tersedia. Semua tombol memakai target sentuh minimal 48dp (AC-52).
class ScanControlBar extends StatelessWidget {
  const ScanControlBar({
    super.key,
    required this.torchOn,
    required this.torchTersedia,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.showSwitchCamera,
    required this.zoom,
    required this.onZoom,
    required this.onManual,
    this.enabled = true,
  });

  final bool torchOn;
  final bool torchTersedia;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final bool showSwitchCamera;
  final double zoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onManual;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _TombolKendali(
                icon: torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                label: 'Senter',
                aktif: torchOn,
                onPressed: enabled && torchTersedia ? onToggleTorch : null,
              ),
              if (showSwitchCamera)
                _TombolKendali(
                  icon: Icons.cameraswitch_outlined,
                  label: 'Ganti',
                  onPressed: enabled ? onSwitchCamera : null,
                ),
              _TombolKendali(
                icon: Icons.keyboard_outlined,
                label: 'Input Manual',
                onPressed: enabled ? onManual : null,
              ),
            ],
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: zoom.clamp(1.0, 4.0),
                      min: 1,
                      max: 4,
                      onChanged: onZoom,
                    ),
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${zoom.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TombolKendali extends StatelessWidget {
  const _TombolKendali({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.aktif = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final bool nonaktif = onPressed == null;
    final Color warna = nonaktif
        ? Colors.white24
        : (aktif ? AppColors.primary : Colors.white);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minWidth: AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: warna, size: AppSizes.iconMd),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: warna,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
