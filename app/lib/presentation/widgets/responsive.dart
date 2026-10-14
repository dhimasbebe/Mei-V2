import 'package:flutter/widgets.dart';

import '../../core/theme/app_tokens.dart';

/// Helper breakpoint responsif Mei-V (AC-49).
///
/// Ambang mengikuti [AppSizes.breakpointSm] (768) dan [AppSizes.breakpointLg]
/// (1200) supaya seluruh layar memakai batas yang sama:
///  * < 768   → sempit (ponsel): navigasi bawah.
///  * 768-1199 → sedang (tablet / jendela web kecil): sidebar ringkas.
///  * >= 1200 → lebar (web desktop): sidebar penuh + konten multi-kolom.
abstract class Responsive {
  const Responsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) =>
      width(context) < AppSizes.breakpointSm;

  static bool isTablet(BuildContext context) {
    final double w = width(context);
    return w >= AppSizes.breakpointSm && w < AppSizes.breakpointLg;
  }

  static bool isDesktop(BuildContext context) =>
      width(context) >= AppSizes.breakpointLg;

  /// True bila layar cukup lebar untuk sidebar (tablet ke atas).
  static bool useSidebar(BuildContext context) =>
      width(context) >= AppSizes.breakpointSm;

  /// True bila sidebar boleh menampilkan label teks (bukan hanya ikon).
  static bool sidebarExpanded(BuildContext context) =>
      width(context) >= AppSizes.breakpointLg;

  /// Pilih nilai berdasarkan breakpoint. [tablet] jatuh ke [mobile] bila null.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Jumlah kolom grid yang nyaman pada tiap breakpoint.
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}
