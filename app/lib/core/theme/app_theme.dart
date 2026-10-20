import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_palette_spec.dart';
import 'app_tokens.dart';
import '../motion/app_page_transitions.dart';

/// Tema Mei-V — mengikuti tampilan aplikasi lama:
///  • tombol aksi = pil penuh (radius 50dp) warna brand #CB2400
///  • top bar beranda = hitam, app bar halaman = merah brand
///  • field input = rounded, terisi
///  • tabel = header merah (#CB2400) dengan garis #AFAFAF
///
/// Diperluas (aditif) untuk Mei-V2: skala tipografi lengkap, tema navigasi
/// (bottom bar / rail / drawer), dialog, chip, progress, tooltip, dan transisi
/// halaman. Semua nilai memakai token dari [AppColors]/[AppTokens] — tidak ada
/// literal warna yang tersebar (AC-51, AC-53).
///
/// Tahap 3 (WS E): kedua tema memasang `AppPalette` sebagai ThemeExtension
/// (permukaan/teks dari `PaletteSpec`); [dark] adalah varian gelap baru.
class AppTheme {
  const AppTheme._();

  static const double pillRadius = 50;

  /// Perubahan aditif bersama: extensions + darkTheme.
  ///
  /// Nilai permukaan/teks lama TIDAK berubah — [light] tetap 100% kompatibel
  /// dengan tampilan sebelumnya.
  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    return _dasar(
      scheme: scheme,
      palet: AppPalette.dari(PaletteTheme.light),
      scaffold: AppColors.background,
      appBarBackground: AppColors.black,
      appBarForeground: AppColors.background,
    );
  }

  /// Varian gelap (Tahap 3 — AC-E6). Brand tetap #CB2400; permukaan/teks dari
  /// `PaletteSpec.dark`; top bar tetap hitam sehingga identitas visual bertahan.
  static ThemeData dark() {
    final AppPalette palet = AppPalette.dari(PaletteTheme.dark);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: palet.surface,
      brightness: Brightness.dark,
    );

    return _dasar(
      scheme: scheme,
      palet: palet,
      scaffold: palet.background,
      appBarBackground: AppColors.black,
      appBarForeground: AppColors.background,
      gelap: true,
    );
  }

  /// Kerangka tema bersama light/dark. Nilai permukaan/teks diambil dari
  /// [palet] sehingga dark mode benar-benar berbeda; brand tidak berubah.
  static ThemeData _dasar({
    required ColorScheme scheme,
    required AppPalette palet,
    required Color scaffold,
    required Color appBarBackground,
    required Color appBarForeground,
    bool gelap = false,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkRipple.splashFactory,
      brightness: gelap ? Brightness.dark : Brightness.light,
      extensions: <ThemeExtension<dynamic>>{palet},

      // Top bar hitam (logo Mei-V) — dipakai di Beranda & Profil.
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: appBarForeground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: appBarForeground),
      ),

      // App bar merah (halaman detail / form) — seperti "ALAT", "Panel Listrik".
      // Gunakan AppBar dengan backgroundColor: AppColors.primary secara eksplisit.
      primaryTextTheme: const TextTheme(
        titleLarge: TextStyle(color: AppColors.background),
      ),

      // Tombol utama: pil merah penuh.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.primarySoft,
          minimumSize: const Size.fromHeight(AppSizes.touchTarget),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),

      // Tombol sekunder (CANCEL pada aplikasi lama = merah pucat).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primarySoft,
          side: BorderSide.none,
          minimumSize: const Size.fromHeight(AppSizes.touchTarget),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      // Field input: rounded, terisi, label kecil di atas.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palet.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palet.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        labelStyle: TextStyle(color: palet.textSecondary),
        hintStyle: TextStyle(color: palet.textSecondary),
      ),

      // Kartu permukaan standar: putih/gelap, garis [divider], radius [AppRadius.md].
      cardTheme: CardThemeData(
        color: palet.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palet.divider),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palet.divider,
        thickness: 1,
        space: 1,
      ),

      // Snackbar terpadu (dipakai [AppSnackbar]) — sudut membulat + margin.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: const TextStyle(color: AppColors.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Bottom navigation (Material 3) — dipakai [RoleShell].
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomNavHeight,
        backgroundColor: palet.surface,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : palet.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.iconMd,
            color: selected ? AppColors.primary : palet.textSecondary,
          );
        }),
      ),

      // Bottom navigation (Material 2) — jaring pengaman bila shell memakai
      // BottomNavigationBar agar warna ikon/label tetap konsisten.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palet.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: palet.textSecondary,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: palet.textSecondary),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Sidebar web (rail) — item aktif latar primarySoft, teks primary.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palet.surface,
        indicatorColor: AppColors.primarySoft,
        selectedIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: AppSizes.iconMd,
        ),
        unselectedIconTheme: IconThemeData(
          color: palet.textSecondary,
          size: AppSizes.iconMd,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: palet.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),

      // Sidebar web (drawer) untuk layar sempit.
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: palet.surface,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : palet.textPrimary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : palet.textSecondary,
          );
        }),
      ),

      // Dialog konfirmasi (I9) — radius besar, judul titleMedium.
      dialogTheme: DialogThemeData(
        backgroundColor: palet.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palet.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: palet.textPrimary,
        ),
      ),

      // Chip filter/badge — latar abu, terpilih primarySoft + teks primary.
      chipTheme: ChipThemeData(
        backgroundColor: palet.surfaceMuted,
        selectedColor: AppColors.primarySoft,
        secondarySelectedColor: AppColors.primarySoft,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palet.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),

      // Progres form (AC-33) — warna brand + jalur primarySoft.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: const TextStyle(color: AppColors.background, fontSize: 12),
      ),

      // Transisi halaman kustom, konsisten di Android/iOS/web (Tahap 3 WS F,
      // AC-F7): durasi efektif 200–300 ms dari AppMotion, hormati
      // reduce-motion (MediaQuery.disableAnimations).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: MeiVPageTransitionsBuilder(),
          TargetPlatform.iOS: MeiVPageTransitionsBuilder(),
          TargetPlatform.macOS: MeiVPageTransitionsBuilder(),
          TargetPlatform.windows: MeiVPageTransitionsBuilder(),
          TargetPlatform.linux: MeiVPageTransitionsBuilder(),
          TargetPlatform.fuchsia: MeiVPageTransitionsBuilder(),
        },
      ),

      // Skala tipografi lengkap (11 style).
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: palet.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: palet.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: palet.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: palet.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palet.textSecondary,
        ),
      ),
    );
  }
}

/// Gradien brand & permukaan. Dipakai header/kartu hero dan kartu KPI web.
class AppGradients {
  const AppGradients._();

  /// Gradien brand merah (header login/beranda).
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientBrandStart, AppColors.gradientBrandEnd],
  );

  /// Gradien permukaan lembut (header kartu KPI).
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.surface, AppColors.surfaceAlt],
  );
}
