import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/kategori.dart';
import '../../../domain/models/lokasi.dart';
import '../../../domain/models/spesifikasi.dart';
import '../../../providers/master_data_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Master Data (Admin) — kategori, lokasi, dan checklist spesifikasi.
///
/// Ketiganya adalah sumber kebenaran aplikasi: kategori menentukan siklus
/// overdue, lokasi dipakai pada detail alat, dan checklist menggerakkan form
/// pemeliharaan dinamis milik teknisi.
class MasterDataScreen extends ConsumerStatefulWidget {
  const MasterDataScreen({super.key});

  @override
  ConsumerState<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends ConsumerState<MasterDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(masterKategoriProvider.notifier).load();
      ref.read(masterLokasiProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const <Widget>[
            Tab(text: 'Kategori'),
            Tab(text: 'Lokasi'),
            Tab(text: 'Checklist'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const <Widget>[
              _TabKategori(),
              _TabLokasi(),
              _TabSpesifikasi(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kategori
// ---------------------------------------------------------------------------

class _TabKategori extends ConsumerStatefulWidget {
  const _TabKategori();

  @override
  ConsumerState<_TabKategori> createState() => _TabKategoriState();
}

class _TabKategoriState extends ConsumerState<_TabKategori> {
  @override
  Widget build(BuildContext context) {
    final MasterListState<Kategori> state = ref.watch(masterKategoriProvider);

    return _KerangkaTab(
      labelTambah: 'TAMBAH KATEGORI',
      onTambah: () => _form(),
      onRetry: () => ref.read(masterKategoriProvider.notifier).load(),
      isLoading: state.isLoading,
      error: state.error,
      isEmpty: state.isEmpty,
      kosongJudul: 'Belum ada kategori',
      kosongPesan: 'Tambahkan kategori alat terlebih dahulu.',
      children: state.items
          .map(
            (Kategori k) => _BarisData(
              judul: k.nama,
              keterangan: 'Siklus ${k.maintenanceCycleDays} hari • '
                  '${k.jumlahAlat ?? 0} alat',
              ikonAsset: k.iconTampil,
              badge: '${k.maintenanceCycleDays} hari',
              onEdit: () => _form(kategori: k),
              onDelete: () => _hapus(k),
            ),
          )
          .toList(),
    );
  }

  Future<void> _form({Kategori? kategori}) async {
    final TextEditingController nama =
        TextEditingController(text: kategori?.nama ?? '');
    final TextEditingController deskripsi =
        TextEditingController(text: kategori?.deskripsi ?? '');
    final TextEditingController siklus =
        TextEditingController(text: '${kategori?.maintenanceCycleDays ?? 30}');

    final bool simpan = await _dialogForm(
      context,
      judul: kategori == null ? 'Tambah kategori' : 'Ubah kategori',
      fields: <Widget>[
        AppTextField(controller: nama, label: 'Nama kategori'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(controller: deskripsi, label: 'Deskripsi'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: siklus,
          label: 'Siklus pemeliharaan (hari)',
          keyboardType: TextInputType.number,
        ),
      ],
    );

    if (simpan && mounted) {
      final MasterKategoriNotifier notifier =
          ref.read(masterKategoriProvider.notifier);
      final int? siklusHari = int.tryParse(siklus.text.trim());
      final bool ok = kategori == null
          ? await notifier.create(
              nama: nama.text.trim(),
              deskripsi: deskripsi.text.trim(),
              maintenanceCycleDays: siklusHari,
            )
          : await notifier.update(
              id: kategori.idKategori,
              nama: nama.text.trim(),
              deskripsi: deskripsi.text.trim(),
            );
      if (ok && kategori != null && siklusHari != null) {
        await notifier.updateCycle(
          id: kategori.idKategori,
          maintenanceCycleDays: siklusHari,
        );
      }
      if (mounted) _pesan(context, ok, 'Kategori tersimpan.');
    }

    nama.dispose();
    deskripsi.dispose();
    siklus.dispose();
  }

  Future<void> _hapus(Kategori k) async {
    final bool ok = await _konfirmasiHapus(
      context,
      'Hapus kategori "${k.nama}"?',
      'Alat yang memakai kategori ini bisa kehilangan relasinya.',
    );
    if (!ok || !mounted) return;
    final bool hasil =
        await ref.read(masterKategoriProvider.notifier).delete(k.idKategori);
    if (mounted) _pesan(context, hasil, 'Kategori dihapus.');
  }
}

// ---------------------------------------------------------------------------
// Lokasi
// ---------------------------------------------------------------------------

class _TabLokasi extends ConsumerStatefulWidget {
  const _TabLokasi();

  @override
  ConsumerState<_TabLokasi> createState() => _TabLokasiState();
}

class _TabLokasiState extends ConsumerState<_TabLokasi> {
  @override
  Widget build(BuildContext context) {
    final MasterListState<Lokasi> state = ref.watch(masterLokasiProvider);

    return _KerangkaTab(
      labelTambah: 'TAMBAH LOKASI',
      onTambah: () => _form(),
      onRetry: () => ref.read(masterLokasiProvider.notifier).load(),
      isLoading: state.isLoading,
      error: state.error,
      isEmpty: state.isEmpty,
      kosongJudul: 'Belum ada lokasi',
      kosongPesan: 'Tambahkan lokasi penempatan alat.',
      children: state.items
          .map(
            (Lokasi l) => _BarisData(
              judul: l.namaLokasi,
              keterangan: '${l.jumlahAlat ?? 0} alat',
              ikon: Icons.location_on_outlined,
              badge: l.lantai == null ? null : 'Lantai ${l.lantai}',
              onEdit: () => _form(lokasi: l),
              onDelete: () => _hapus(l),
            ),
          )
          .toList(),
    );
  }

  Future<void> _form({Lokasi? lokasi}) async {
    final TextEditingController nama =
        TextEditingController(text: lokasi?.namaLokasi ?? '');
    final TextEditingController lantai =
        TextEditingController(text: lokasi?.lantai?.toString() ?? '');

    final bool simpan = await _dialogForm(
      context,
      judul: lokasi == null ? 'Tambah lokasi' : 'Ubah lokasi',
      fields: <Widget>[
        AppTextField(controller: nama, label: 'Nama lokasi'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: lantai,
          label: 'Lantai',
          keyboardType: TextInputType.number,
        ),
      ],
    );

    if (simpan && mounted) {
      final MasterLokasiNotifier notifier = ref.read(masterLokasiProvider.notifier);
      final int? lantaiAngka = int.tryParse(lantai.text.trim());
      final bool ok = lokasi == null
          ? await notifier.create(namaLokasi: nama.text.trim(), lantai: lantaiAngka)
          : await notifier.update(
              id: lokasi.idLokasi,
              namaLokasi: nama.text.trim(),
              lantai: lantaiAngka,
            );
      if (mounted) _pesan(context, ok, 'Lokasi tersimpan.');
    }

    nama.dispose();
    lantai.dispose();
  }

  Future<void> _hapus(Lokasi l) async {
    final bool ok = await _konfirmasiHapus(
      context,
      'Hapus lokasi "${l.namaLokasi}"?',
      'Alat di lokasi ini bisa kehilangan relasinya.',
    );
    if (!ok || !mounted) return;
    final bool hasil =
        await ref.read(masterLokasiProvider.notifier).delete(l.idLokasi);
    if (mounted) _pesan(context, hasil, 'Lokasi dihapus.');
  }
}

// ---------------------------------------------------------------------------
// Spesifikasi (checklist per kategori)
// ---------------------------------------------------------------------------

class _TabSpesifikasi extends ConsumerStatefulWidget {
  const _TabSpesifikasi();

  @override
  ConsumerState<_TabSpesifikasi> createState() => _TabSpesifikasiState();
}

class _TabSpesifikasiState extends ConsumerState<_TabSpesifikasi> {
  int? _idKategori;

  @override
  Widget build(BuildContext context) {
    final MasterListState<Kategori> kategori = ref.watch(masterKategoriProvider);

    if (kategori.isLoading && kategori.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[SkeletonListTile(), SkeletonListTile()],
        ),
      );
    }

    final int? terpilih = _idKategori ??
        (kategori.items.isEmpty ? null : kategori.items.first.idKategori);

    if (terpilih == null) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'Belum ada kategori',
        message: 'Tambahkan kategori dulu di tab Kategori.',
      );
    }

    final MasterListState<Spesifikasi> state =
        ref.watch(masterSpesifikasiProvider(terpilih));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: DropdownButtonFormField<int>(
            initialValue: terpilih,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: kategori.items
                .map(
                  (Kategori k) => DropdownMenuItem<int>(
                    value: k.idKategori,
                    child: Text(k.nama),
                  ),
                )
                .toList(),
            onChanged: (int? v) => setState(() => _idKategori = v),
          ),
        ),
        Expanded(
          child: _KerangkaTab(
            labelTambah: 'TAMBAH ITEM CHECKLIST',
            onTambah: () => _form(terpilih),
            onRetry: () =>
                ref.read(masterSpesifikasiProvider(terpilih).notifier).load(),
            isLoading: state.isLoading,
            error: state.error,
            isEmpty: state.isEmpty,
            kosongJudul: 'Checklist masih kosong',
            kosongPesan:
                'Teknisi tidak akan bisa mengisi form tanpa item checklist.',
            children: state.items
                .map(
                  (Spesifikasi s) => _BarisData(
                    judul: s.namaSpesifikasi,
                    keterangan: '${s.tipeInput}'
                        '${s.satuan == null ? '' : ' • ${s.satuan}'}'
                        '${s.opsi.isEmpty ? '' : ' • ${s.opsi.join(', ')}'}',
                    ikon: Icons.checklist_rtl,
                    badge: '#${s.urutan}',
                    onEdit: () => _form(terpilih, spesifikasi: s),
                    onDelete: () => _hapus(terpilih, s),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _form(int idKategori, {Spesifikasi? spesifikasi}) async {
    final TextEditingController nama =
        TextEditingController(text: spesifikasi?.namaSpesifikasi ?? '');
    final TextEditingController satuan =
        TextEditingController(text: spesifikasi?.satuan ?? '');
    final TextEditingController opsi =
        TextEditingController(text: spesifikasi?.opsiRaw ?? '');
    String tipe = spesifikasi?.tipeInput ?? 'text';

    final bool simpan = await _dialogForm(
      context,
      judul: spesifikasi == null ? 'Tambah item checklist' : 'Ubah item checklist',
      fields: <Widget>[
        AppTextField(controller: nama, label: 'Nama item'),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: tipe,
          decoration: const InputDecoration(labelText: 'Tipe input'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'text', child: Text('Teks')),
            DropdownMenuItem<String>(value: 'number', child: Text('Angka')),
            DropdownMenuItem<String>(
              value: 'select',
              child: Text('Pilihan (select)'),
            ),
          ],
          onChanged: (String? v) => tipe = v ?? tipe,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: satuan,
          label: 'Satuan (opsional)',
          hint: 'mis. bar, psi, liter',
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: opsi,
          label: 'Pilihan (opsional)',
          hint: 'pisahkan dengan koma: Baik, Tidak Baik',
        ),
      ],
    );

    if (simpan && mounted) {
      final MasterSpesifikasiNotifier notifier =
          ref.read(masterSpesifikasiProvider(idKategori).notifier);
      final bool ok = spesifikasi == null
          ? await notifier.create(
              namaSpesifikasi: nama.text.trim(),
              tipeInput: tipe,
              satuan: satuan.text.trim().isEmpty ? null : satuan.text.trim(),
              opsi: opsi.text.trim().isEmpty ? null : opsi.text.trim(),
            )
          : await notifier.update(
              id: spesifikasi.idSpesifikasi,
              namaSpesifikasi: nama.text.trim(),
              tipeInput: tipe,
              satuan: satuan.text.trim().isEmpty ? null : satuan.text.trim(),
              opsi: opsi.text.trim().isEmpty ? null : opsi.text.trim(),
            );
      if (mounted) _pesan(context, ok, 'Item checklist tersimpan.');
    }

    nama.dispose();
    satuan.dispose();
    opsi.dispose();
  }

  Future<void> _hapus(int idKategori, Spesifikasi s) async {
    final bool ok = await _konfirmasiHapus(
      context,
      'Hapus item "${s.namaSpesifikasi}"?',
      'Item ini akan hilang dari form pemeliharaan kategori terkait.',
    );
    if (!ok || !mounted) return;
    final bool hasil = await ref
        .read(masterSpesifikasiProvider(idKategori).notifier)
        .delete(s.idSpesifikasi);
    if (mounted) _pesan(context, hasil, 'Item checklist dihapus.');
  }
}

// ---------------------------------------------------------------------------
// Bagian bersama
// ---------------------------------------------------------------------------

/// Kerangka satu tab master data: tombol tambah, keadaan loading/error/kosong,
/// lalu daftar. Menjaga ketiga tab tampil konsisten.
class _KerangkaTab extends StatelessWidget {
  const _KerangkaTab({
    required this.labelTambah,
    required this.onTambah,
    required this.onRetry,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.kosongJudul,
    required this.kosongPesan,
    required this.children,
  });

  final String labelTambah;
  final VoidCallback onTambah;
  final VoidCallback onRetry;
  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final String kosongJudul;
  final String kosongPesan;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTambah,
              icon: const Icon(Icons.add, size: AppSizes.iconSm),
              label: Text(labelTambah),
            ),
          ),
        ),
        Expanded(child: _isi(context)),
      ],
    );
  }

  Widget _isi(BuildContext context) {
    if (isLoading && children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            SkeletonListTile(),
            SkeletonListTile(),
            SkeletonListTile(),
          ],
        ),
      );
    }

    if (error != null && children.isEmpty) {
      return ErrorView(message: error!, onRetry: onRetry);
    }

    if (isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: kosongJudul,
        message: kosongPesan,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: children,
      ),
    );
  }
}

