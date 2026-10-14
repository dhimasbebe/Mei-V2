/// Rentang periode grafik dashboard — **Dart murni**.
///
/// TIDAK mengimpor `package:flutter`. Lihat `docs/DESIGN-FEATURES-V3.md` §3.2
/// & §5 (WS G).
library;

/// Rentang tanggal `[dari, sampai]` untuk grafik.
///
/// `dari` selalu ≤ `sampai`. `sampai` inklusif; `dari` = `sampai - N hari`.
class ChartRange {
  const ChartRange(this.dari, this.sampai);

  final DateTime dari;
  final DateTime sampai;

  /// Periode yang didukung UI (urutan tampil chip filter).
  static const List<String> periods = <String>['7d', '30d', '90d'];

  /// Periode fallback saat kode tak dikenal (AC-G3).
  static const String periodeDefault = '30d';

  /// Rentang untuk [period] dihitung mundur dari [acuan] (default: hari ini).
  ///
  /// `'7d'` → 7 hari ke belakang, `'30d'` → 30 hari, `'90d'` → 90 hari.
  /// Periode tak dikenal memakai [periodeDefault] (AC-G2).
  static ChartRange forPeriod(String period, {DateTime? acuan}) {
    final DateTime sampai = _tanggalSaja(acuan ?? DateTime.now());
    final int hari = jumlahHari(period);
    final DateTime dari = sampai.subtract(Duration(days: hari));
    return ChartRange(dari, sampai);
  }

  /// Jumlah hari ke belakang untuk [period]; tak dikenal → 30 (AC-G2).
  static int jumlahHari(String period) {
    switch (period.trim().toLowerCase()) {
      case '7d':
        return 7;
      case '90d':
        return 90;
      case '30d':
      default:
        return 30;
    }
  }

  /// Label tampilan untuk [period]: `'30d'` → `"30 Hari"`; tak dikenal →
  /// `"30 Hari"` (AC-G3).
  static String label(String period) => '${jumlahHari(period)} Hari';

  /// Jumlah titik (hari) dalam rentang, inklusif kedua ujung.
  int get jumlahTitik => sampai.difference(dari).inDays + 1;

  /// Tanggal titik ke-[index] (0 = [dari]); `null` bila di luar rentang.
  DateTime? titik(int index) {
    if (index < 0 || index >= jumlahTitik) return null;
    return dari.add(Duration(days: index));
  }

  /// Indeks titik untuk [tanggal]; `null` bila di luar rentang.
  int? indeks(DateTime tanggal) {
    final int delta = _tanggalSaja(tanggal).difference(dari).inDays;
    if (delta < 0 || delta >= jumlahTitik) return null;
    return delta;
  }

  /// Kode periode terdekat berdasarkan jumlah titik (untuk menandai chip aktif).
  String get kodePeriode => '${jumlahTitik - 1}d';

  static DateTime _tanggalSaja(DateTime d) => DateTime(d.year, d.month, d.day);
}
