/// Token desain NON-WARNA Mei-V2.
///
/// Dipisah dari [AppColors]/[AppTheme] supaya token ukuran/jarak/waktu tidak
/// mencampuri definisi tema. Semua nilai di sini dipakai bersama oleh widget
/// bersama (W1…W16) dan layar agar jarak/radius/durasi konsisten.
///
/// Aturan: seluruh jarak memakai kelipatan 4dp ([AppSpacing]); radius pil
/// brand tetap 50dp ([AppRadius.pill]) dan tidak boleh berubah.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Skala jarak 4dp. Semua padding/margin/gap memakai salah satu nilai ini.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Skala radius sudut. [pill] = 50 dipakai tombol aksi (brand lama).
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 50;
}

/// Durasi animasi standar. [normal] (250 ms) dipakai transisi halaman
/// (I1: rentang 200-300 ms terasa responsif tanpa lambat).
class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Loop garis scan — harus dengan [AppCurves.scanLine] (linear) agar
  /// animasi bolak-balik tidak "menabrak" di ujung.
  static const Duration scanLine = Duration(milliseconds: 1800);

  /// Animasi masuk saat splash/beranda.
  static const Duration splash = Duration(milliseconds: 600);
}

/// Kurva easing standar.
class AppCurves {
  const AppCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.fastOutSlowIn;

  /// Wajib linear agar loop garis scan mulus tanpa hentakan.
  static const Curve scanLine = Curves.linear;
}

/// Ukuran tetap (logo, ikon, target sentuh, kotak scan, breakpoint responsif).
class AppSizes {
  const AppSizes._();

  /// Logo Mei-V pada layar login (AC-01, toleransi ±2px).
  static const double logoLogin = 60;

  /// Logo Telkom Property pada layar login (AC-02).
  static const double logoTelproLogin = 32;

  /// Logo Telkom Property pada footer/kaki halaman (AC-46, header web).
  static const double logoTelproFooter = 24;

  /// Logo pada AppBar halaman dalam.
  static const double logoAppBar = 32;

  static const double avatarRadius = 36;
  static const double avatarRadiusLg = 48;

  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 48;

  /// Target sentuh minimum semua InkWell/IconButton (AC-52).
  static const double touchTarget = 48;

  /// Kotak pandu scan barcode.
  static const double scanBoxWidth = 280;
  static const double scanBoxHeight = 180;
  static const double scanCorner = 24;

  static const double appBarHeight = 56;
  static const double bottomNavHeight = 64;

  /// Breakpoint responsif web (AC-49): <768 sempit, 768-1199 sedang, >=1200 lebar.
  static const int breakpointSm = 768;
  static const int breakpointLg = 1200;
}

/// Bayangan kartu. Warnanya [AppColors.shadowColor] (8% hitam) agar lembut.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}
