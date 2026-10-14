import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/settings_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/api/api_exception.dart';
import '../../../domain/models/alat.dart';
import '../../../providers/alat_provider.dart';
import '../../shell/role_shell.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/scan/scan_control_bar.dart';
import '../../widgets/scan/scan_overlay.dart';
import '../../widgets/scan/scan_state_view.dart';

/// Fase layar Scan. Setiap fase pasti punya teks penjelasan + tombol aksi.
enum ScanFase {
  /// Kamera berjalan, menunggu barcode.
  memindai,

  /// Barcode terbaca, sedang divalidasi ke server.
  memvalidasi,

  /// Izin kamera ditolak pengguna.
  izinDitolak,

  /// Perangkat tidak punya kamera / pemindaian tidak didukung.
  kameraTidakAda,

  /// Kamera ada tetapi gagal dijalankan.
  kameraGagal,

  /// Barcode terbaca tetapi tidak terdaftar di server (404).
  tidakTerdaftar,

  /// Jaringan bermasalah saat validasi.
  offline,
}

/// Layar pemindaian barcode alat.
///
/// Menutup SELURUH state pada `docs/PRD-ROLE-UI-V2.md` §5.1. Sebelumnya layar
/// ini hanya menampilkan kotak hitam berisi ikon tanda seru (widget error
/// bawaan `mobile_scanner`) tanpa penjelasan maupun jalan keluar — sekarang
/// setiap kegagalan kamera dirender sebagai panel yang menjelaskan sebabnya
/// dan menyediakan tombol Coba Lagi, Buka Pengaturan, atau Input Manual.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
    ],
    facing: CameraFacing.back,
    autoStart: true,
  );

  ScanFase _fase = ScanFase.memindai;
  String? _barcodeTerakhir;
  double _zoom = 1.0;

  /// True bila sudah ~10 detik tidak ada barcode terbaca (state SC-6).
  bool _lamaTidakAda = false;
  Timer? _timerPetunjuk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_pantauKamera);
    _mulaiTimerPetunjuk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerPetunjuk?.cancel();
    _controller.removeListener(_pantauKamera);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // Kamera tidak boleh hidup saat aplikasi di latar belakang.
    if (state == AppLifecycleState.resumed) {
      if (_fase == ScanFase.memindai) _jalankanKamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  // -------------------------------------------------------------------------
  // Pemantauan kamera
  // -------------------------------------------------------------------------

  /// Menerjemahkan error dari plugin menjadi fase UI yang bisa ditindaklanjuti.
  void _pantauKamera() {
    if (!mounted) return;
    final MobileScannerState kamera = _controller.value;
    final MobileScannerException? error = kamera.error;

    if (error != null) {
      final ScanFase fase = switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied => ScanFase.izinDitolak,
        MobileScannerErrorCode.unsupported => ScanFase.kameraTidakAda,
        _ => ScanFase.kameraGagal,
      };
      if (_fase != fase) setState(() => _fase = fase);
      return;
    }

    // Kamera pulih (mis. setelah izin diberikan di Pengaturan).
    const Set<ScanFase> gagal = <ScanFase>{
      ScanFase.izinDitolak,
      ScanFase.kameraTidakAda,
      ScanFase.kameraGagal,
    };
    if (kamera.isRunning && gagal.contains(_fase)) {
      setState(() => _fase = ScanFase.memindai);
    }
  }

  void _mulaiTimerPetunjuk() {
    _timerPetunjuk?.cancel();
    _timerPetunjuk = Timer(const Duration(seconds: 10), () {
      if (mounted && _fase == ScanFase.memindai) {
        setState(() => _lamaTidakAda = true);
      }
    });
  }

  // -------------------------------------------------------------------------
  // Aksi
  // -------------------------------------------------------------------------

  Future<void> _jalankanKamera() async {
    try {
      await _controller.start();
      if (mounted) {
        setState(() {
          _fase = ScanFase.memindai;
          _lamaTidakAda = false;
        });
        _mulaiTimerPetunjuk();
      }
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = e.errorCode == MobileScannerErrorCode.permissionDenied
            ? ScanFase.izinDitolak
            : ScanFase.kameraGagal;
      });
    } catch (_) {
      if (mounted) setState(() => _fase = ScanFase.kameraGagal);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_fase != ScanFase.memindai) return;
    final String? mentah = capture.barcodes.firstOrNull?.rawValue;
    if (mentah == null || mentah.trim().isEmpty) return;

    // Getar sebagai umpan balik deteksi (I8).
    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    _timerPetunjuk?.cancel();
    setState(() {
      _fase = ScanFase.memvalidasi;
      _barcodeTerakhir = mentah.trim();
    });
    await _controller.stop();
    await _validasi(mentah.trim());
  }

  Future<void> _validasi(String barcode) async {
    try {
      final Alat alat = await ref.read(alatRepositoryProvider).getByBarcode(barcode);
      if (!mounted) return;
      context.goAlat(alat.barcodeAlat);
    } on NotFoundException {
      if (mounted) setState(() => _fase = ScanFase.tidakTerdaftar);
    } on NetworkException {
      if (mounted) setState(() => _fase = ScanFase.offline);
    } catch (_) {
      if (mounted) setState(() => _fase = ScanFase.tidakTerdaftar);
    }
  }

  Future<void> _inputManual() async {
    final TextEditingController ctrl = TextEditingController(
      text: _barcodeTerakhir ?? '',
    );
    final String? hasil = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Input Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ketik kode alat bila barcode sulit terbaca.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: ctrl,
              label: 'Kode Alat',
              hint: 'mis. AC-001',
              autofocus: true,
              onSubmitted: (String v) => Navigator.of(ctx).pop(v.trim()),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('CARI'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (hasil == null || hasil.isEmpty || !mounted) return;
    setState(() {
      _fase = ScanFase.memvalidasi;
      _barcodeTerakhir = hasil;
    });
    await _validasi(hasil);
  }

  Future<void> _bukaPengaturan() async {
    final bool ok = await SettingsChannel.openAppSettings();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak bisa membuka Pengaturan otomatis. Buka manual: '
            'Pengaturan > Aplikasi > Mei-V > Izin > Kamera.',
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool kameraAktif =
        _fase == ScanFase.memindai || _fase == ScanFase.memvalidasi;
    final MobileScannerState kamera = _controller.value;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Pratinjau kamera. errorBuilder sengaja kosong: kegagalan dirender
        // oleh ScanStateView di atasnya, bukan kotak hitam + tanda seru.
        ColoredBox(
          color: AppColors.black,
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              MobileScannerException error,
              Widget? child,
            ) =>
                const SizedBox.expand(),
          ),
        ),

        if (kameraAktif) ...<Widget>[
          Center(child: ScanOverlay(paused: _fase == ScanFase.memvalidasi)),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_lamaTidakAda && _fase == ScanFase.memindai) ...<Widget>[
                  _KartuPetunjuk(onManual: _inputManual),
                  const SizedBox(height: AppSpacing.md),
                ],
                ScanControlBar(
                  torchOn: kamera.torchState == TorchState.on,
                  torchTersedia: kamera.torchState != TorchState.unavailable,
                  onToggleTorch: () => _controller.toggleTorch(),
                  onSwitchCamera: () => _controller.switchCamera(),
                  showSwitchCamera: (kamera.availableCameras ?? 1) > 1,
                  zoom: _zoom,
                  onZoom: (double v) {
                    setState(() => _zoom = v);
                    _controller.setZoomScale(v);
                  },
                  onManual: _inputManual,
                  enabled: _fase == ScanFase.memindai,
                ),
              ],
            ),
          ),
        ],

        if (_fase == ScanFase.memvalidasi) const _LayarMemvalidasi(),

        if (_fase == ScanFase.izinDitolak)
          ColoredBox(
            color: AppColors.surfaceAlt,
            child: ScanStateView(
              icon: Icons.no_photography_outlined,
              title: 'Izin kamera diperlukan',
              message: AppStrings.msgIzinKameraDitolak,
              warna: AppColors.statusWarning,
              actions: <Widget>[
                ScanActionButton(
                  label: 'COBA LAGI',
                  icon: Icons.refresh,
                  onPressed: _jalankanKamera,
                ),
                ScanActionButton(
                  label: 'BUKA PENGATURAN',
                  icon: Icons.settings_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: _bukaPengaturan,
                ),
                ScanActionButton(
                  label: 'INPUT MANUAL',
                  icon: Icons.keyboard_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: _inputManual,
                ),
              ],
            ),
          ),

        if (_fase == ScanFase.kameraTidakAda || _fase == ScanFase.kameraGagal)
          ColoredBox(
            color: AppColors.surfaceAlt,
            child: ScanStateView(
              icon: _fase == ScanFase.kameraTidakAda
                  ? Icons.videocam_off_outlined
                  : Icons.error_outline,
              title: _fase == ScanFase.kameraTidakAda
                  ? 'Kamera tidak tersedia'
                  : 'Kamera gagal dijalankan',
              message: _fase == ScanFase.kameraTidakAda
                  ? AppStrings.msgKameraTidakTersedia
                  : AppStrings.msgKameraGagal,
              warna: AppColors.statusDanger,
              actions: <Widget>[
                if (_fase == ScanFase.kameraGagal)
                  ScanActionButton(
                    label: 'COBA LAGI',
                    icon: Icons.refresh,
                    onPressed: _jalankanKamera,
                  ),
                ScanActionButton(
                  label: 'INPUT MANUAL',
                  icon: Icons.keyboard_outlined,
                  variant: _fase == ScanFase.kameraGagal
                      ? AppButtonVariant.outline
                      : AppButtonVariant.filled,
                  onPressed: _inputManual,
                ),
                ScanActionButton(
                  label: 'KEMBALI',
                  icon: Icons.arrow_back,
                  variant: AppButtonVariant.outline,
                  onPressed: () => context.goHome(),
                ),
              ],
            ),
          ),

        if (_fase == ScanFase.tidakTerdaftar)
          ColoredBox(
            color: AppColors.surfaceAlt,
            child: ScanStateView(
              icon: Icons.search_off,
              title: 'Barcode tidak terdaftar',
              message:
                  '${AppStrings.msgBarcodeTidakTerdaftar}\nKode: ${_barcodeTerakhir ?? '-'}',
              warna: AppColors.statusWarning,
              actions: <Widget>[
                ScanActionButton(
                  label: 'SCAN ULANG',
                  icon: Icons.qr_code_scanner,
                  onPressed: _jalankanKamera,
                ),
                ScanActionButton(
                  label: 'INPUT MANUAL',
                  icon: Icons.keyboard_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: _inputManual,
                ),
              ],
            ),
          ),

        if (_fase == ScanFase.offline)
          ColoredBox(
            color: AppColors.surfaceAlt,
            child: ScanStateView(
              icon: Icons.wifi_off_outlined,
              title: 'Tidak ada koneksi',
              message:
                  '${AppStrings.msgOffline}\nSambungkan kembali lalu coba lagi, '
                  'atau catat kode alat secara manual.',
              warna: AppColors.statusWarning,
              actions: <Widget>[
                ScanActionButton(
                  label: 'COBA LAGI',
                  icon: Icons.refresh,
                  onPressed: () async {
                    if (_barcodeTerakhir == null) {
                      await _jalankanKamera();
                      return;
                    }
                    setState(() => _fase = ScanFase.memvalidasi);
                    await _validasi(_barcodeTerakhir!);
                  },
                ),
                ScanActionButton(
                  label: 'INPUT MANUAL',
                  icon: Icons.keyboard_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: _inputManual,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kartu petunjuk saat barcode lama tidak terdeteksi (state SC-6).
class _KartuPetunjuk extends StatelessWidget {
  const _KartuPetunjuk({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Dekatkan kamera dan pastikan pencahayaan cukup.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onManual,
            child: const Text(
              'Manual',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay saat barcode sedang divalidasi ke server.
class _LayarMemvalidasi extends StatelessWidget {
  const _LayarMemvalidasi();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.overlayScrim,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: AppColors.background),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Memeriksa barcode...',
              style: TextStyle(
                color: AppColors.background,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
