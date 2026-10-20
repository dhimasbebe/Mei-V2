import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/foto_lokal.dart';
import '../../../core/media/photo_store.dart';
import '../../../core/maintenance/checklist_quick_fill.dart';
import '../../../core/offline/draft_queue.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/maintenance.dart';
import '../../../domain/models/spesifikasi.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/draft_provider.dart';
import '../../../providers/kategori_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/success_check.dart';
import '../../widgets/foto_picker_field.dart';
import '../../../core/theme/app_palette.dart';

/// Form pemeliharaan dinamis berdasarkan spesifikasi kategori.
/// Teknisi mengisi checklist item per item, lalu kirim ke server.
class MaintenanceFormScreen extends ConsumerStatefulWidget {
  const MaintenanceFormScreen({super.key});

  @override
  ConsumerState<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends ConsumerState<MaintenanceFormScreen> {
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  final Map<int, String?> _selectValues = <int, String?>{};
  final TextEditingController _catatanCtrl = TextEditingController();
  String? _kondisiKeseluruhan;
  bool _isSubmitting = false;

  /// Foto lampiran lokal (Tahap 3 — WS C). Dimiliki state form; parent
  /// widget menyimpannya ke draf offline lewat [DraftRecord.fotoPaths].
  List<FotoLokal> _fotos = <FotoLokal>[];

  /// UUID draf autosave sesi ini (dibuat sekali, dipertahankan saat
  /// autosave berikutnya supaya antrean tidak menduplikasi — AC-A3).
  String? _uuidDraf;

  /// Apakah draf sudah masuk antrean (enqueue pertama, lalu replace).
  bool _drafTersimpan = false;

  /// ID laporan asal bila form dibuka lewat aksi "Duplikat" (AC-K6);
  /// `null` pada form biasa sehingga penanda salinan tidak muncul.
  int? _salinanDari;

  /// Timer debounce autosave 600 ms (§5.1) — form menulis draf setelah
  /// pengguna berhenti mengetik, bukan pada tiap ketukan tombol.
  Timer? _debounceDraf;

  /// Nilai satu item checklist (select atau teks) — dipakai menghitung progres.
  String _nilaiUntuk(Spesifikasi s) => s.tipeInput == 'select'
      ? (_selectValues[s.idSpesifikasi] ?? '')
      : (_controllers[s.idSpesifikasi]?.text.trim() ?? '');

  /// Dipanggil setiap isi field berubah agar bilah progres ikut bergerak
  /// dan autosave draf dijadwalkan.
  void _perbaruiProgres() {
    if (mounted) setState(() {});
    _jadwalkanSimpanDraf();
  }

  /// Menjadwalkan autosave draf (debounce 600 ms).
  void _jadwalkanSimpanDraf() {
    _debounceDraf?.cancel();
    _debounceDraf = Timer(const Duration(milliseconds: 600), _simpanDrafSekarang);
  }

  /// Membangun [DraftRecord] dari isi form saat ini.
  DraftRecord _bangunDraf() {
    final MaintenancePayload? formState = ref.read(maintenanceFormProvider);
    final Map<int, String> checklist = <int, String>{};
    _controllers.forEach((int id, TextEditingController c) {
      final String v = c.text.trim();
      if (v.isNotEmpty) checklist[id] = v;
    });
    _selectValues.forEach((int id, String? v) {
      if (v != null && v.trim().isNotEmpty) checklist[id] = v.trim();
    });

    _uuidDraf ??= MaintenancePayload(
      barcodeAlat: formState?.barcodeAlat ?? '',
      idLokasi: formState?.idLokasi ?? 0,
      detail: const <DetailMaintenance>[],
    ).clientUuid;

    return DraftRecord(
      clientUuid: _uuidDraf!,
      barcodeAlat: formState?.barcodeAlat ?? '',
      idLokasi: formState?.idLokasi ?? 0,
      idKategori: ref.read(alatDetailProvider)?.idKategori,
      waktuMaintenance: formState?.waktuMaintenance ?? DateTime.now(),
      checklist: checklist,
      catatan: _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
      kondisiKeseluruhan: _kondisiKeseluruhan,
      fotoPaths: _fotos.map((FotoLokal f) => f.kunci).toList(growable: false),
    );
  }

  /// Menyimpan draf ke antrean offline (AC-A12): draf belum lengkap pun
  /// tersimpan, sehingga aplikasi mati mendadak tidak menghilangkan kerja
  /// teknisi.
  Future<void> _simpanDrafSekarang() async {
    final MaintenancePayload? formState = ref.read(maintenanceFormProvider);
    if (formState == null) return;
    final DraftNotifier notifier = ref.read(draftQueueProvider.notifier);
    final DraftRecord draf = _bangunDraf();
    if (!_drafTersimpan) {
      _drafTersimpan = true;
      await notifier.simpanDraf(draf);
    } else {
      await notifier.perbaruiDraf(draf);
    }
  }

  @override
  void initState() {
    super.initState();

    // Duplikat laporan (WS K): isi awal dari draf yang dibentuk riwayat.
    // Dibaca SEKALI, lalu provider dikosongkan agar tidak terbawa ke form
    // berikutnya.
    final DraftRecord? seed = ref.read(formSeedProvider);
    if (seed != null) {
      _selectValues.addAll(seed.checklist);
      _catatanCtrl.text = seed.catatan ?? '';
      _kondisiKeseluruhan = seed.kondisiKeseluruhan;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(formSeedProvider.notifier).state = null;
      });
    }

