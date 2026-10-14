import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/maintenance.dart';
import '../../../core/media/photo_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Galeri thumbnail foto lampiran laporan (Tahap 3 — WS C, §7.1).
///
/// Dipakai di layar Verifikasi (AC-C13): menampilkan jumlah foto; menekan
/// thumbnail membuka tampilan penuh sederhana (dialog zoom-pan).
class FotoGallery extends StatelessWidget {
  const FotoGallery({super.key, required this.foto, this.dense = false});

  final List<FotoLampiran> foto;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (foto.isEmpty) return const SizedBox.shrink();

    final double sisi = dense ? 56 : 88;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: List<Widget>.generate(foto.length, (int i) {
        final FotoLampiran f = foto[i];
        return GestureDetector(
          onTap: () => _bukaPenuh(context, f),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: sisi,
              height: sisi,
              color: AppColors.surfaceMuted,
              child: Image.network(
                f.url,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext c, Object e, StackTrace? st) =>
                        const Icon(
                  Icons.broken_image_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _bukaPenuh(BuildContext context, FotoLampiran f) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayScrim,
      builder: (BuildContext ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    f.url,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (BuildContext c, Object e, StackTrace? st) =>
                            const Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Indikator jumlah foto untuk kartu riwayat (AC-C14).
class FotoCountBadge extends StatelessWidget {
  const FotoCountBadge({super.key, required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    if (jumlah <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.photo_outlined,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 2),
        Text(
          '$jumlah',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Thumbnail foto lokal (belum terunggah) — dipakai form offline.
class FotoLokalThumbnail extends StatelessWidget {
  const FotoLokalThumbnail({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.memory(bytes, fit: BoxFit.cover, width: 88, height: 88),
    );
  }
}

/// Membaca foto lokal untuk pratinjau (helper FutureBuilder-friendly).
Future<Uint8List?> bacaFotoLokal(String kunci) => PhotoStore.baca(kunci)
    .then((List<int>? b) => b == null ? null : Uint8List.fromList(b));
