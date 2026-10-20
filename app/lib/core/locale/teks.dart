/// Helper pemilihan teks dua bahasa — **Dart murni** (tanpa `package:flutter`).
///
/// Aplikasi ini punya ~40 layar; menerjemahkan seluruhnya berada di luar
/// rilis WS P ini (PRD §P.2). Karena itu kerangka l10n hanya menyediakan
/// pencarian teks bertipe kecil yang bisa diadopsi layar satu per satu:
/// layar yang belum diadopsi tetap berbahasa Indonesia seperti sebelumnya.
///
/// Teks sisi Indonesia tetap **satu sumber** di [AppStrings]; berkas ini hanya
/// menambahkan padanan Inggris untuk string yang benar-benar dipakai layar
/// Login dan pemilih bahasa pada rilis ini.
library;

import '../constants/app_strings.dart';
import 'locale_codec.dart';

/// Pemilih teks berdasarkan bahasa aktif.
///
/// Pemakaian di layar:
/// ```dart
/// final Teks t = Teks(ref.watch(localeProvider));
/// Text(t.hintNip);
/// ```
class Teks {
  const Teks(this.bahasa);

  /// Bahasa antarmuka yang sedang aktif.
  final AppLocale bahasa;

  /// `true` bila UI berbahasa Inggris.
  bool get inggris => bahasa == AppLocale.en;

  /// Pilih teks sesuai bahasa; Indonesia adalah bawaan.
  String pilih(String id, String en) => inggris ? en : id;

  /// Pilih berdasarkan jumlah (mis. "1 alat" / "3 alat").
  ///
  /// Indonesia tidak berinfleksi, jadi [id] dipakai apa adanya. Inggris
  /// memakai [en] sebagai bentuk tunggal dan menurunkan bentuk jamaknya
  /// secara otomatis (akhiran `-s` / `-es` / `-ies`).
  String jumlah(int n, String id, String en) {
    final String kata = inggris ? _jamakInggris(en, n) : id;
    return '$n $kata';
  }

  // --- Layar Login (AC-P3) --------------------------------------------
  // Slogan merek "Maintenance Equipment Information" sudah berbahasa Inggris
  // dan dipakai apa adanya di kedua bahasa, jadi tidak perlu getter.

  /// Label field NIP — akronim resmi, sama di kedua bahasa.
  String get labelNip => AppStrings.labelNip;

  /// Placeholder field NIP.
  String get hintNip => pilih(AppStrings.hintNip, 'Enter your NIP');

  /// Label field password.
  String get labelPassword => pilih(AppStrings.labelPassword, 'Password');

  /// Placeholder field password.
  String get hintPassword =>
      pilih(AppStrings.hintPassword, 'Enter your password');

  /// Label dropdown peran. "Role" adalah kata serapan yang dipakai PRD §6.2,
  /// jadi dipertahankan di kedua bahasa.
  String get labelRole => pilih('Role', 'Role');

  /// Placeholder dropdown peran.
  String get hintPilihRole => pilih(AppStrings.hintPilihRole, 'Select role');

  /// Label tombol utama.
  String get labelMasuk => pilih(AppStrings.labelMasuk, 'SIGN IN');

  /// Validasi NIP kosong.
  String get msgNipKosong =>
      pilih(AppStrings.msgNipKosong, 'NIP is required.');

  /// Validasi panjang password.
  String get msgPasswordMinimal => pilih(
        AppStrings.msgPasswordMinimal,
        'Password must be at least 4 characters.',
      );

  /// Validasi peran belum dipilih.
  String get msgRoleWajib =>
      pilih(AppStrings.msgRoleWajib, 'Please select a role.');

  /// Tooltip tombol mata saat password tersembunyi.
  String get tooltipLihatPassword => pilih('Lihat password', 'Show password');

  /// Tooltip tombol mata saat password terlihat.
  String get tooltipSembunyikanPassword =>
      pilih('Sembunyikan password', 'Hide password');

