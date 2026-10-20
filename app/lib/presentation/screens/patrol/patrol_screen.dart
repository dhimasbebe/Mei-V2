import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/patrol/patrol_queue.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/api/api_exception.dart';
import '../../../domain/models/alat.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../providers/patrol_provider.dart';
import '../../shell/role_shell.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/status_badge.dart';

/// Layar Patroli — scan berkelanjutan (WS I, Fitur Tahap 3).
///
/// Berbeda dari layar Scan (satu barcode → langsung buka detail), layar ini
/// membiarkan kamera tetap hidup dan menumpuk hasil scan ke antrean
/// [PatrolQueue]. Teknisi memindai seluruh alat di satu ruangan lebih dulu,
/// lalu mengerjakan laporannya satu per satu dari daftar.
///
/// Antrean disimpan di `shared_preferences` (kunci
/// [PatrolQueue.storageKey]) sehingga tidak hilang saat aplikasi ditutup —
/// AC-I3. Barcode yang tidak terdaftar TETAP masuk antrean dengan status
/// belum tervalidasi (AC-I4); validasi penuh terjadi saat laporan dikirim.
class PatrolScreen extends ConsumerStatefulWidget {
  const PatrolScreen({super.key});

  @override
  ConsumerState<PatrolScreen> createState() => _PatrolScreenState();
}

