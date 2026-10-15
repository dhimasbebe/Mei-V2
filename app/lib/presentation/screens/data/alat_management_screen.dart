import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/alat.dart';
import '../../../domain/models/kategori.dart';
import '../../../domain/models/lokasi.dart';
import '../../../providers/master_data_provider.dart';
import '../../widgets/swipe_action_wrapper.dart';
import '../../../core/gesture/swipe_action.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../../core/theme/app_palette.dart';

/// Manajemen Alat (Admin) — daftar alat beserta barcode, kategori, dan lokasi.
class AlatManagementScreen extends ConsumerStatefulWidget {
  const AlatManagementScreen({super.key});

  @override
  ConsumerState<AlatManagementScreen> createState() =>
      _AlatManagementScreenState();
}

class _AlatManagementScreenState extends ConsumerState<AlatManagementScreen> {
  final TextEditingController _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(masterAlatProvider.notifier).load();
      ref.read(masterKategoriProvider.notifier).load();
      ref.read(masterLokasiProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MasterListState<Alat> state = ref.watch(masterAlatProvider);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: _cari,
                hint: 'Cari barcode atau merk...',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                onSubmitted: (String v) =>
                    ref.read(masterAlatProvider.notifier).load(query: v),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _form(),
                  icon: Icon(Icons.add, size: AppSizes.iconSm),
                  label: Text('TAMBAH ALAT'),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _isi(state)),
      ],
    );
  }

  Widget _isi(MasterListState<Alat> state) {
    if (state.isLoading && state.items.isEmpty) {
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

    if (state.error != null && state.items.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(masterAlatProvider.notifier).load(),
      );
    }

    if (state.isEmpty) {
      return const EmptyState(
        icon: Icons.qr_code_2,
        title: 'Belum ada alat',
        message: 'Tambahkan alat beserta barcode-nya agar bisa dipindai teknisi.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(masterAlatProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: state.items.length,
        itemBuilder: (BuildContext context, int i) {
          final Alat a = state.items[i];
          final String? ikon = AppStrings.kategoriIcon[a.namaKategori];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SwipeActionWrapper(
              layar: 'alat_management',
              onAksi: (SwipeActionType aksi) {
                if (aksi == SwipeActionType.hapus) {
                  _hapus(a);
                }
              },
              child: AppCard(
              child: Row(
                children: <Widget>[
                  if (ikon != null)
                    Image.asset(ikon, width: 34, height: 34, fit: BoxFit.contain)
                  else
                    Icon(Icons.build_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          a.barcodeAlat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.merkAlat} • ${a.namaKategori ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.pal.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        StatusBadge(
                          label: a.detailLokasi,
                          color: AppColors.roleSupervisor,
                          softColor: AppColors.roleSupervisorSoft,
                          icon: Icons.location_on_outlined,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ubah',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: AppSizes.iconSm,
                      color: context.pal.textSecondary,
                    ),
                    onPressed: () => _form(alat: a),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: Icon(
                      Icons.delete_outline,
                      size: AppSizes.iconSm,
                      color: AppColors.statusDanger,
                    ),
                    onPressed: () => _hapus(a),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _form({Alat? alat}) async {
    final List<Kategori> kategori = ref.read(masterKategoriProvider).items;
    final List<Lokasi> lokasi = ref.read(masterLokasiProvider).items;

    if (kategori.isEmpty) {
      AppSnackbar.show(
        context,
        'Tambahkan kategori terlebih dahulu di Master Data.',
        type: AppSnackbarType.gagal,
      );
      return;
    }

    final TextEditingController barcode =
        TextEditingController(text: alat?.barcodeAlat ?? '');
    final TextEditingController merk =
        TextEditingController(text: alat?.merkAlat ?? '');
    int idKategori = alat?.idKategori ?? kategori.first.idKategori;
    int? idLokasi = alat?.idLokasi;

    final bool simpan = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
              title: Text(alat == null ? 'Tambah alat' : 'Ubah alat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppTextField(
                      controller: barcode,
                      label: 'Barcode alat',
                      hint: 'mis. AC-001',
                      readOnly: alat != null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(controller: merk, label: 'Merk alat'),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<int>(
                      initialValue: idKategori,
                      decoration: InputDecoration(labelText: 'Kategori'),
                      items: kategori
                          .map(
                            (Kategori k) => DropdownMenuItem<int>(
                              value: k.idKategori,
                              child: Text(k.nama),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) =>
                          setLocal(() => idKategori = v ?? idKategori),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<int?>(
                      initialValue: idLokasi,
                      decoration: InputDecoration(labelText: 'Lokasi'),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('- belum ditentukan -'),
                        ),
                        ...lokasi.map(
                          (Lokasi l) => DropdownMenuItem<int?>(
                            value: l.idLokasi,
                            child: Text(l.label),
                          ),
                        ),
                      ],
                      onChanged: (int? v) => setLocal(() => idLokasi = v),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('BATAL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('SIMPAN'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (simpan && mounted) {
      final MasterAlatNotifier notifier = ref.read(masterAlatProvider.notifier);
      final bool ok = alat == null
          ? await notifier.create(
              barcodeAlat: barcode.text.trim(),
              merkAlat: merk.text.trim(),
              idKategori: idKategori,
              idLokasi: idLokasi,
            )
          : await notifier.update(
              barcode: alat.barcodeAlat,
              merkAlat: merk.text.trim(),
              idKategori: idKategori,
              idLokasi: idLokasi,
            );
      if (mounted) {
        AppSnackbar.show(
          context,
          ok ? 'Alat tersimpan.' : (ref.read(masterAlatProvider).error ?? 'Gagal menyimpan.'),
          type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
        );
      }
    }

    barcode.dispose();
    merk.dispose();
  }

  Future<void> _hapus(Alat a) async {
    final bool ya = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text('Hapus alat?'),
            content: Text(
              'Alat ${a.barcodeAlat} (${a.merkAlat}) akan dihapus permanen.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('BATAL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('HAPUS'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ya || !mounted) return;
    final bool ok = await ref.read(masterAlatProvider.notifier).delete(a.barcodeAlat);
    if (mounted) {
      AppSnackbar.show(
        context,
        ok ? 'Alat dihapus.' : (ref.read(masterAlatProvider).error ?? 'Gagal menghapus.'),
        type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
      );
    }
  }
}