class _BarisData extends StatelessWidget {
  const _BarisData({
    required this.judul,
    required this.keterangan,
    required this.onEdit,
    required this.onDelete,
    this.ikon,
    this.ikonAsset,
    this.badge,
  });

  final String judul;
  final String keterangan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final IconData? ikon;
  final String? ikonAsset;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: <Widget>[
            if (ikonAsset != null)
              Image.asset(ikonAsset!, width: 34, height: 34, fit: BoxFit.contain)
            else
              Icon(
                ikon ?? Icons.circle,
                color: AppColors.primary,
                size: AppSizes.iconMd,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    keterangan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...<Widget>[
              StatusBadge(
                label: badge!,
                color: AppColors.roleAdmin,
                softColor: AppColors.roleAdminSoft,
                dense: true,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            IconButton(
              tooltip: 'Ubah',
              icon: const Icon(
                Icons.edit_outlined,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(
                Icons.delete_outline,
                size: AppSizes.iconSm,
                color: AppColors.statusDanger,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog form master data. Mengembalikan `true` bila pengguna menekan SIMPAN.
Future<bool> _dialogForm(
  BuildContext context, {
  required String judul,
  required List<Widget> fields,
}) async {
  final bool? hasil = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(judul),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('BATAL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('SIMPAN'),
        ),
      ],
    ),
  );
  return hasil ?? false;
}

/// Dialog konfirmasi hapus. Mengembalikan `true` bila disetujui.
Future<bool> _konfirmasiHapus(
  BuildContext context,
  String judul,
  String pesan,
) async {
  final bool? ya = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(judul),
      content: Text(pesan),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('BATAL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('HAPUS'),
        ),
      ],
    ),
  );
  return ya ?? false;
}

/// Snackbar hasil mutasi master data.
void _pesan(BuildContext context, bool ok, String sukses) {
  AppSnackbar.show(
    context,
    ok ? sukses : 'Gagal menyimpan. Periksa data dan koneksi.',
    type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
  );
}
