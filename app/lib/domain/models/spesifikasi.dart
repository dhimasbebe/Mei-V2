/// Item checklist pemeliharaan per kategori. Padanan tabel `spesifikasi`.
///
/// Inilah sumber **form dinamis**: aplikasi lama punya 6 layar form berbeda
/// (AC, Alarm, APAR, Panel, Hydrant, Petir) yang sebenarnya membaca daftar
/// field dari tabel ini. Di Mei-V2 hanya ada SATU layar form.
class Spesifikasi {
  const Spesifikasi({
    required this.idSpesifikasi,
    required this.idKategori,
    required this.namaSpesifikasi,
    required this.tipeInput,
    this.satuan,
    this.opsiRaw,
    this.urutan = 0,
  });

  final int idSpesifikasi;
  final int idKategori;
  final String namaSpesifikasi;

  /// 'number' | 'text' | 'select'
  final String tipeInput;
  final String? satuan;

  /// Opsi mentah dari API, dipisah tanda `|` (mis. "Baik|Tidak Baik").
  final String? opsiRaw;
  final int urutan;

  bool get isNumber => tipeInput == 'number';
  bool get isSelect => tipeInput == 'select';
  bool get isText => tipeInput == 'text';

  /// Daftar opsi untuk dropdown (kosong bila bukan tipe select).
  List<String> get opsi {
    final String raw = (opsiRaw ?? '').trim();
    if (raw.isEmpty) return const <String>[];
    return raw.split('|').map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
  }

  /// Label dengan satuan, mis. "Voltage R-S (V)".
  String get labelDenganSatuan {
    final String s = (satuan ?? '').trim();
    return s.isEmpty ? namaSpesifikasi : '$namaSpesifikasi ($s)';
  }

  factory Spesifikasi.fromJson(Map<String, dynamic> json) {
    return Spesifikasi(
      idSpesifikasi: int.tryParse('${json['id_spesifikasi'] ?? json['idSpesifikasi'] ?? 0}') ?? 0,
      idKategori: int.tryParse('${json['id_kategori'] ?? json['idKategori'] ?? 0}') ?? 0,
      namaSpesifikasi: (json['nama_spesifikasi'] ?? json['namaSpesifikasi'] ?? '') as String,
      tipeInput: (json['tipe_input'] ?? json['tipeInput'] ?? 'text') as String,
      satuan: json['satuan'] as String?,
      opsiRaw: json['opsi'] as String?,
      urutan: int.tryParse('${json['urutan'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_spesifikasi': idSpesifikasi,
        'id_kategori': idKategori,
        'nama_spesifikasi': namaSpesifikasi,
        'tipe_input': tipeInput,
        'satuan': satuan,
        'opsi': opsiRaw,
        'urutan': urutan,
      };
}
