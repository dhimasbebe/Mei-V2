/// Penyimpanan draf form yang **belum dikirim** (AC-A6, AC-A12).
///
/// Bedanya dengan `DraftQueue` (`meiv.draft_queue.v1`) penting dan disengaja:
///
///  * `DraftQueue` = draf yang **harus dikirim**; setiap perubahan memicu
///    `syncNow()` sehingga isinya langsung di-POST ke server.
///  * `FormDraftStore` = isi form yang masih diketik teknisi. Tidak ada
///    jaringan, tidak ada sinkronisasi: hanya pemulihan tampilan saat form
///    dibuka kembali.
///
/// Sebelum pemisahan ini, autosave 600 ms menulis ke `DraftQueue` yang
/// langsung mengirim laporan setengah jadi (dan karena `client_uuid` saat itu
/// dibuat ulang di setiap perubahan, laporan final menjadi laporan KEDUA).
/// Lihat `docs/DESIGN-FEATURES-V3.md` §5.1 dan AC-A6.
///
/// Satu entri per barcode, disimpan sebagai satu string JSON di
/// `shared_preferences` (kunci [storageKey]) dengan bentuk:
///
/// ```json
/// {"version": 1, "items": {"ac-001": { ...DraftRecord... }}}
/// ```
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'draft_queue.dart';

/// Membaca/menulis draf form per barcode.
///
/// Seluruh operasi **tidak pernah melempar**: penyimpanan gagal, JSON rusak,
/// atau data hilang hanya menghasilkan `null`/tanpa efek — sama seperti
/// `PatrolQueue.deserialize` dan `DraftQueue.deserialize`. Form pemeliharaan
/// tidak boleh gagal dibuka gara-gara draf lama yang korup.
class FormDraftStore {
  /// [prefs] dapat diganti pada uji (mis. `SharedPreferences.setMockInitialValues`)
  /// tanpa perlu server maupun plugin asli.
  FormDraftStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Instans yang dipakai layar form.
  static final FormDraftStore instance = FormDraftStore();

  /// Kunci `shared_preferences` — TERPISAH dari antrean kirim
  /// (`meiv.draft_queue.v1`) supaya draf setengah jadi tidak pernah terkirim.
  static const String storageKey = 'meiv.form_draft.v1';

  final Future<SharedPreferences> Function() _prefs;

  /// Kunci peta untuk satu barcode: trim + huruf kecil, agar "ac-001" dan
  /// "AC-001" menunjuk entri yang sama.
  static String kunciUntuk(String barcode) => barcode.trim().toLowerCase();

  /// Draf tersimpan untuk [barcode], atau `null` bila tidak ada / rusak.
  Future<DraftRecord?> baca(String barcode) async {
    final String kunci = kunciUntuk(barcode);
    if (kunci.isEmpty) return null;

    final Map<String, Map<String, dynamic>> peta = await bacaPeta();
    final Map<String, dynamic>? isi = peta[kunci];
    if (isi == null) return null;

    try {
      final DraftRecord draf = DraftRecord.fromJson(isi);
      // Entri tanpa checklist sama sekali tidak berguna untuk dipulihkan.
      if (draf.barcodeAlat.trim().isEmpty) return null;
      return draf;
    } catch (_) {
      return null;
    }
  }

  /// Simpan/ganti draf untuk barcode milik [draf]. Tanpa efek bila gagal.
  Future<void> simpan(DraftRecord draf) async {
    final String kunci = kunciUntuk(draf.barcodeAlat);
    if (kunci.isEmpty) return;

    final Map<String, Map<String, dynamic>> peta = await bacaPeta();
    peta[kunci] = draf.toJson();
    await tulisPeta(peta);
  }

  /// Hapus draf untuk [barcode] (setelah terkirim / dibuang pengguna).
  Future<void> hapus(String barcode) async {
    final String kunci = kunciUntuk(barcode);
    if (kunci.isEmpty) return;

    final Map<String, Map<String, dynamic>> peta = await bacaPeta();
    if (peta.remove(kunci) == null) return;
    await tulisPeta(peta);
  }

  /// Seluruh peta draf tersimpan (`kunci barcode → JSON draf`).
  ///
  /// Publik supaya dapat diperiksa/diuji; pemanggil normal cukup memakai
  /// [baca]/[simpan]/[hapus].
  Future<Map<String, Map<String, dynamic>>> bacaPeta() async {
    try {
      final SharedPreferences prefs = await _prefs();
      return decode(prefs.getString(storageKey));
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  /// Tulis ulang seluruh peta (satu `setString` agar atomik).
  Future<void> tulisPeta(Map<String, Map<String, dynamic>> peta) async {
    try {
      final SharedPreferences prefs = await _prefs();
      await prefs.setString(storageKey, encode(peta));
    } catch (_) {
      // Penyimpanan penuh/terkunci: form tetap berjalan di memori.
    }
  }

  // ---------------------------------------------------------------------
  // Codec (fungsi murni — dipakai juga oleh pemeriksaan di luar Flutter)
  // ---------------------------------------------------------------------

  /// Serialisasi peta draf menjadi satu string JSON.
  static String encode(Map<String, Map<String, dynamic>> items) =>
      jsonEncode(<String, dynamic>{
        'version': 1,
        'items': items,
      });

  /// Kebalikan [encode]; data `null`/kosong/rusak menghasilkan peta kosong.
  static Map<String, Map<String, dynamic>> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    try {
      final Object? data = jsonDecode(raw);
      if (data is Map) {
        final Object? items = data['items'];
        if (items is Map) {
          final Map<String, Map<String, dynamic>> hasil =
              <String, Map<String, dynamic>>{};
          items.forEach((Object? k, Object? v) {
            if (v is Map) hasil['$k'] = Map<String, dynamic>.from(v);
          });
          return hasil;
        }
      }
      // Bentuk lama: peta langsung tanpa pembungkus.
      if (data is Map) {
        final Map<String, Map<String, dynamic>> hasil =
            <String, Map<String, dynamic>>{};
        data.forEach((Object? k, Object? v) {
          if (v is Map) hasil['$k'] = Map<String, dynamic>.from(v);
        });
        return hasil;
      }
    } catch (_) {
      // Abaikan: peta kosong.
    }
    return <String, Map<String, dynamic>>{};
  }
}
