/// Riwayat kueri pencarian (bounded, tanpa duplikat) — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2
/// & §5.5.
library;

/// Daftar kueri terakhir, terbaru di depan, maksimum [kapasitas] entri.
class SearchHistory {
  SearchHistory({this.kapasitas = 10, List<String>? initial})
      : _items = <String>[] {
    if (initial != null) {
      for (final String q in initial) {
        add(q);
      }
    }
  }

  /// Jumlah maksimum entri yang disimpan.
  final int kapasitas;

  final List<String> _items;

  /// Salinan tak-termutasi dari riwayat (terbaru lebih dulu).
  List<String> get items => List<String>.unmodifiable(_items);

  /// Menambahkan [query] ke depan.
  ///
  /// Kueri kosong (setelah trim) diabaikan. Duplikat dipindah ke depan, bukan
  /// digandakan (AC-H4). Bila melebihi [kapasitas], entri terlama dibuang
  /// (AC-H5).
  void add(String query) {
    final String q = query.trim();
    if (q.isEmpty) return;
    _items.removeWhere((String e) => e == q);
    _items.insert(0, q);
    while (_items.length > kapasitas) {
      _items.removeLast();
    }
  }

  /// Menghapus satu [query] dari riwayat (tidak ada efek bila tak ditemukan).
  void remove(String query) {
    _items.removeWhere((String e) => e == query);
  }

  /// Mengosongkan seluruh riwayat.
  void clear() => _items.clear();

  /// Bentuk serialisasi (daftar string terbaru lebih dulu).
  List<String> serialize() => List<String>.of(_items, growable: false);

  /// Membangun kembali riwayat dari [raw] (urutan dipertahankan: terbaru lebih
  /// dulu). Duplikat dibuang (kemunculan pertama dipertahankan) dan panjang
  /// dibatasi [kapasitas].
  factory SearchHistory.deserialize(List<String> raw, {int kapasitas = 10}) {
    final SearchHistory h = SearchHistory(kapasitas: kapasitas);
    for (final String q in raw) {
      final String t = q.trim();
      if (t.isEmpty) continue;
      if (h._items.contains(t)) continue;
      h._items.add(t);
      if (h._items.length >= kapasitas) break;
    }
    return h;
  }
}
