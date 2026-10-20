import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/api/api_exception.dart';
import '../../../domain/models/alat_import.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';

/// Contoh CSV yang disalin ke papan klip lewat "Unduh contoh CSV".
///
/// Kolom mengikuti kontrak backend WS M (`barcode_alat, merk_alat,
/// nama_kategori, nama_lokasi`) — urutan kolom tetap, baris pertama header.
const String _contohCsv = 'barcode_alat,merk_alat,nama_kategori,nama_lokasi\n'
    'AC-001,Panasonic 1PK,Ruang Server,Lantai 3';

/// Nama berkas bawaan saat pengguna hanya menempel teks (tanpa berkas).
const String _namaBerkasBawaan = 'alat.csv';

/// Aksi yang sedang gagal — dipakai tombol "COBA LAGI" agar mengulang
/// permintaan yang tepat (pratinjau vs impor).
enum _AksiGalat { pratinjau, impor }

/// Sumber CSV yang sudah dipakai untuk satu permintaan.
///
/// Disimpan setelah pratinjau supaya tahap impor memakai **input yang sama**
/// persis dengan yang sudah divalidasi pengguna (tidak pernah mencampur teks
/// baru dengan hasil pratinjau lama).
@immutable
class _SumberImpor {
  const _SumberImpor({
    this.csv,
    this.fileBytes,
    this.namaFile = _namaBerkasBawaan,
  });

  /// Isi CSV sebagai teks tempelan (jalur ponsel).
  final String? csv;

  /// Isi berkas CSV (jalur web) — diutamakan backend bila terisi.
  final List<int>? fileBytes;

  /// Nama berkas asal (dipakai pesan galat backend).
  final String namaFile;

  /// Tidak ada teks dan tidak ada berkas.
  bool get kosong => fileBytes == null && (csv ?? '').trim().isEmpty;

  /// Ringkasan sumber untuk dialog konfirmasi.
  String get keterangan =>
      fileBytes == null ? 'teks yang ditempel' : 'berkas $namaFile';
}

/// Impor massal alat dari CSV (Admin) — Fitur Tahap 3 WS M.
///
/// Dua tahap yang sengaja TIDAK digabung:
///  1. **Pratinjau** — memvalidasi tiap baris tanpa menulis database (AC-M1).
///  2. **Impor** — menulis hanya baris valid, setelah konfirmasi (AC-M2/M3).
///
/// Layar ini hidup DI DALAM shell navigasi, jadi ia mengembalikan [Column]
/// (bukan `Scaffold`/`AppBar`) persis seperti `AlatManagementScreen`.
class AlatImportScreen extends ConsumerStatefulWidget {
  const AlatImportScreen({super.key});

  @override
  ConsumerState<AlatImportScreen> createState() => _AlatImportScreenState();
}

class _AlatImportScreenState extends ConsumerState<AlatImportScreen> {
  final TextEditingController _csv = TextEditingController();

  /// Isi berkas CSV yang dipilih lewat `file_picker` (null = pakai teks).
  List<int>? _fileBytes;

  /// Nama berkas terpilih (untuk pesan & multipart).
  String _namaFile = _namaBerkasBawaan;

  /// Hasil pratinjau terakhir (belum ditulis ke database).
  AlatImportResult? _hasilPratinjau;

  /// Hasil impor yang sudah benar-benar tersimpan.
  AlatImportResult? _hasilImpor;

  /// Sumber yang sudah divalidasi — dasar tahap impor.
  _SumberImpor? _sumberTervalidasi;

  /// Pesan galat terakhir (sudah diterjemahkan dari [ApiException]).
  String? _galat;

  /// Permintaan yang harus diulang tombol "COBA LAGI".
  _AksiGalat? _aksiGalat;

  bool _memuat = false;
  bool _mengimpor = false;

  /// Ada permintaan berjalan — tombol dinonaktifkan agar tap ganda diabaikan.
  bool get _sibuk => _memuat || _mengimpor;

  /// Sudah ada bahan untuk dipratinjau (teks tempelan atau berkas).
  bool get _adaInput => _fileBytes != null || _csv.text.trim().isNotEmpty;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;

