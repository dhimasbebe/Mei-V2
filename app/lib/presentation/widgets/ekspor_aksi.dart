import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/file_delivery.dart';
import '../../core/files/file_export_spec.dart';
import '../../data/api/api_exception.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/maintenance_provider.dart';
import 'app_snackbar.dart';

/// Aksi ekspor PDF (WS L, Fitur Tahap 3) — dipakai bersama oleh layar dashboard.
///
/// Semua endpoint PDF membalas biner tanpa envelope, jadi alurnya selalu sama:
/// ambil bytes → pastikan isinya benar-benar `%PDF` → serahkan ke sheet
/// bagikan/unduhan. Menaruhnya di satu tempat mencegah pemeriksaan `%PDF`
/// terlewat di salah satu layar (AC-L1), yang akan berujung pada berkas
/// `.pdf` berisi halaman galat HTML.
abstract class EksporAksi {
  const EksporAksi._();

  /// PDF resmi SATU laporan (`GET /maintenance/{id}/pdf`).
  static Future<void> pdfLaporan(
    BuildContext context,
    WidgetRef ref, {
    required int id,
  }) async {
    await _jalankan(
      context,
      pesanSibuk: 'Menyiapkan PDF laporan #$id…',
      nama: FileExportSpec.namaPdfLaporan(id),
      judul: 'Laporan #$id',
      ambil: () => ref.read(maintenanceRepositoryProvider).getPdf(id),
      sukses: 'PDF laporan #$id siap dibagikan.',
    );
  }

  /// PDF ringkasan periode (`GET /dashboard/export/pdf`).
  ///
  /// Rentang diperiksa lebih dulu terhadap batas server (90 hari) supaya
  /// pengguna tidak menunggu permintaan yang pasti ditolak 422 (AC-L3).
  static Future<void> pdfPeriode(
    BuildContext context,
    WidgetRef ref, {
    required DateTime dari,
    required DateTime sampai,
  }) async {
    if (FileExportSpec.rentangTerlaluPanjang(dari, sampai)) {
      AppSnackbar.show(
        context,
        'Rentang maksimal ${FileExportSpec.maxHariPdf} hari. '
        'Pilih rentang yang lebih pendek.',
        type: AppSnackbarType.gagal,
      );
      return;
    }

    await _jalankan(
      context,
      pesanSibuk: 'Menyiapkan PDF ${FileExportSpec.tanggal(dari)}'
          ' – ${FileExportSpec.tanggal(sampai)}…',
      nama: FileExportSpec.namaPdfPeriode(dari, sampai),
      judul: 'Ringkasan pemeliharaan ${FileExportSpec.tanggal(dari)}'
          ' – ${FileExportSpec.tanggal(sampai)}',
      ambil: () => ref
          .read(dashboardRepositoryProvider)
          .exportPdf(dari: dari, sampai: sampai),
      sukses: 'PDF ringkasan periode siap dibagikan.',
    );
  }

  /// Ekspor CSV riwayat periode (melengkapi tombol PDF).
  static Future<void> csvPeriode(
    BuildContext context,
    WidgetRef ref, {
    required DateTime dari,
    required DateTime sampai,
  }) async {
    await _jalankan(
      context,
      pesanSibuk: 'Menyiapkan CSV periode…',
      nama: FileExportSpec.namaCsvPeriode(dari, sampai),
      judul: 'Riwayat pemeliharaan ${FileExportSpec.tanggal(dari)}'
          ' – ${FileExportSpec.tanggal(sampai)}',
      ambil: () => ref
          .read(dashboardRepositoryProvider)
          .exportCsv(dari: dari, sampai: sampai),
      sukses: 'CSV riwayat siap dibagikan.',
      // CSV tidak punya tanda `%PDF`; cukup pastikan isinya bukan halaman galat.
      validasi: FileExportSpec.tampakCsv,
      mime: 'text/csv',
    );
  }

  /// Alur bersama: ambil berkas → validasi isi → serahkan → laporkan.
  static Future<void> _jalankan(
    BuildContext context, {
    required String pesanSibuk,
    required String nama,
    required String judul,
    required Future<List<int>> Function() ambil,
    required String sukses,
    bool Function(List<int>)? validasi,
    String mime = 'application/pdf',
  }) async {
    // Snackbar "sibuk" diganti snackbar hasil; durasinya panjang supaya tidak
    // hilang saat permintaan PDF besar sedang berjalan.
    AppSnackbar.show(
      context,
      pesanSibuk,
      type: AppSnackbarType.info,
      duration: const Duration(seconds: 30),
    );

    try {
      final List<int> bytes = await ambil();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final bool Function(List<int>) periksa = validasi ?? FileExportSpec.tampakPdf;
      if (!periksa(bytes)) {
        AppSnackbar.show(
          context,
          'Berkas tidak valid diterima dari server. Coba lagi beberapa saat.',
          type: AppSnackbarType.gagal,
        );
        return;
      }

      final HasilPenyerahan hasil = await FileDelivery.bagikanBerkas(
        bytes: bytes,
        nama: nama,
        mime: mime,
        judul: judul,
      );

      if (!context.mounted) return;
      if (hasil.berhasil) {
        AppSnackbar.show(
          context,
          '$sukses (${FileExportSpec.ukuranManusia(bytes.length)})',
          type: AppSnackbarType.sukses,
        );
      } else {
        AppSnackbar.show(
          context,
          hasil.pesan ?? 'Gagal menyiapkan berkas.',
          type: AppSnackbarType.gagal,
        );
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppSnackbar.show(context, e.message, type: AppSnackbarType.gagal);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppSnackbar.show(
        context,
        'Gagal menyiapkan berkas: $e',
        type: AppSnackbarType.gagal,
      );
    }
  }
}
