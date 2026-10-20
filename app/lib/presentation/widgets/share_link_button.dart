import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/file_delivery.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/api/api_exception.dart';
import '../../domain/models/share_link.dart';
import '../../providers/maintenance_provider.dart';
import 'app_snackbar.dart';
import 'status_badge.dart';

/// Dialog kelola tautan bagikan laporan (WS O, Fitur Tahap 3).
///
/// Backend hanya menyediakan buat / cabut / buka-publik — TIDAK ada endpoint
/// daftar tautan (`docs/DESIGN-FEATURES-V3.md` §C.2.2). Karena itu dialog ini
/// mengelola tautan yang dibuat SELAMA dialog terbuka; setelah ditutup, tautan
/// tetap aktif di server tetapi tidak lagi dapat dicabut dari sini. Batasan ini
/// ditulis apa adanya di UI supaya admin tidak mengira tautan lama hilang.
class ShareLinkDialog extends ConsumerStatefulWidget {
  const ShareLinkDialog({super.key, required this.idMaintenance});

  final int idMaintenance;

  @override
  ConsumerState<ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends ConsumerState<ShareLinkDialog> {
  /// Pilihan masa berlaku (hari); 0 = tanpa kedaluwarsa.
  static const List<(int, String)> _pilihanMasa = <(int, String)>[
    (0, 'Tanpa kedaluwarsa'),
    (1, '1 hari'),
    (7, '7 hari'),
    (30, '30 hari'),
  ];

  int _hari = 0;
  bool _sibuk = false;
  String? _error;
  ShareLink? _tautan;

  Future<void> _buat() async {
    setState(() {
      _sibuk = true;
      _error = null;
    });

    try {
      final DateTime? kedaluwarsa =
          _hari == 0 ? null : DateTime.now().add(Duration(days: _hari));
      final ShareLink tautan = await ref
          .read(maintenanceRepositoryProvider)
          .buatShareLink(widget.idMaintenance, expiresAt: kedaluwarsa);

      if (!mounted) return;
      setState(() {
        _tautan = tautan;
        _sibuk = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sibuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membuat tautan: $e';
        _sibuk = false;
      });
    }
  }

  Future<void> _salin() async {
    final ShareLink? tautan = _tautan;
    if (tautan == null) return;

    await Clipboard.setData(ClipboardData(text: tautan.url));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      'Tautan disalin ke papan klip.',
      type: AppSnackbarType.sukses,
    );
  }

  /// Bagikan lewat sheet OS; bila tidak tersedia (web lama / desktop tanpa
  /// dukungan), salin ke papan klip supaya pengguna tidak buntu (AC-O8/O9).
  Future<void> _bagikan() async {
    final ShareLink? tautan = _tautan;
    if (tautan == null) return;

    final HasilPenyerahan hasil = await FileDelivery.bagikanTeks(
      teks: tautan.url,
      judul: 'Laporan #${widget.idMaintenance}',
    );

    if (!mounted) return;
    if (hasil.berhasil) return;

    await Clipboard.setData(ClipboardData(text: tautan.url));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      'Sheet bagikan tidak tersedia — tautan disalin ke papan klip.',
      type: AppSnackbarType.info,
    );
  }

  Future<void> _cabut() async {
    final ShareLink? tautan = _tautan;
    if (tautan == null) return;

    final bool ya = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Cabut tautan?'),
            content: const Text(
              'Tautan yang dicabut langsung berhenti berfungsi. '
              'Riwayatnya tetap tersimpan di audit log.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('BATAL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('CABUT'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ya || !mounted) return;

    setState(() {
      _sibuk = true;
      _error = null;
    });

    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .cabutShareLink(tautan.token);

      if (!mounted) return;
      setState(() {
        _tautan = null;
        _sibuk = false;
      });
      AppSnackbar.show(
        context,
        'Tautan dicabut.',
        type: AppSnackbarType.sukses,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sibuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mencabut tautan: $e';
        _sibuk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShareLink? tautan = _tautan;

    return AlertDialog(
      title: Text('Bagikan laporan #${widget.idMaintenance}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tautan ini dapat dibuka tanpa login oleh siapa pun yang '
                'memegang URL-nya. Halaman hanya menampilkan ringkasan '
                'laporan — email dan NIP teknisi tidak disertakan.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: context.pal.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (tautan == null) ..._formBaru() else ..._tautanAktif(tautan),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.verifikasiDitolakSoft,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.verifikasiDitolak,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.verifikasiDitolak,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _sibuk ? null : () => Navigator.of(context).pop(),
          child: const Text('TUTUP'),
        ),
        if (tautan == null)
          TextButton(
            onPressed: _sibuk ? null : _buat,
            child: _sibuk
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('BUAT TAUTAN'),
          )
        else ...<Widget>[
          TextButton(
            onPressed: _sibuk ? null : _cabut,
            child: const Text('CABUT'),
          ),
          TextButton(
            onPressed: _sibuk ? null : _salin,
            child: const Text('SALIN'),
          ),
          FilledButton(
            onPressed: _sibuk ? null : _bagikan,
            child: const Text('BAGIKAN'),
          ),
        ],
      ],
    );
  }

  List<Widget> _formBaru() {
    return <Widget>[
      Text(
        'Masa berlaku',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.pal.textPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: _pilihanMasa.map(((int, String) opsi) {
          final bool aktif = _hari == opsi.$1;
          return ChoiceChip(
            label: Text(opsi.$2),
            selected: aktif,
            onSelected: _sibuk ? null : (_) => setState(() => _hari = opsi.$1),
          );
        }).toList(growable: false),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Setiap permintaan membuat token baru; token lama tidak otomatis '
        'tercabut. Gunakan "Cabut" pada tautan yang tidak dipakai lagi.',
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: context.pal.textSecondary,
        ),
      ),
    ];
  }

  List<Widget> _tautanAktif(ShareLink tautan) {
    return <Widget>[
      Row(
        children: <Widget>[
          StatusBadge(
            label: tautan.aktif ? 'Aktif' : 'Tidak aktif',
            color: tautan.aktif
                ? AppColors.verifikasiDisetujui
                : AppColors.statusUnknown,
            softColor: tautan.aktif
                ? AppColors.verifikasiDisetujuiSoft
                : context.pal.surfaceMuted,
            icon: tautan.aktif ? Icons.link : Icons.link_off,
            dense: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tautan.expiresAt == null
                  ? 'Tanpa kedaluwarsa'
                  : 'Kedaluwarsa ${_tanggal(tautan.expiresAt!)}',
              style: TextStyle(
                fontSize: 11,
                color: context.pal.textSecondary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.pal.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: SelectableText(
          tautan.url,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: context.pal.textPrimary,
          ),
        ),
      ),
    ];
  }

  String _tanggal(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(d.day)}/${dua(d.month)}/${d.year} '
        '${dua(d.hour)}:${dua(d.minute)}';
  }
}

/// Tombol pensil-bagikan kecil untuk membuka [ShareLinkDialog].
///
/// Dipakai di baris tabel data pemeliharaan (Supervisor/Admin).
class TombolBagikanLaporan extends StatelessWidget {
  const TombolBagikanLaporan({super.key, required this.idMaintenance});

  final int idMaintenance;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bagikan tautan laporan',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.share_outlined,
        size: AppSizes.iconSm,
        color: context.pal.textSecondary,
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (BuildContext ctx) =>
            ShareLinkDialog(idMaintenance: idMaintenance),
      ),
    );
  }
}
