/// Codec bahasa aplikasi — **Dart murni** (tanpa `package:flutter`).
///
/// Menyembunyikan perbedaan antara nilai yang disimpan (`shared_preferences`)
/// dan nilai yang dipakai UI, sehingga penyedia bahasa (`localeProvider`)
/// cukup menyimpan/membaca satu kode pendek. Dipakai juga oleh
/// `tools/modelcheck` untuk memverifikasi AC-P2/AC-P5.
///
/// Lihat `docs/PRD-FEATURES-V3.md` §P dan `docs/DESIGN-FEATURES-V3.md` §C.3/T10.
library;

/// Bahasa antarmuka yang didukung aplikasi.
///
/// Urutan deklarasi menentukan urutan tampil di pemilih bahasa; Indonesia
/// selalu pertama karena merupakan bawaan (AC-P2).
enum AppLocale { id, en }

/// Normalisasi kode bahasa antara penyimpanan dan UI.
abstract class LocaleCodec {
  const LocaleCodec._();

  /// Kunci `SharedPreferences` untuk preferensi bahasa (AC-P4).
  ///
  /// Nilai ini **tidak boleh berubah**: mengganti nama kunci akan membuat
  /// preferensi pengguna yang sudah tersimpan menjadi yatim (aplikasi kembali
  /// ke Indonesia). Dijaga oleh pemeriksaan di `tools/modelcheck`.
  static const String storageKey = 'meiv.locale.v1';

  /// Bahasa bawaan saat belum ada setelan apa pun (AC-P2).
  static const AppLocale bawaan = AppLocale.id;

  /// Seluruh bahasa yang didukung, Indonesia lebih dulu.
  static const List<AppLocale> didukung = <AppLocale>[AppLocale.id, AppLocale.en];

  /// Kode kanonik yang disimpan di perangkat.
  static const String kodeId = 'id';
  static const String kodeEn = 'en';

  /// Membaca kode tersimpan menjadi [AppLocale].
  ///
  /// Toleran terhadap huruf besar/kecil dan spasi (`'EN '` → [AppLocale.en]),
  /// serta terhadap kode locale lengkap bergaya BCP-47 (`'en-US'`, `'id_ID'`)
  /// yang dipetakan lewat subtag utamanya.
  ///
  /// `null`, string kosong, atau kode tak dikenal → [bawaan]. Fungsi ini
  /// **tidak pernah melempar** agar preferensi rusak tidak membuat aplikasi
  /// gagal dibuka.
  static AppLocale fromKode(String? kode) {
    if (kode == null) return bawaan;
    final String utama = _subtagUtama(kode);
    if (utama == kodeId) return AppLocale.id;
    if (utama == kodeEn) return AppLocale.en;
    return bawaan;
  }

  /// Kode kanonik untuk disimpan (`'id'` / `'en'`).
  static String keKode(AppLocale locale) => switch (locale) {
        AppLocale.id => kodeId,
        AppLocale.en => kodeEn,
      };

  /// Nama bahasa untuk pemilih bahasa — sama di kedua bahasa UI karena
  /// keduanya sudah berupa endonim singkat.
  static String label(AppLocale locale) => switch (locale) {
        AppLocale.id => 'Indonesia',
        AppLocale.en => 'English',
      };

  /// Endonim lengkap: sebutan bahasa menurut penuturnya sendiri.
  static String labelSendiri(AppLocale locale) => switch (locale) {
        AppLocale.id => 'Bahasa Indonesia',
        AppLocale.en => 'English',
      };

  /// Bahasa berikutnya pada siklus `id → en → id`.
  ///
  /// Dengan dua bahasa, fungsi ini adalah invers dirinya sendiri
  /// (`berikutnya(berikutnya(l)) == l`) — dipakai tombol pintas "ganti bahasa".
  static AppLocale berikutnya(AppLocale locale) => switch (locale) {
        AppLocale.id => AppLocale.en,
        AppLocale.en => AppLocale.id,
      };

  /// `true` bila [kode] menunjuk bahasa yang didukung.
  ///
  /// Berbeda dengan [fromKode] yang selalu mengembalikan nilai, fungsi ini
  /// membedakan "tidak ada setelan" dari "setelan valid" — berguna untuk
  /// membedakan `null` (belum pernah memilih) dari hasil fallback.
  static bool didukungKode(String? kode) {
    if (kode == null) return false;
    final String utama = _subtagUtama(kode);
    return utama == kodeId || utama == kodeEn;
  }

  /// Subtag utama dari sebuah kode locale, sudah di-trim dan di-lowercase.
  ///
  /// `' EN-us '` → `'en'`, `'id_ID'` → `'id'`, `''` → `''`.
  static String _subtagUtama(String kode) {
    final String bersih = kode.trim().toLowerCase();
    final int pisah = bersih.indexOf(RegExp(r'[-_]'));
    return pisah < 0 ? bersih : bersih.substring(0, pisah);
  }
}