    return Column(
      children: <Widget>[
        _kepala(pal),
        if (_sibuk)
          LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.primary,
            backgroundColor: pal.surfaceMuted,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: <Widget>[
              _kartuMasukan(pal),
              const SizedBox(height: AppSpacing.md),
              _tombolPratinjau(),
              if (_galat != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _kartuGalat(pal),
              ],
              if (_hasilImpor != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _kartuImporSelesai(pal, _hasilImpor!),
              ],
              if (_hasilPratinjau != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _kartuPratinjau(pal, _hasilPratinjau!),
              ],
              const SizedBox(height: AppSpacing.lg),
              _catatan(pal),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Kepala halaman (dengan tombol kembali ke Manajemen Alat)
  // ---------------------------------------------------------------------------

  Widget _kepala(AppPalette pal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Kembali ke Manajemen Alat',
            onPressed: _sibuk ? null : () => context.go(Routes.dataAlat),
            icon: Icon(Icons.arrow_back, color: pal.textPrimary),
          ),
          Expanded(
            child: SectionHeader(
              title: 'Impor alat dari CSV',
              subtitle: 'Validasi dulu, baru simpan ke database',
              icon: Icons.upload_file_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Langkah 1 — masukan CSV (tempel teks atau pilih berkas)
  // ---------------------------------------------------------------------------

  Widget _kartuMasukan(AppPalette pal) {
    final String? namaBerkas = _fileBytes == null ? null : _namaFile;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '1. Siapkan CSV',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Baris pertama wajib header: '
            'barcode_alat,merk_alat,nama_kategori,nama_lokasi',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _kolomCsv(pal),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sibuk ? null : _pilihBerkas,
              icon: const Icon(Icons.folder_open_outlined, size: AppSizes.iconSm),
              label: const Text('PILIH BERKAS CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
          ),
          if (namaBerkas != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _chipBerkas(pal, namaBerkas),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _sibuk ? null : _salinContoh,
              icon: const Icon(
                Icons.copy_all_outlined,
                size: AppSizes.iconSm,
                color: AppColors.primary,
              ),
              label: const Text('Unduh contoh CSV'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kolom tempel multiline.
  ///
  /// Tidak memakai [AppTextField] karena widget itu tidak menerima `maxLines`
  /// (selalu satu baris), sedangkan jalur ponsel butuh area tempel besar.
  /// Dekorasi di bawah disamakan persis dengan `AppTextField` supaya tampilan
  /// tetap konsisten, dan seluruh warnanya dari [AppPalette].
  Widget _kolomCsv(AppPalette pal) {
    final OutlineInputBorder garis = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: pal.divider),
    );

    return TextField(
      controller: _csv,
      enabled: !_sibuk,
      minLines: 4,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: _saatTeksBerubah,
      style: TextStyle(fontSize: 13, height: 1.4, color: pal.textPrimary),
      decoration: InputDecoration(
        hintText: 'barcode_alat,merk_alat,nama_kategori,nama_lokasi\n'
            'AC-001,Panasonic 1PK,Ruang Server,Lantai 3',
        hintStyle: TextStyle(fontSize: 12, height: 1.5, color: pal.textSecondary),
        filled: true,
        fillColor: pal.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: garis,
        enabledBorder: garis,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: pal.borderSubtle),
        ),
      ),
    );
  }

  Widget _chipBerkas(AppPalette pal, String nama) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: pal.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.description_outlined,
            size: AppSizes.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: pal.textPrimary),
            ),
          ),
          IconButton(
            tooltip: 'Batalkan berkas',
            onPressed: _sibuk ? null : _hapusBerkas,
            icon: Icon(Icons.close, size: AppSizes.iconSm, color: pal.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tombolPratinjau() {
    final bool bisa = _adaInput && !_sibuk;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: bisa ? _pratinjau : null,
        icon: const Icon(Icons.fact_check_outlined, size: AppSizes.iconSm),
        label: Text(_memuat ? 'MEMPRATINJAU' : 'PRATINJAU'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.touchTarget),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kartu galat
  // ---------------------------------------------------------------------------

  Widget _kartuGalat(AppPalette pal) {
    return AppCard(
      borderColor: AppColors.statusDanger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: AppSizes.iconSm,
                color: AppColors.statusDanger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Gagal memproses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _galat ?? '',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: pal.textSecondary,
            ),
          ),
          if (_aksiGalat != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _sibuk ? null : _ulangi,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, AppSizes.touchTarget),
                ),
                child: const Text('COBA LAGI'),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Langkah 2 — hasil pratinjau
  // ---------------------------------------------------------------------------

  Widget _kartuPratinjau(AppPalette pal, AlatImportResult hasil) {
    final bool adaValid = !hasil.tidakAdaBarisValid;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '2. Hasil pratinjau',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _barisStatistik(pal, hasil),
          const SizedBox(height: AppSpacing.md),
          if (hasil.error.isEmpty)
            _kotakInfo(
              pal,
              Icons.check_circle_outline,
              AppColors.statusOk,
              'Semua baris valid dan siap diimpor.',
            )
          else ...<Widget>[
            Text(
              'Baris bermasalah (${hasil.jumlahGagal})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Nomor baris mengikuti baris fisik berkas; baris 1 adalah header.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _daftarGalat(pal, hasil.error),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!adaValid)
            _kotakInfo(
              pal,
              Icons.info_outline,
              AppColors.statusWarning,
              'Tidak ada baris valid, jadi impor tidak dapat dijalankan. '
                  'Perbaiki CSV lalu pratinjau ulang.',
            )
          else ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sibuk ? null : _impor,
                icon: const Icon(Icons.save_alt, size: AppSizes.iconSm),
                label: Text(hasil.labelTombolImpor.toUpperCase()),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hanya baris valid yang disimpan; baris gagal dilewati.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: pal.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Daftar galat per baris di dalam kotak bergulir tersendiri.
  Widget _daftarGalat(AppPalette pal, List<AlatImportError> error) {
    final double tinggi = (error.length * 52.0).clamp(52.0, 240.0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: pal.borderSubtle),
      ),
      child: SizedBox(
        height: tinggi,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          itemCount: error.length,
          separatorBuilder: (BuildContext ctx, int i) =>
              Divider(height: 1, color: pal.divider),
          itemBuilder: (BuildContext ctx, int i) {
            final AlatImportError e = error[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.error_outline,
                      size: 14,
                      color: AppColors.statusDanger,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Baris ${e.baris}: ${e.pesan}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hasil impor
  // ---------------------------------------------------------------------------

  Widget _kartuImporSelesai(AppPalette pal, AlatImportResult hasil) {
    final bool adaGagal = hasil.jumlahGagal > 0;

    return AppCard(
      borderColor: AppColors.verifikasiDisetujui,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: AppSizes.iconMd,
                color: AppColors.verifikasiDisetujui,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Impor selesai',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _barisStatistik(pal, hasil),
          const SizedBox(height: AppSpacing.md),
          if (adaGagal) ...<Widget>[
            _kotakInfo(
              pal,
              Icons.info_outline,
              AppColors.statusWarning,
              '${hasil.jumlahGagal} baris dilewati karena tidak valid. '
                  'Perbaiki lalu impor ulang bila perlu.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(Routes.dataAlat),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
              child: const Text('SELESAI'),
            ),
          ),
        ],
      ),
    );
  }

  /// Tiga angka ringkas: total, valid, gagal.
  Widget _barisStatistik(AppPalette pal, AlatImportResult hasil) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Statistik(
            nilai: '${hasil.total}',
            label: 'Total baris',
            ikon: Icons.list_alt,
            warna: pal.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Statistik(
            nilai: '${hasil.jumlahValid}',
            label: 'Valid',
            ikon: Icons.check_circle_outline,
            warna: AppColors.statusOk,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Statistik(
            nilai: '${hasil.jumlahGagal}',
            label: 'Gagal',
            ikon: Icons.error_outline,
            warna: AppColors.statusDanger,
          ),
        ),
      ],
    );
  }

  Widget _kotakInfo(AppPalette pal, IconData ikon, Color warna, String pesan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: pal.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(ikon, size: AppSizes.iconSm, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: pal.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catatan(AppPalette pal) {
    return Text(
      'Impor massal hanya untuk Admin. Kolom harus berurutan: '
      'barcode_alat, merk_alat, nama_kategori, nama_lokasi. Kategori dan lokasi '
      'harus sudah terdaftar di Master Data — impor tidak membuat master data '
      'baru.',
      style: TextStyle(fontSize: 11, height: 1.6, color: pal.textSecondary),
    );
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  /// Ketikan pengguna selalu menang atas berkas terpilih, dan hasil pratinjau
  /// lama dibuang agar tahap impor tidak memakai data yang sudah berubah.
  void _saatTeksBerubah(String nilai) {
    setState(() {
      _fileBytes = null;
      _namaFile = _namaBerkasBawaan;
      _hasilPratinjau = null;
      _hasilImpor = null;
      _sumberTervalidasi = null;
      _galat = null;
      _aksiGalat = null;
    });
  }

  Future<void> _pilihBerkas() async {
    if (_sibuk) return;

    try {
      final FilePickerResult? hasil = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
        withData: true,
      );
      if (hasil == null || hasil.files.isEmpty) return; // dialog dibatalkan

      final PlatformFile berkas = hasil.files.single;
      final List<int>? bytes = berkas.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          'Berkas tidak dapat dibaca di perangkat ini. Tempel isi CSV sebagai teks.',
          type: AppSnackbarType.gagal,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _fileBytes = List<int>.unmodifiable(bytes);
        _namaFile = berkas.name.trim().isEmpty
            ? _namaBerkasBawaan
            : berkas.name.trim();
        _csv.clear();
        _hasilPratinjau = null;
        _hasilImpor = null;
        _sumberTervalidasi = null;
        _galat = null;
        _aksiGalat = null;
      });
    } catch (e, st) {
      debugPrint('AlatImportScreen._pilihBerkas gagal: $st');
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Berkas tidak dapat dibuka. Tempel isi CSV sebagai teks.',
        type: AppSnackbarType.gagal,
      );
    }
  }

  void _hapusBerkas() {
    setState(() {
      _fileBytes = null;
      _namaFile = _namaBerkasBawaan;
      _hasilPratinjau = null;
      _hasilImpor = null;
      _sumberTervalidasi = null;
      _galat = null;
      _aksiGalat = null;
    });
  }

  Future<void> _salinContoh() async {
    await Clipboard.setData(const ClipboardData(text: _contohCsv));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      'Contoh CSV disalin.',
      type: AppSnackbarType.sukses,
    );
  }

  /// Susun sumber dari kondisi UI saat ini (berkas menang atas teks).
  _SumberImpor _sumber() {
    final List<int>? bytes = _fileBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return _SumberImpor(fileBytes: bytes, namaFile: _namaFile);
    }
    return _SumberImpor(csv: _csv.text, namaFile: _namaFile);
  }

  Future<void> _pratinjau() async {
    if (_sibuk) return;

    final _SumberImpor sumber = _sumber();
    if (sumber.kosong) {
      AppSnackbar.show(
        context,
        'Tempel isi CSV atau pilih berkas terlebih dahulu.',
        type: AppSnackbarType.gagal,
      );
      return;
    }

    setState(() {
      _memuat = true;
      _galat = null;
      _aksiGalat = null;
      _hasilPratinjau = null;
      _hasilImpor = null;
      _sumberTervalidasi = null;
    });

    try {
      final AlatImportResult hasil = await ref
          .read(alatRepositoryProvider)
          .previewImpor(
            csv: sumber.csv,
            fileBytes: sumber.fileBytes,
            namaFile: sumber.namaFile,
          );
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _hasilPratinjau = hasil;
        _sumberTervalidasi = sumber;
      });
      AppSnackbar.show(
        context,
        hasil.semuaValid
            ? 'Semua ${hasil.total} baris valid.'
            : '${hasil.jumlahValid} baris valid, ${hasil.jumlahGagal} baris gagal.',
        type: hasil.semuaValid ? AppSnackbarType.sukses : AppSnackbarType.info,
      );
    } catch (e, st) {
      debugPrint('AlatImportScreen._pratinjau gagal: $st');
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = _pesanGalat(e);
        _aksiGalat = _AksiGalat.pratinjau;
      });
    }
  }

  Future<void> _impor() async {
    if (_sibuk) return;

    final AlatImportResult? pratinjau = _hasilPratinjau;
    final _SumberImpor? sumber = _sumberTervalidasi;
    if (pratinjau == null || sumber == null) {
      AppSnackbar.show(
        context,
        'Lakukan pratinjau terlebih dahulu.',
        type: AppSnackbarType.gagal,
      );
      return;
    }
    if (pratinjau.tidakAdaBarisValid) {
      AppSnackbar.show(
        context,
        'Tidak ada baris valid untuk diimpor.',
        type: AppSnackbarType.gagal,
      );
      return;
    }

    final bool setuju = await _konfirmasiImpor(pratinjau) ?? false;
    if (!setuju || !mounted) return;

    setState(() {
      _mengimpor = true;
      _galat = null;
      _aksiGalat = null;
    });

    try {
      final AlatImportResult hasil = await ref
          .read(alatRepositoryProvider)
          .commitImpor(
            csv: sumber.csv,
            fileBytes: sumber.fileBytes,
            namaFile: sumber.namaFile,
          );
      if (!mounted) return;
      setState(() {
        _mengimpor = false;
        _hasilImpor = hasil;
        _hasilPratinjau = null;
        _sumberTervalidasi = null;
      });
      // Daftar di Manajemen Alat ikut disegarkan agar hasil impor langsung tampil.
      ref.read(masterAlatProvider.notifier).refresh();
      AppSnackbar.show(
        context,
        '${hasil.jumlahValid} alat diimpor.',
        type: AppSnackbarType.sukses,
      );
    } catch (e, st) {
      debugPrint('AlatImportScreen._impor gagal: $st');
      if (!mounted) return;
      setState(() {
        _mengimpor = false;
        _galat = _pesanGalat(e);
        _aksiGalat = _AksiGalat.impor;
      });
    }
  }

  Future<void> _ulangi() {
    final _AksiGalat? aksi = _aksiGalat;
    if (aksi == _AksiGalat.impor) return _impor();
    return _pratinjau();
  }

  /// Konfirmasi sebelum menulis database (impor = mutasi data).
  Future<bool?> _konfirmasiImpor(AlatImportResult pratinjau) {
    final String ekor = pratinjau.jumlahGagal > 0
        ? ' ${pratinjau.jumlahGagal} baris gagal akan dilewati.'
        : ' Seluruh baris valid.';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Impor sekarang?'),
        content: Text(
          '${pratinjau.jumlahValid} alat akan disimpan ke database.$ekor',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('IMPOR'),
          ),
        ],
      ),
    );
  }

  /// Terjemahkan exception API menjadi kalimat yang bisa ditindaklanjuti.
  String _pesanGalat(Object e) {
    if (e is ValidationException) {
      final StringBuffer buffer = StringBuffer(e.message);
      final Map<String, List<String>>? rincian = e.errors;
      if (rincian != null && rincian.isNotEmpty) {
        rincian.forEach((String kolom, List<String> daftarPesan) {
          for (final String pesan in daftarPesan) {
            buffer.write('\n• $kolom: $pesan');
          }
        });
      }
      return buffer.toString();
    }
    if (e is ForbiddenException) return 'Hanya Admin yang dapat mengimpor.';
    if (e is NetworkException) {
      return 'Koneksi internet terputus. Periksa jaringan lalu tekan COBA LAGI.';
    }
    if (e is ApiException) return e.message;
    return 'Terjadi kesalahan tak terduga. Silakan coba lagi.';
  }
}

/// Satu kotak statistik kecil (angka + label) pada kartu hasil.
class _Statistik extends StatelessWidget {
  const _Statistik({
    required this.nilai,
    required this.label,
    required this.ikon,
    required this.warna,
  });

  final String nilai;
  final String label;
  final IconData ikon;

  /// Warna aksen ikon (semantik status), bukan warna teks.
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: pal.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ikon, size: 14, color: warna),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: pal.textSecondary),
          ),
        ],
      ),
    );
  }
}
