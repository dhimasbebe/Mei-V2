import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'photo_policy.dart';

/// Hasil kompresi satu foto.
class HasilKompresi {
  const HasilKompresi({
    required this.bytes,
    required this.namaFile,
    required this.mime,
    required this.jalurCadangan,
    required this.melebihiBatas,
  });

  final List<int> bytes;

  /// Nama berkas (menentukan ekstensi yang divalidasi server).
  final String namaFile;

  /// `image/jpeg` (jalur utama) atau `image/png` (cadangan `dart:ui`).
  final String mime;

  /// `true` bila hasil berasal dari jalur cadangan `dart:ui` (PNG).
  final bool jalurCadangan;

  /// `true` bila ukuran hasil masih > [PhotoPolicy.maxBytes] — pemanggil
  /// WAJIB memberi tahu pengguna, bukan mengirim berkas besar diam-diam.
  final bool melebihiBatas;

  bool get diterima => !melebihiBatas;
}

/// Kompresi foto: resize sisi terpanjang ≤ [PhotoPolicy.maxSisiPx] lalu encode.
///
/// Jalur utama memakai `flutter_image_compress` (JPEG native, kualitas 80).
/// Bila pemanggilan native gagal, cadangan memakai `dart:ui` yang **hanya**
/// dapat menghasilkan PNG (lihat `docs/DESIGN-FEATURES-V3.md` §5.2 & §13 D1).
class PhotoCompressor {
  const PhotoCompressor();

  /// Kualitas JPEG jalur utama.
  static const int kualitasJpeg = 80;

  /// Mengompres [input] (bytes gambar apa pun yang didukung codec).
  Future<HasilKompresi> kompres(
    List<int> input, {
    String namaAsal = 'foto.jpg',
  }) async {
    final List<int>? jpeg = await _cobaNative(input);
    if (jpeg != null && jpeg.isNotEmpty) {
      return HasilKompresi(
        bytes: jpeg,
        namaFile: '${_dasar(namaAsal)}.jpg',
        mime: 'image/jpeg',
        jalurCadangan: false,
        melebihiBatas: !PhotoPolicy.acceptSize(jpeg.length),
      );
    }

    final List<int> png = await _kompresDartUi(input);
    return HasilKompresi(
      bytes: png,
      namaFile: '${_dasar(namaAsal)}.png',
      mime: 'image/png',
      jalurCadangan: true,
      melebihiBatas: !PhotoPolicy.acceptSize(png.length),
    );
  }

  /// Jalur utama: JPEG native. `null` bila paket gagal/tidak mendukung.
  Future<List<int>?> _cobaNative(List<int> input) async {
    try {
      final List<int>? hasil = await FlutterImageCompress.compressWithList(
        input is Uint8List ? input : Uint8List.fromList(input),
        quality: kualitasJpeg,
        format: CompressFormat.jpeg,
        minWidth: PhotoPolicy.maxSisiPx,
        minHeight: PhotoPolicy.maxSisiPx,
      );
      return hasil;
    } catch (_) {
      return null;
    }
  }

  /// Jalur cadangan: resize + encode PNG lewat `dart:ui`.
  Future<List<int>> _kompresDartUi(List<int> input) async {
    final Uint8List data =
        input is Uint8List ? input : Uint8List.fromList(input);

    final ui.Codec awal = await ui.instantiateImageCodec(data);
    final ui.FrameInfo frameAwal = await awal.getNextFrame();
    final int w0 = frameAwal.image.width;
    final int h0 = frameAwal.image.height;

    final List<int> target = PhotoPolicy.targetDimensi(w0, h0);
    ui.Image gambar = frameAwal.image;

    if (target[0] != w0 || target[1] != h0) {
      final ui.Codec codec = await ui.instantiateImageCodec(
        data,
        targetWidth: target[0],
        targetHeight: target[1],
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      gambar = frame.image;
    }

    final ByteData? bd = await gambar.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return input; // gagal encode -> kembalikan apa adanya
    return bd.buffer.asUint8List();
  }

  static String _dasar(String nama) {
    final String berkas = nama.split(RegExp(r'[/\\]')).last;
    final int titik = berkas.lastIndexOf('.');
    final String dasar = titik > 0 ? berkas.substring(0, titik) : berkas;
    return dasar.isEmpty ? 'foto' : dasar;
  }
}
