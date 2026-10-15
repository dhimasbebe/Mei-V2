import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/foto_lokal.dart';
import '../../../core/media/photo_compressor.dart';
import '../../../core/media/photo_policy.dart';
import '../../../core/media/photo_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// Field pemilih foto lampiran (Tahap 3 — WS C, §7.1).
///
/// Aturan [PhotoPolicy] diberlakukan penuh:
///  - maksimum [PhotoPolicy.maxFotos] (15) foto per laporan;
///  - kuota total [PhotoPolicy.maxTotalBytes] (100 MB) — foto yang membuat
///    total melebihi kuota DITOLAK sebelum disimpan;
///  - ukuran per berkas setelah kompresi diperiksa [PhotoPolicy.acceptSize];
///    hasil jalur cadangan `dart:ui` (PNG) yang melebihi batas ditolak dengan
///    pesan, bukan dikirim diam-diam.
///
/// State daftar foto DIMILIK PARENT (lihat [onChanged]) supaya form dapat
/// memasukkannya ke draf offline.
class FotoPickerField extends StatefulWidget {
  const FotoPickerField({
    super.key,
    required this.fotos,
    required this.onChanged,
    this.enabled = true,
  });

  final List<FotoLokal> fotos;
  final ValueChanged<List<FotoLokal>> onChanged;
  final bool enabled;

  @override
  State<FotoPickerField> createState() => _FotoPickerFieldState();
}

class _FotoPickerFieldState extends State<FotoPickerField> {
  final ImagePicker _pemilih = ImagePicker();
  bool _sedangProses = false;
  String? _pesan;

  int get _totalBytes =>
      widget.fotos.fold<int>(0, (int t, FotoLokal f) => t + f.ukuran);

  Future<void> _pilih(ImageSource sumber) async {
    if (!widget.enabled || _sedangProses) return;

    // Cek jumlah & kuota SEBELUM membuka kamera/galeri.
    if (!PhotoPolicy.canAdd(
      widget.fotos.length,
      totalBytes: _totalBytes,
    )) {
      _beri(PesanFoto.penuh);
      return;
    }

    setState(() => _sedangProses = true);
    try {
      final XFile? berkas = await _pemilih.pickImage(source: sumber);
      if (berkas == null) return;

      final Uint8List asli = await berkas.readAsBytes();
      final HasilKompresi hasil = await const PhotoCompressor().kompres(
        asli,
        namaAsal: berkas.name,
      );

      if (!hasil.diterima) {
        // Kompresi cadangan tetap melebihi batas per berkas — jangan simpan.
        _beri(PesanFoto.terlaluBesar);
        return;
      }

      if (!PhotoPolicy.canAdd(
        widget.fotos.length,
        totalBytes: _totalBytes,
        bytesBaru: hasil.bytes.length,
      )) {
        _beri(PesanFoto.kuotaHabis);
        return;
      }

      final FotoLokal foto = await PhotoStore.simpan(
        bytes: hasil.bytes,
        nama: hasil.namaFile,
        mime: hasil.mime,
      );

      widget.onChanged(<FotoLokal>[...widget.fotos, foto]);
      if (hasil.jalurCadangan) {
        _beri(PesanFoto.cadangan);
      } else {
        _beri(null);
      }
    } catch (e) {
      _beri('Gagal memproses foto: $e');
    } finally {
      if (mounted) setState(() => _sedangProses = false);
    }
  }

  Future<void> _hapus(int indeks) async {
    final FotoLokal foto = widget.fotos[indeks];
    widget.onChanged(
      <FotoLokal>[...widget.fotos]..removeAt(indeks),
    );
    try {
      await PhotoStore.hapus(foto.kunci);
    } catch (_) {
      // Berkas sudah tidak ada: abaikan.
    }
    _beri(null);
  }

  void _beri(String? pesan) {
    if (mounted) setState(() => _pesan = pesan);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Foto Lampiran',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ),
            Text(
              '${widget.fotos.length}/${PhotoPolicy.maxFotos} • '
              '${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)}/'
              '${PhotoPolicy.maxTotalBytes / (1024 * 1024)} MB',
              style: TextStyle(
                fontSize: 11,
                color: pal.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ...List<Widget>.generate(widget.fotos.length, (int i) {
              return _Thumbnail(foto: widget.fotos[i], onHapus: () => _hapus(i));
            }),
            if (widget.enabled &&
                widget.fotos.length < PhotoPolicy.maxFotos) ...<Widget>[
              _TombolAmbil(
                ikon: Icons.photo_camera_outlined,
                label: 'Kamera',
                sedangProses: _sedangProses,
                onTap: () => _pilih(ImageSource.camera),
              ),
              _TombolAmbil(
                ikon: Icons.photo_library_outlined,
                label: 'Galeri',
                sedangProses: _sedangProses,
                onTap: () => _pilih(ImageSource.gallery),
              ),
            ],
          ],
        ),
        if (_pesan != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _pesan!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.statusDanger,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pesan validasi foto — selaras `PhotoPolicy`.
abstract class PesanFoto {
  const PesanFoto._();

  static const String penuh =
      'Maksimum ${PhotoPolicy.maxFotos} foto per laporan.';
  static const String kuotaHabis =
      'Kuota foto laporan penuh (total maksimal '
      '${PhotoPolicy.maxTotalBytes / (1024 * 1024)} MB).';
  static const String terlaluBesar =
      'Foto terlalu besar setelah dikompresi. Coba foto lain.';
  static const String cadangan =
      'Foto disimpan sebagai PNG (kompresi JPEG tidak tersedia).';
}

class _TombolAmbil extends StatelessWidget {
  const _TombolAmbil({
    required this.ikon,
    required this.label,
    required this.sedangProses,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final bool sedangProses;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: sedangProses ? null : onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: pal.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: pal.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            sedangProses
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(ikon, size: 22, color: AppColors.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: pal.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.foto, required this.onHapus});

  final FotoLokal foto;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 88,
            height: 88,
            color: pal.surfaceMuted,
            child: FutureBuilder<List<int>?>(
              future: PhotoStore.baca(foto.kunci),
              builder: (BuildContext context, AsyncSnapshot<List<int>?> snap) {
                final List<int>? bytes = snap.data;
                if (!snap.hasData || bytes == null || bytes.isEmpty) {
                  return Icon(
                    Icons.image_outlined,
                    size: 24,
                    color: pal.textSecondary,
                  );
                }
                return Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onHapus,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.overlayScrim,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
