import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// Animasi centang sukses — dibuat sendiri dengan `AnimatedBuilder` +
/// `CustomPainter`, tanpa paket animasi tambahan (Tahap 3 — WS F, AC-F4).
///
/// Lingkaran tergambar lebih dulu, lalu tanda centang "tumbuh" mengikuti
/// progres animasi. Bila pengguna mematikan animasi, hasil akhir langsung
/// ditampilkan (reduce-motion).
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({
    super.key,
    this.size = 96,
    this.warna = AppColors.statusOk,
    this.durasi = const Duration(milliseconds: 700),
  });

  final double size;
  final Color warna;
  final Duration durasi;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.durasi,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            painter: _CentangPainter(
              progres: _controller.value,
              warna: widget.warna,
              lingkaran: pal.surfaceAlt,
            ),
          );
        },
      ),
    );
  }
}

/// Menggambar lingkaran latar + tanda centang sesuai [progres] (0..1).
class _CentangPainter extends CustomPainter {
  const _CentangPainter({
    required this.progres,
    required this.warna,
    required this.lingkaran,
  });

  final double progres;
  final Color warna;
  final Color lingkaran;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset pusat = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;

    // 1) Lingkaran latar + cincin (30% pertama animasi).
    final double faseLingkaran = (progres / 0.3).clamp(0.0, 1.0);
    canvas.drawCircle(
      pusat,
      radius,
      Paint()..color = lingkaran,
    );
    canvas.drawCircle(
      pusat,
      radius - 1.5,
      Paint()
        ..color = warna.withValues(alpha: 0.35 * faseLingkaran)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 2) Tanda centang (70% sisanya).
    final double faseCentang = ((progres - 0.3) / 0.7).clamp(0.0, 1.0);
    if (faseCentang <= 0) return;

    final Offset a = Offset(size.width * 0.28, size.height * 0.52);
    final Offset b = Offset(size.width * 0.44, size.height * 0.68);
    final Offset c = Offset(size.width * 0.74, size.height * 0.34);

    final Paint pena = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path jalur = Path()..moveTo(a.dx, a.dy);
    if (faseCentang <= 0.5) {
      final double t = faseCentang / 0.5;
      jalur.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    } else {
      final double t = (faseCentang - 0.5) / 0.5;
      jalur.lineTo(b.dx, b.dy);
      jalur.lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
    }
    canvas.drawPath(jalur, pena);
  }

  @override
  bool shouldRepaint(_CentangPainter old) =>
      old.progres != progres || old.warna != warna || old.lingkaran != lingkaran;
}

/// Menampilkan dialog animasi centang lalu menutupnya sendiri (AC-F4).
///
/// Dipanggil SEBELUM snackbar sukses agar pengguna melihat konfirmasi visual.
/// Durasi total dijaga singkat (± 900 ms) dan langsung selesai bila pengguna
/// mematikan animasi.
Future<void> tampilkanAnimasiSukses(
  BuildContext context, {
  String judul = 'Berhasil',
  Duration durasi = const Duration(milliseconds: 900),
}) async {
  final bool tanpaAnimasi =
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  if (tanpaAnimasi) return;

  final NavigatorState nav = Navigator.of(context);

  // Dialog TIDAK di-await: penutupannya dijadwalkan sendiri agar pemanggil
  // tidak menunggu aksi pengguna.
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (BuildContext ctx) {
      final AppPalette pal = ctx.pal;
      return AlertDialog(
        backgroundColor: pal.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SuccessCheck(),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
          ],
        ),
      );
    },
  ));

  await Future<void>.delayed(durasi);
  if (nav.canPop()) nav.pop();
}
