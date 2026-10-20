import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import 'app_button.dart';

/// W8 — Tombol dengan animasi skala tekan + haptic ringan (I2, I8).
///
/// Skala turun ke 0.97 selama 120 ms saat ditekan, disertai
/// [HapticFeedback.selectionClick]. [variant] memakai [AppButtonVariant] yang
/// sama dengan [AppButton] agar konsisten. [expand] mengatur lebar penuh.
class PressButton extends StatefulWidget {
  const PressButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _handleTap() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.variant == AppButtonVariant.filled;
    final bool dark = widget.variant == AppButtonVariant.dark;
    final Color fg = filled || dark ? AppColors.background : AppColors.primary;

    // `outline` transparan agar permukaan halaman yang tampil (bukan slab
    // putih di mode gelap); `dark` tetap hitam — chrome yang memang tidak
    // mengikuti tema.
    final Color bg = filled
        ? AppColors.primary
        : (dark ? AppColors.black : Colors.transparent);

    // Nonaktif mengikuti aturan latar yang sama, teks redup namun terbaca.
    final Color bgDisabled = filled
        ? AppColors.primary.withValues(alpha: 0.5)
        : (dark
            ? AppColors.black.withValues(alpha: 0.6)
            : Colors.transparent);
    final Color fgDisabled =
        filled || dark ? AppColors.background : context.pal.textSecondary;

    // Ripple tetap terbaca di atas latar transparan: overlay brand tipis
    // (bukan mengandalkan fill opaque seperti sebelumnya).
    final Color? overlay = filled || dark
        ? null
        : AppColors.primary.withValues(alpha: 0.08);

    final BorderSide side = widget.variant == AppButtonVariant.outline
        ? const BorderSide(color: AppColors.primary, width: 1.5)
        : BorderSide.none;

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: AppCurves.standard,
        child: ElevatedButton(
          onPressed: _enabled ? _handleTap : null,
          style: ElevatedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: bg,
            disabledBackgroundColor: bgDisabled,
            disabledForegroundColor: fgDisabled,
            overlayColor: overlay,
            minimumSize: Size(
              widget.expand ? double.infinity : 0.0,
              AppSizes.touchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: const StadiumBorder(),
            side: side,
            elevation: filled ? 2 : 0,
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (widget.icon != null) ...<Widget>[
                      widget.icon!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        // Warna eksplisit menimpa disabledForegroundColor,
                        // jadi status nonaktif diterapkan di sini juga.
                        color: _enabled ? fg : fgDisabled,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