    // Penanda "Salinan dari laporan #N" (AC-K6). Dibaca-sekali lalu
    // dikosongkan, sehingga form biasa berikutnya tidak mewarisi banner.
    _salinanDari = ref.read(salinanDariProvider);
    if (_salinanDari != null) {
      ref.read(salinanDariProvider.notifier).state = null;
    }

    // Catatan ikut memicu progres + autosave draf.
    _catatanCtrl.addListener(_perbaruiProgres);
  }

  @override
  void dispose() {
    _debounceDraf?.cancel();
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    _catatanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(maintenanceFormProvider);

    if (formState == null) {
      return const AppScaffold(
        useRedAppBar: true,
        title: 'Form Maintenance',
        body: Center(child: Text('Form tidak tersedia.')),
      );
    }

    // Ambil alat detail untuk tahu id_kategori → spesifikasi
    // Untuk sekarang kita pakai hardcoded mapping barcode prefix atau fetch dari alat state.
    // Lebih baik: alat state harusnya sudah punya id_kategori.
    final alat = ref.watch(alatDetailProvider);
    final int? idKategori = alat?.idKategori;
    final spesifikasiAsync = idKategori != null
        ? ref.watch(spesifikasiProvider(idKategori))
        : const AsyncValue<List<Spesifikasi>>.data(<Spesifikasi>[]);

    return AppScaffold(
      useRedAppBar: true,
      title: 'Form Maintenance',
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: spesifikasiAsync.when(
        data: (List<Spesifikasi> list) => _buildForm(list, formState),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (Object e, _) => Center(
          child: Text('Gagal memuat form checklist.\n$e', textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildForm(List<Spesifikasi> list, MaintenancePayload formState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_salinanDari != null) ...<Widget>[
            _PenandaSalinan(idSumber: _salinanDari!),
            const SizedBox(height: 16),
          ],
          _HeaderInfo(formState: formState),
          const SizedBox(height: 16),
          _ProgresChecklist(
            terisi: list.where((Spesifikasi s) => _nilaiUntuk(s).isNotEmpty).length,
            total: list.length,
            kondisiTerpilih: _kondisiKeseluruhan != null,
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Checklist Pemeriksaan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _isiSemuaBaik(list),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Semua Baik'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...list.map((Spesifikasi s) => _buildInput(s)),
          const SizedBox(height: 20),
          Text(
            'Kondisi Keseluruhan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _KondisiSelector(
            value: _kondisiKeseluruhan,
            onChanged: (String? v) {
              setState(() => _kondisiKeseluruhan = v);
              _jadwalkanSimpanDraf();
            },
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _catatanCtrl,
            label: 'Catatan Tambahan',
            hint: 'Opsional: tulis temuan atau kendala...',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          FotoPickerField(
            fotos: _fotos,
            onChanged: (List<FotoLokal> v) {
              setState(() => _fotos = v);
              _jadwalkanSimpanDraf();
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'KIRIM',
            isLoading: _isSubmitting,
            onPressed: () => _submit(list),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInput(Spesifikasi s) {
    final String label = s.namaSpesifikasi;
    final String? satuan = s.satuan;
    final String satuanText = (satuan != null && satuan.isNotEmpty) ? ' ($satuan)' : '';

    if (s.tipeInput == 'select' && s.opsi.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$label$satuanText', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.pal.borderSubtle),
                borderRadius: BorderRadius.circular(12),
                color: context.pal.surfaceAlt,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectValues[s.idSpesifikasi],
                  hint: Text('Pilih'),
                  items: s.opsi
                      .map((String o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (String? v) {
                    setState(() => _selectValues[s.idSpesifikasi] = v);
                    _jadwalkanSimpanDraf();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // text / number
    _controllers.putIfAbsent(
      s.idSpesifikasi,
      () => TextEditingController()..addListener(_perbaruiProgres),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: _controllers[s.idSpesifikasi]!,
        label: '$label$satuanText',
        keyboardType: s.tipeInput == 'number' ? TextInputType.number : TextInputType.text,
      ),
    );
  }

  /// Aksi "Semua Baik" (WS J) — hanya mengisi item pilihan yang punya opsi
  /// Baik/OK dan BELUM diisi pengguna. Isian yang sudah ada tidak ditimpa dan
  /// item angka/teks tetap kosong (AC-J1/J2), seluruhnya lewat modul murni
  /// [ChecklistQuickFill] agar perilakunya identik dengan yang diuji
  /// `tools/modelcheck`.
  void _isiSemuaBaik(List<Spesifikasi> list) {
    if (list.isEmpty) return;

    final List<QuickFillItem> items = list
        .map((Spesifikasi s) => QuickFillItem(
              idSpesifikasi: s.idSpesifikasi,
              tipeInput: s.tipeInput,
              opsi: s.opsi,
              nilai: _nilaiUntuk(s),
            ))
        .toList(growable: false);

    final int akanDiisi = ChecklistQuickFill.markAllOk(items);
    if (akanDiisi == 0) {
      AppSnackbar.show(
        context,
        'Tidak ada item pilihan yang kosong. Isian Anda tidak diubah.',
        type: AppSnackbarType.info,
      );
      return;
    }

    final List<QuickFillItem> hasil = ChecklistQuickFill.isiSemua(items);
    setState(() {
      for (int i = 0; i < items.length; i++) {
        // Hanya item select yang BARU terisi — tidak menimpa isian pengguna.
        if (items[i].tipeInput != 'select') continue;
        if (!items[i].terisi && hasil[i].terisi) {
          _selectValues[hasil[i].idSpesifikasi] = hasil[i].nilai;
        }
      }
    });
    _jadwalkanSimpanDraf();

    AppSnackbar.show(
      context,
      '$akanDiisi item ditandai Baik',
      type: AppSnackbarType.sukses,
    );
  }

  Future<void> _submit(List<Spesifikasi> list) async {
    if (_kondisiKeseluruhan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kondisi keseluruhan terlebih dahulu.')),
      );
      return;
    }

    final List<DetailMaintenance> detail = <DetailMaintenance>[];
    for (final Spesifikasi s in list) {
      String status;
      if (s.tipeInput == 'select') {
        status = _selectValues[s.idSpesifikasi] ?? '';
      } else {
        status = _controllers[s.idSpesifikasi]?.text.trim() ?? '';
      }
      if (status.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${s.namaSpesifikasi}" belum diisi.')),
        );
        return;
      }
      detail.add(DetailMaintenance(idSpesifikasi: s.idSpesifikasi, status: status));
    }

    setState(() => _isSubmitting = true);

    ref.read(maintenanceFormProvider.notifier).updateDetail(detail);
    ref.read(maintenanceFormProvider.notifier).updateCatatan(
          _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
        );
    ref.read(maintenanceFormProvider.notifier).updateKondisi(_kondisiKeseluruhan);

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final Maintenance laporan =
          await ref.read(maintenanceFormProvider.notifier).submit(repo);

      // Unggah foto lampiran (Tahap 3 — WS C) setelah laporan ada di server.
      await _unggahFoto(laporan.idMaintenance);

      // Draf autosave tidak diperlukan lagi — laporan sudah terkirim.
      if (_drafTersimpan && _uuidDraf != null) {
        await ref.read(draftQueueProvider.notifier).hapusDraf(_uuidDraf!);
      }
      _uuidDraf = null;
      _drafTersimpan = false;

      if (mounted) {
        // AC-F4: animasi centang (CustomPainter, tanpa paket tambahan)
        // tampil sebelum snackbar; dilewati bila pengguna mematikan animasi.
        await tampilkanAnimasiSukses(context, judul: 'Laporan terkirim');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance berhasil dikirim!'), backgroundColor: AppColors.statusOk),
        );
        context.goHome();
      }
    } catch (e) {
      if (mounted) {
        // Simpan laporan ke antrean offline (WS A): akan dikirim otomatis
        // saat online (AC-A19), idempoten lewat client_uuid (AC-A17).
        await ref.read(draftQueueProvider.notifier).simpanDraf(_bangunDraf());
        _drafTersimpan = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim. Laporan disimpan di antrean offline '
                'dan dikirim otomatis saat online.'),
            backgroundColor: AppColors.statusWarning,
          ),
        );
        context.goHome();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Mengunggah seluruh foto lokal ke [idMaintenance]. Kegagalan satu foto
  /// tidak membatalkan laporan — foto tersisa dicoba, sisanya dilaporkan.
  Future<void> _unggahFoto(int idMaintenance) async {
    for (final FotoLokal f in _fotos) {
      final List<int>? bytes = await PhotoStore.baca(f.kunci);
      if (bytes == null) continue;
      try {
        await ref.read(fotoRepositoryProvider).upload(
              idMaintenance,
              bytes: bytes,
              namaFile: f.nama,
            );
      } catch (_) {
        // Foto gagal terunggah: laporan tetap terkirim; teknisi dapat
        // mengunggah ulang lewat detail laporan.
      }
    }
  }
}

/// Bilah progres pengisian form.
///
/// Memberi umpan balik langsung saat teknisi mengisi checklist: berapa item
/// yang sudah terisi, dan apakah kondisi keseluruhan sudah dipilih. Sebelumnya
/// teknisi baru tahu ada yang kurang setelah menekan KIRIM.
class _ProgresChecklist extends StatelessWidget {
  const _ProgresChecklist({
    required this.terisi,
    required this.total,
    required this.kondisiTerpilih,
  });

  final int terisi;
  final int total;
  final bool kondisiTerpilih;

  @override
  Widget build(BuildContext context) {
    final int langkahTerisi = terisi + (kondisiTerpilih ? 1 : 0);
    final int langkahTotal = total + 1;
    final double rasio = langkahTotal == 0 ? 0 : langkahTerisi / langkahTotal;
    final bool lengkap = langkahTerisi >= langkahTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lengkap
            ? AppColors.kondisiBaikSoft
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lengkap
              ? AppColors.kondisiBaik.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                lengkap ? Icons.check_circle_outline : Icons.playlist_add_check,
                size: 18,
                color: lengkap ? AppColors.kondisiBaik : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lengkap
                      ? 'Semua item terisi — siap dikirim'
                      : 'Kelengkapan pengisian',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: lengkap ? AppColors.kondisiBaik : context.pal.textPrimary,
                  ),
                ),
              ),
              Text(
                '$langkahTerisi/$langkahTotal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: lengkap ? AppColors.kondisiBaik : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: rasio),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? child) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: context.pal.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    lengkap ? AppColors.kondisiBaik : AppColors.primary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.formState});
  final MaintenancePayload formState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row(context, 'Barcode', formState.barcodeAlat),
          const SizedBox(height: 4),
          _row(context, 'Waktu', _fmt(formState.waktuMaintenance)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: context.pal.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _KondisiSelector extends StatelessWidget {
  const _KondisiSelector({this.value, this.onChanged});

  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[
      <String, dynamic>{'label': 'Baik', 'value': 'baik', 'color': AppColors.statusOk},
      <String, dynamic>{'label': 'Kurang Baik', 'value': 'kurang_baik', 'color': AppColors.statusWarning},
      <String, dynamic>{'label': 'Rusak', 'value': 'rusak', 'color': AppColors.statusDanger},
    ];

    return Row(
      children: items.map((Map<String, dynamic> item) {
        final bool selected = value == item['value'] as String;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onChanged?.call(item['value'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? (item['color'] as Color).withValues(alpha: 0.1) : context.pal.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? item['color'] as Color : context.pal.borderSubtle,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.circle,
                      size: 14,
                      color: selected ? item['color'] as Color : context.pal.divider,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? item['color'] as Color : context.pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Penanda bahwa form ini adalah salinan laporan lama (AC-K6).
///
/// Tanpa penanda ini teknisi tidak tahu sedang menyunting salinan, bukan
/// laporan asli. Seluruh warna memakai token tema (`context.pal` /
/// [AppColors.primary]) agar ikut mode gelap.
class _PenandaSalinan extends StatelessWidget {
  const _PenandaSalinan({required this.idSumber});

  /// ID laporan asal yang disalin.
  final int idSumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.pal.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.pal.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.copy_all_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Salinan dari laporan #$idSumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Periksa dan ubah bagian yang berbeda sebelum mengirim.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.pal.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
