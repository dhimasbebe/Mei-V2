/// Logika checklist cepat "Semua Baik" (WS J, Fitur Tahap 3) — **Dart murni**.
///
/// Modul ini TIDAK boleh mengimpor `package:flutter`; seluruhnya diuji lewat
/// `dart.exe` (`tools/modelcheck`). Lihat `docs/DESIGN-FEATURES-V3.md` §C.1.2
/// dan `docs/PRD-FEATURES-V3.md` §J.
///
/// Seluruh fungsi bersifat MURNI: daftar masukan tidak pernah diubah; hasil
/// baru dikembalikan sebagai daftar terpisah (AC-J1/J2).
library;

/// Nilai satu item checklist yang sedang diisi (peta dari Spesifikasi UI).
///
/// Sengaja struct terpisah agar modul tetap murni dan uji tidak bergantung
/// pada fixture/model domain.
class QuickFillItem {
  const QuickFillItem({
    required this.idSpesifikasi,
    required this.tipeInput,
    this.opsi = const <String>[],
    this.nilai,
  });

  final int idSpesifikasi;

  /// `'select'` | `'text'` | `'number'`.
  final String tipeInput;

  /// Hasil pecah `'|'` — hanya bermakna untuk `select`.
  final List<String> opsi;

  /// Isian pengguna saat ini (`null`/kosong = belum diisi).
  final String? nilai;

  bool get terisi => (nilai ?? '').trim().isNotEmpty;

  /// Item baru dengan [nilai] berbeda (objek lama tidak diubah).
  QuickFillItem copyWith({String? nilai}) => QuickFillItem(
        idSpesifikasi: idSpesifikasi,
        tipeInput: tipeInput,
        opsi: opsi,
        nilai: nilai ?? this.nilai,
      );

  /// Opsi item yang cocok dengan [kandidat] (case-insensitive, trim),
  /// dikembalikan apa adanya (mempertahankan huruf asli opsi).
  String? opsiCocok(Iterable<String> kandidat) {
    final Set<String> target =
        kandidat.map((String s) => s.trim().toLowerCase()).toSet();

    for (final String o in opsi) {
      if (target.contains(o.trim().toLowerCase())) return o;
    }
    return null;
  }
}

/// Aksi "Semua Baik" pada checklist (AC-J1/J2/J3).
abstract class ChecklistQuickFill {
  /// Opsi yang dianggap "normal". Pencocokan case-insensitive, trim.
  static const Set<String> opsiBaik = {'baik', 'ok', 'baik/ok', 'normal'};

  static const String defaultNilai = 'Baik';

  /// Isi item pilihan yang punya opsi "Baik/OK", kembalikan DAFTAR BARU.
  ///
  /// ATURAN (AC-J1/J2) — daftar masukan TIDAK diubah:
  ///  - item bertipe != `select` → TIDAK disentuh (angka/teks tetap kosong);
  ///  - item tanpa opsi ∈ [opsiBaik] → TIDAK disentuh;
  ///  - item yang sudah diisi pengguna → TIDAK ditimpa;
  ///  - sisanya diisi: opsi item yang cocok bila ada (mis. `'OK'` pada opsi
  ///    `['OK','Tidak OK']`), selain itu [defaultNilai]. Memilih opsi yang
  ///    benar-benar ada menghindari nilai di luar daftar opsi.
  static List<QuickFillItem> isiSemua(
    List<QuickFillItem> items, {
    String defaultNilai = defaultNilai,
  }) {
    return items.map((QuickFillItem item) {
      if (item.tipeInput != 'select') return item;
      if (item.terisi) return item;

      final String? cocok = item.opsiCocok(opsiBaik);
      if (cocok == null) return item;

      final String nilai = item.opsiCocok(<String>[defaultNilai]) ?? cocok;
      return item.copyWith(nilai: nilai);
    }).toList(growable: false);
  }

  /// Jumlah item yang BENAR-BENAR akan diisi oleh [isiSemua]
  /// (untuk snackbar AC-J7). Daftar masukan tidak diubah.
  static int markAllOk(
    List<QuickFillItem> items, {
    String defaultNilai = defaultNilai,
  }) {
    final List<QuickFillItem> hasil = isiSemua(items, defaultNilai: defaultNilai);
    int jumlah = 0;

    for (int i = 0; i < items.length; i++) {
      if (!items[i].terisi && hasil[i].terisi) jumlah++;
    }
    return jumlah;
  }

  /// Progres = item yang benar-benar terisi; dijamin <= `items.length`
  /// — AC-J3.
  static int hitungTerisi(List<QuickFillItem> items) =>
      items.where((QuickFillItem i) => i.terisi).length;
}