  /// Nama instansi — nama diri, tidak diterjemahkan.
  String get namaInstansi => AppStrings.telkomPropertySurabayaUtara;

  // --- Pemilih bahasa di Profil (AC-P4/AC-P6) --------------------------

  /// Judul seksi bahasa.
  String get labelBahasa => pilih('Bahasa', 'Language');

  /// Subjudul seksi bahasa.
  String get subjudulBahasa =>
      pilih('Bahasa antarmuka aplikasi', 'App interface language');

  /// Keterangan kejujuran cakupan: hanya Login yang sudah dwibahasa.
  String get catatanBahasa => pilih(
        'Perubahan langsung berlaku. Layar selain Login masih berbahasa '
            'Indonesia pada rilis ini.',
        'Changes apply immediately. Screens other than Login are still in '
            'Indonesian in this release.',
      );

  /// Label baris "bahasa aktif".
  String get bahasaAktif => pilih('Bahasa aktif', 'Active language');

  // --- Pesan galat -----------------------------------------------------

  /// Menerjemahkan pesan galat yang **dikenal** ke bahasa aktif.
  ///
  /// Pesan dari server (Laravel) atau pembungkus `ApiException(401): …`
  /// dibiarkan apa adanya bila tidak dikenali — teks server adalah data, bukan
  /// string UI milik aplikasi. Pesan lokal ([AppStrings.msgRoleTidakCocok])
  /// dan pesan bawaan [ApiException] diterjemahkan agar layar Login tidak
  /// menyisakan teks Indonesia saat bahasa Inggris aktif (AC-P3).
  String pesanGalat(String pesan) {
    if (!inggris) return pesan;
    final String langsung = _galatInggris[pesan.trim()] ?? '';
    if (langsung.isNotEmpty) return langsung;

    // Bentuk `ApiException(422): <pesan>` — terjemahkan ekornya saja agar
    // jenis galat tetap terbaca oleh pengembang.
    final int pisah = pesan.indexOf(': ');
    if (pisah > 0 && pisah < pesan.length - 2) {
      final String ekor = _galatInggris[pesan.substring(pisah + 2).trim()] ?? '';
      if (ekor.isNotEmpty) {
        return '${pesan.substring(0, pisah)}: $ekor';
      }
    }
    return pesan;
  }

  /// Padanan Inggris untuk pesan galat yang berasal dari aplikasi sendiri
  /// (bukan dari server). Kuncinya persis sama dengan teks Indonesia yang
  /// dihasilkan [AppStrings] / `AuthNotifier` / `ApiException`.
  static const Map<String, String> _galatInggris = <String, String>{
    AppStrings.msgLoginGagal: 'Incorrect username or password',
    AppStrings.msgRoleTidakCocok:
        'The selected role does not match this account.',
    'Login gagal.': 'Login failed.',
    'Koneksi internet terputus.': 'Internet connection lost.',
    'Sesi habis. Silakan masuk kembali.': 'Session expired. Please sign in again.',
    'Anda tidak memiliki izin.': 'You do not have permission.',
    'Validasi gagal.': 'Validation failed.',
    'Terjadi kesalahan server.': 'A server error occurred.',
  };

  /// Bentuk jamak Inggris sederhana untuk [jumlah].
  static String _jamakInggris(String kata, int n) {
    if (n == 1) return kata;
    if (kata.endsWith('s') ||
        kata.endsWith('x') ||
        kata.endsWith('ch') ||
        kata.endsWith('sh')) {
      return '${kata}es';
    }
    if (kata.endsWith('y') && kata.length > 1) {
      const String vokal = 'aeiou';
      final String sebelum = kata[kata.length - 2].toLowerCase();
      if (!vokal.contains(sebelum)) {
        return '${kata.substring(0, kata.length - 1)}ies';
      }
    }
    return '${kata}s';
  }
}
