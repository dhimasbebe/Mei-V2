import 'package:flutter/material.dart';

/// Palet warna Mei-V — DIAMBIL LANGSUNG dari aplikasi lama:
/// `app/src/main/res/values/colors.xml`  →  <color name="red">#cb2400</color>
/// serta `rounded_corner.xml` (radius 50dp, solid @color/red) dan
/// `table_header_cell_bg.xml` (solid #FFCB2400, stroke #AFAFAF, padding 8dp).
///
/// JANGAN mengganti nilai di bawah tanpa persetujuan pemilik produk —
/// ini warna brand aplikasi Mei-V yang sudah dipakai sejak versi awal.
class AppColors {
  const AppColors._();

  /// Warna brand utama Mei-V (merah). Sumber: colors.xml `red` = #cb2400.
  static const Color primary = Color(0xFFCB2400);

  /// Varian gelap untuk status bar / pressed state.
  static const Color primaryDark = Color(0xFF9E1C00);

  /// Varian terang untuk tombol sekunder (CANCEL pada aplikasi lama).
  static const Color primarySoft = Color(0xFFF3D3CB);

  /// Top bar logo "Mei-V" pada aplikasi lama berwarna hitam.
  static const Color black = Color(0xFF000000);

  /// Warna teks utama.
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Warna teks sekunder.
  static const Color textSecondary = Color(0xFF6B6B6B);

  /// Latar halaman.
  static const Color background = Color(0xFFFFFFFF);

  /// Latar kartu/permukaan.
  static const Color surface = Color(0xFFFFFFFF);

  /// Latar abu-abu untuk field input gelap pada aplikasi lama.
  static const Color fieldDark = Color(0xFF2B2B2B);

  /// Garis tabel — dari `table_header_cell_bg.xml` (stroke #AFAFAF).
  static const Color tableBorder = Color(0xFFAFAFAF);

  /// Latar header tabel — sama dengan brand (#FFCB2400).
  static const Color tableHeader = primary;

  static const Color divider = Color(0xFFE0E0E0);

  // ---------------------------------------------------------------------
  // Warna STATUS untuk dashboard monitoring (BUKAN dari aplikasi lama).
  // Konvensi yang dipakai: merah = abnormal/terlambat, hijau = normal.
  // ---------------------------------------------------------------------
  static const Color statusOk = Color(0xFF2E7D32);
  static const Color statusWarning = Color(0xFFEF6C00);
  static const Color statusDanger = primary;
  static const Color statusUnknown = Color(0xFF9E9E9E);

  // ---------------------------------------------------------------------
  // Warna PER PERAN (AC-43, AC-51).
  // Dipilih dari keluarga warna yang TIDAK bersaing dengan merah brand agar
  // chip peran tetap terbaca (kontras AA) namun brand tetap dominan.
  // Varian *Soft dipakai sebagai latar chip/badge (alpha rendah).
  // ---------------------------------------------------------------------

  /// Admin — indigo netral, tidak menyaingi brand merah.
  static const Color roleAdmin = Color(0xFF3730A3);

  /// Supervisor — teal gelap, jelas berbeda dari merah.
  static const Color roleSupervisor = Color(0xFF0E7490);

  /// Teknisi — memakai brand karena teknisi adalah pengguna utama.
  static const Color roleTeknisi = primary;

  /// Latar chip Admin (alpha ~0.12 dari [roleAdmin]).
  static const Color roleAdminSoft = Color(0xFFE8E7FB);

  /// Latar chip Supervisor.
  static const Color roleSupervisorSoft = Color(0xFFE0F2F6);

  /// Latar chip Teknisi (= [primarySoft]).
  static const Color roleTeknisiSoft = primarySoft;

  // ---------------------------------------------------------------------
  // Kondisi pemeliharaan — menggantikan hardcode Colors.green/orange/red
  // yang tersebar di layar detail alat & form (AC-51).
  // ---------------------------------------------------------------------
  static const Color kondisiBaik = statusOk;
  static const Color kondisiKurangBaik = statusWarning;
  static const Color kondisiRusak = statusDanger;
  static const Color kondisiBaikSoft = Color(0xFFE8F5E9);
  static const Color kondisiKurangBaikSoft = Color(0xFFFFF3E0);
  static const Color kondisiRusakSoft = Color(0xFFFBE9E7);

  // ---------------------------------------------------------------------
  // Status verifikasi maintenance (S2) — dipakai layar Verifikasi & badge.
  // ---------------------------------------------------------------------
  static const Color verifikasiMenunggu = statusWarning;
  static const Color verifikasiDisetujui = statusOk;
  static const Color verifikasiDitolak = statusDanger;
  static const Color verifikasiMenungguSoft = Color(0xFFFFF3E0);
  static const Color verifikasiDisetujuiSoft = Color(0xFFE8F5E9);
  static const Color verifikasiDitolakSoft = Color(0xFFFBE9E7);

  // ---------------------------------------------------------------------
  // Overdue / tepat waktu — papan tugas & badge status (AC-29).
  // ---------------------------------------------------------------------
  static const Color overdue = statusDanger;
  static const Color overdueSoft = Color(0xFFFDECEA);
  static const Color tepatWaktu = statusOk;
  static const Color tepatWaktuSoft = Color(0xFFE8F5E9);

  // ---------------------------------------------------------------------
  // Netral & permukaan tambahan.
  // ---------------------------------------------------------------------

  /// Latar dashboard web (sebelumnya hardcode di 3 layar dashboard).
  static const Color surfaceAlt = Color(0xFFF5F6FA);

  /// Latar abu-abu input (= fillColor input pada app_theme).
  static const Color surfaceMuted = Color(0xFFF4F4F4);

  /// Garis pemisah halus (lebih terang dari [divider]).
  static const Color borderSubtle = Color(0xFFEEEEEE);

  /// Overlay dim 54% hitam saat barcode terdeteksi.
  static const Color overlayScrim = Color(0x8A000000);

  /// Warna dasar bayangan (8% hitam) — dipakai [AppShadows].
  static const Color shadowColor = Color(0x14000000);

  // ---------------------------------------------------------------------
  // Stop gradien brand.
  // ---------------------------------------------------------------------
  static const Color gradientBrandStart = primary;
  static const Color gradientBrandEnd = primaryDark;
}
