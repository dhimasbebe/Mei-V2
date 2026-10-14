import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/maintenance.dart';
import '../../../domain/models/spesifikasi.dart';
import '../../../providers/alat_provider.dart';
import '../../../providers/kategori_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';

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

  /// Nilai satu item checklist (select atau teks) — dipakai menghitung progres.
  String _nilaiUntuk(Spesifikasi s) => s.tipeInput == 'select'
      ? (_selectValues[s.idSpesifikasi] ?? '')
      : (_controllers[s.idSpesifikasi]?.text.trim() ?? '');

  /// Dipanggil setiap isi field berubah agar bilah progres ikut bergerak.
  void _perbaruiProgres() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
        icon: const Icon(Icons.arrow_back),
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
          _HeaderInfo(formState: formState),
          const SizedBox(height: 16),
          _ProgresChecklist(
            terisi: list.where((Spesifikasi s) => _nilaiUntuk(s).isNotEmpty).length,
            total: list.length,
            kondisiTerpilih: _kondisiKeseluruhan != null,
          ),
          const SizedBox(height: 20),
          const Text(
            'Checklist Pemeriksaan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...list.map((Spesifikasi s) => _buildInput(s)),
          const SizedBox(height: 20),
          const Text(
            'Kondisi Keseluruhan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _KondisiSelector(
            value: _kondisiKeseluruhan,
            onChanged: (String? v) => setState(() => _kondisiKeseluruhan = v),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _catatanCtrl,
            label: 'Catatan Tambahan',
            hint: 'Opsional: tulis temuan atau kendala...',
            onTap: () {},
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
            Text('$label$satuanText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectValues[s.idSpesifikasi],
                  hint: const Text('Pilih'),
                  items: s.opsi
                      .map((String o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (String? v) => setState(() => _selectValues[s.idSpesifikasi] = v),
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
      await ref.read(maintenanceFormProvider.notifier).submit(repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance berhasil dikirim!'), backgroundColor: Colors.green),
        );
        context.goHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                    color: lengkap ? AppColors.kondisiBaik : AppColors.textPrimary,
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
                  backgroundColor: Colors.white,
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
          _row('Barcode', formState.barcodeAlat),
          const SizedBox(height: 4),
          _row('Waktu', _fmt(formState.waktuMaintenance)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
      <String, dynamic>{'label': 'Baik', 'value': 'baik', 'color': Colors.green},
      <String, dynamic>{'label': 'Kurang Baik', 'value': 'kurang_baik', 'color': Colors.orange},
      <String, dynamic>{'label': 'Rusak', 'value': 'rusak', 'color': Colors.red},
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
                  color: selected ? (item['color'] as Color).withValues(alpha: 0.1) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? item['color'] as Color : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.circle,
                      size: 14,
                      color: selected ? item['color'] as Color : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? item['color'] as Color : Colors.grey.shade700,
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