class _PatrolScreenState extends ConsumerState<PatrolScreen>
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

  /// Barcode yang sedang diproses (membuka form) — menonaktifkan tap ganda.
  String? _memproses;

  /// Penjaga agar satu barcode tidak terbaca berulang dalam waktu singkat.
  String? _terakhirBarcode;
  DateTime? _terakhirDeteksi;

  bool _kameraGagal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_pantauKamera);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_pantauKamera);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (!_kameraGagal) unawaited(_controller.start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.stop());
    }
  }

  void _pantauKamera() {
    if (!mounted) return;
    final bool gagal = _controller.value.error != null;
    if (gagal != _kameraGagal) setState(() => _kameraGagal = gagal);
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  Future<void> _onDetect(BarcodeCapture capture) async {
    final String? mentah = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (mentah == null || mentah.isEmpty) return;

    final DateTime sekarang = DateTime.now();
    final bool terlaluCepat = _terakhirBarcode == mentah &&
        _terakhirDeteksi != null &&
        sekarang.difference(_terakhirDeteksi!) < const Duration(seconds: 2);
    if (terlaluCepat) return;

    _terakhirBarcode = mentah;
    _terakhirDeteksi = sekarang;

    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    final bool baru = await ref.read(patrolQueueProvider.notifier).tambah(mentah);
    if (!mounted) return;

    _pesan(baru ? 'Ditambahkan: $mentah' : '$mentah sudah ada di antrean');
    if (baru) unawaited(_validasi(mentah));
  }

  /// Validasi diam-diam: sukses → status tervalidasi, gagal → tetap
  /// belum tervalidasi (item TIDAK dihapus — AC-I4).
  Future<void> _validasi(String barcode) async {
    try {
      await ref.read(alatRepositoryProvider).getByBarcode(barcode);
      await ref.read(patrolQueueProvider.notifier).tandaiTervalidasi(barcode);
    } catch (_) {
      // Biarkan berstatus belum tervalidasi; dicoba lagi saat dibuka.
    }
  }

  Future<void> _bukaItem(PatrolItem item) async {
    if (_memproses != null) return;
    setState(() => _memproses = item.barcode);

    try {
      final Alat alat =
          await ref.read(alatRepositoryProvider).getByBarcode(item.barcode);
      if (!mounted) return;

      await ref
          .read(patrolQueueProvider.notifier)
          .tandaiTervalidasi(item.barcode);
      ref.read(alatDetailProvider.notifier).state = alat;
      ref.read(maintenanceFormProvider.notifier).init(
            barcodeAlat: alat.barcodeAlat,
            idLokasi: alat.idLokasi ?? 0,
          );
      if (mounted) context.goMaintenanceForm();
    } on NotFoundException {
      await ref
          .read(patrolQueueProvider.notifier)
          .tandaiBelumValidasi(item.barcode);
      if (mounted) _pesan('Barcode ${item.barcode} tidak terdaftar.');
    } on NetworkException {
      if (mounted) {
        _pesan('Tidak ada koneksi. Coba lagi saat online.');
      }
    } catch (_) {
      if (mounted) _pesan('Gagal membuka ${item.barcode}. Coba lagi.');
    } finally {
      if (mounted) setState(() => _memproses = null);
    }
  }

  Future<void> _inputManual() async {
    final TextEditingController ctrl = TextEditingController();
    final String? hasil = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Tambah ke Antrean'),
        content: AppTextField(
          controller: ctrl,
          label: 'Kode Alat',
          hint: 'mis. AC-001',
          autofocus: true,
          onSubmitted: (String v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('TAMBAH'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (hasil == null || hasil.isEmpty || !mounted) return;
    final bool baru = await ref.read(patrolQueueProvider.notifier).tambah(hasil);
    if (!mounted) return;
    _pesan(baru ? 'Ditambahkan: $hasil' : '$hasil sudah ada di antrean');
    if (baru) unawaited(_validasi(hasil));
  }

  Future<void> _kosongkan() async {
    final bool? ya = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Kosongkan antrean?'),
        content: const Text(
          'Seluruh barcode di antrean patroli akan dihapus. Laporan yang sudah '
          'dibuat tidak terpengaruh.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('KOSONGKAN'),
          ),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    await ref.read(patrolQueueProvider.notifier).kosongkan();
    if (mounted) _pesan('Antrean patroli dikosongkan.');
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(teks),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final PatrolQueue antrean = ref.watch(patrolQueueProvider);

    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
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
              if (_kameraGagal)
                ColoredBox(
                  color: context.pal.surfaceAlt,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.no_photography_outlined,
                              size: 40, color: AppColors.statusWarning),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Kamera tidak dapat dijalankan. Gunakan input '
                            'manual untuk tetap menambah barcode.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Bingkai pemandu + penghitung antrean.
              Positioned(
                left: AppSpacing.lg,
                top: AppSpacing.lg,
                child: _Chip(
                  icon: Icons.playlist_add_check,
                  label: '${antrean.count} di antrean',
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.lg,
                child: Center(
                  child: _Chip(
                    icon: Icons.qr_code_scanner,
                    label: 'Arahkan kamera ke barcode alat',
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: context.pal.surface,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Antrean Patroli',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.pal.textPrimary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _inputManual,
                        icon: const Icon(Icons.keyboard_outlined, size: 18),
                        label: const Text('Manual'),
                      ),
                      if (antrean.count > 0)
                        TextButton.icon(
                          onPressed: _kosongkan,
                          icon: const Icon(Icons.delete_sweep_outlined,
                              size: 18),
                          label: const Text('Kosongkan'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: antrean.kosong
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Belum ada barcode. Pindai alat satu per satu — '
                              'setiap hasil masuk ke antrean ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.pal.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          itemCount: antrean.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int i) {
                            final PatrolItem item = antrean.items[i];
                            return _BarisAntrean(
                              item: item,
                              memproses: _memproses == item.barcode,
                              onTap: () => _bukaItem(item),
                              onHapus: () => ref
                                  .read(patrolQueueProvider.notifier)
                                  .hapus(item.barcode),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu baris antrean patroli.
class _BarisAntrean extends StatelessWidget {
  const _BarisAntrean({
    required this.item,
    required this.memproses,
    required this.onTap,
    required this.onHapus,
  });

  final PatrolItem item;
  final bool memproses;
  final VoidCallback onTap;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final bool valid = item.status == PatrolStatus.tervalidasi;

    return Material(
      color: context.pal.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: memproses ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                valid ? Icons.check_circle_outline : Icons.help_outline,
                size: 20,
                color: valid ? AppColors.statusOk : AppColors.statusWarning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.barcode,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valid ? 'Terdaftar' : 'Belum tervalidasi',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (memproses)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...<Widget>[
                StatusBadge(
                  label: 'ISI',
                  color: AppColors.primary,
                  softColor: AppColors.primarySoft,
                  icon: Icons.edit_document,
                  dense: true,
                ),
                IconButton(
                  tooltip: 'Hapus dari antrean',
                  onPressed: onHapus,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip informasi di atas pratinjau kamera.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.background),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}
