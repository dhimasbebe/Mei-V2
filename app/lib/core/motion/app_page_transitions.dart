import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Transisi halaman Mei-V (Tahap 3 — WS F, AC-F7).
///
/// Dipasang lewat `pageTransitionsTheme` sehingga Android, iOS, dan web
/// memakai gerakan yang sama: halaman baru menggeser sedikit dari bawah
/// sambil memudar, halaman lama meredup.
///
/// * Durasi efektif diambil dari modul murni [AppMotion] (200–300 ms) —
///   dihitung sebagai rasio terhadap durasi rute bawaan sehingga tetap
///   konsisten walau `MaterialPageRoute` memakai 300 ms.
/// * Menghormati *reduce motion*: bila pengguna mematikan animasi
///   (`MediaQuery.disableAnimations`), halaman langsung tampil (AC-F7).
class MeiVPageTransitionsBuilder extends PageTransitionsBuilder {
  const MeiVPageTransitionsBuilder({this.pageId = 'default'});

  /// Kunci halaman untuk [AppMotion.transitionMs].
  final String pageId;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_tanpaAnimasi(context)) return child;

    final int ms = AppMotion.transitionMs(pageId);
    final int durasiRute = route.transitionDuration.inMilliseconds;
    final double rasio = durasiRute <= 0
        ? 1.0
        : (ms / durasiRute).clamp(0.05, 1.0);

    final Animation<double> maju = CurvedAnimation(
      parent: animation,
      curve: Interval(0.0, rasio, curve: Curves.easeOutCubic),
    );
    final Animation<double> redup = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: maju,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(maju),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.7).animate(redup),
          child: child,
        ),
      ),
    );
  }

  /// `true` bila animasi harus dilewati (reduce-motion / aksesibilitas).
  static bool _tanpaAnimasi(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
    return MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
  }
}
