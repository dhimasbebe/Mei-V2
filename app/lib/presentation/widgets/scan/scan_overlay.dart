import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Kotak pandu scan dengan garis pemindai beranimasi (I7).
///
/// Menggantikan kotak border polos: sudut tebal bergaya bidik + garis merah
/// yang bergerak naik-turun. Saat [paused] (mis. sedang memvalidasi barcode)
/// animasi berhenti dan bingkai berubah warna agar pengguna tahu prosesnya
/// sedang berjalan.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({super.key, this.paused = false});

  final bool paused;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.scanLine,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && _controller.isAnimating) {
      _controller.stop();
    } else if (!widget.paused && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double lebar = AppSizes.scanBoxWidth;
    const double tinggi = AppSizes.scanBoxHeight;
    final Color warna = widget.paused ? AppColors.statusWarning : AppColors.primary;

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Stack(
        children: <Widget>[
          // Bingkai sudut.
          Positioned.fill(
            child: CustomPaint(painter: _SudutPainter(warna: warna)),
          ),
          // Garis pemindai.
          if (!widget.paused)
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return Positioned(
                  top: _controller.value * (tinggi - 4),
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          warna.withValues(alpha: 0.0),
                          warna,
                          warna.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: warna.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Empat sudut bidik bergaya kamera.
class _SudutPainter extends CustomPainter {
  const _SudutPainter({required this.warna});

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = warna
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double s = AppSizes.scanCorner;
    final double w = size.width;
    final double h = size.height;

    // Kiri atas
    canvas.drawPath(
      Path()
        ..moveTo(0, s)
        ..lineTo(0, 0)
        ..lineTo(s, 0),
      p,
    );
    // Kanan atas
    canvas.drawPath(
      Path()
        ..moveTo(w - s, 0)
        ..lineTo(w, 0)
        ..lineTo(w, s),
      p,
    );
    // Kanan bawah
    canvas.drawPath(
      Path()
        ..moveTo(w, h - s)
        ..lineTo(w, h)
        ..lineTo(w - s, h),
      p,
    );
    // Kiri bawah
    canvas.drawPath(
      Path()
        ..moveTo(s, h)
        ..lineTo(0, h)
        ..lineTo(0, h - s),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SudutPainter oldDelegate) =>
      oldDelegate.warna != warna;
}
