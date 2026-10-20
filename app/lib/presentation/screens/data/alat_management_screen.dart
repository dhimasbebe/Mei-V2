import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/files/file_delivery.dart';
import '../../../core/files/file_export_spec.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/api/api_exception.dart';
import '../../../domain/models/alat.dart';
import '../../../domain/models/kategori.dart';
import '../../../domain/models/lokasi.dart';
import '../../../providers/dashboard_provider.dart';
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

  /// Barcode yang sedang dicentang (WS N — cetak label QR massal).
  final Set<String> _dipilih = <String>{};

  /// Mode pilih aktif (dimulai lewat tekan-lama pada kartu).
  bool _modePilih = false;

  /// Permintaan label QR sedang berjalan — tombol dinonaktifkan.
  bool _sedangEkspor = false;

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
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _form(),
                      icon: const Icon(Icons.add, size: AppSizes.iconSm),
                      label: const Text(
                        'TAMBAH ALAT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.touchTarget),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.alatImpor),
                      icon: const Icon(
                        Icons.upload_file_outlined,
                        size: AppSizes.iconSm,
                      ),
                      label: const Text(
                        'IMPOR CSV',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, AppSizes.touchTarget),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_dipilih.isNotEmpty) _barAksi(state),
        Expanded(child: _isi(state)),
      ],
    );
  }

  /// Bar aksi kontekstual saat ada alat terpilih (WS N).
  Widget _barAksi(MasterListState<Alat> state) {
    final AppPalette pal = context.pal;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: pal.divider),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${_dipilih.length} alat dipilih',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: _sedangEkspor ? null : () => _pilihSemua(state.items),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Semua'),
          ),
          TextButton(
            onPressed: _sedangEkspor ? null : _batalPilih,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton.icon(
            onPressed: _sedangEkspor ? null : _cetakLabel,
            icon: const Icon(Icons.qr_code_2, size: AppSizes.iconSm),
            label: Text(
              _sedangEkspor ? 'MEMPROSES' : 'LABEL QR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
          ),
        ],
      ),
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
      onRefresh: _muatUlang,
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
          final bool dipilih = _dipilih.contains(a.barcodeAlat);

          final Widget kartu = AppCard(
            borderColor: dipilih ? AppColors.primary : null,
            onTap: _modePilih ? () => _togglePilih(a.barcodeAlat) : null,
            onLongPress: () => _mulaiPilih(a.barcodeAlat),
            child: Row(
              children: <Widget>[
                if (_modePilih)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Checkbox(
                      value: dipilih,
                      onChanged: (bool? v) => _togglePilih(a.barcodeAlat),
                      activeColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                Hero(
                  tag: 'alat-${a.barcodeAlat}',
                  child: ikon != null
                      ? Image.asset(
                          ikon,
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        )
                      : const Icon(Icons.build_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        a.barcodeAlat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                // Aksi per baris disembunyikan saat mode pilih agar tidak salah tekan.
                if (!_modePilih) ...<Widget>[
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
                    icon: const Icon(
                      Icons.delete_outline,
                      size: AppSizes.iconSm,
                      color: AppColors.statusDanger,
                    ),
                    onPressed: () => _hapus(a),
                  ),
                ],
              ],
            ),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            // Geser-untuk-hapus hanya di mode normal; mode pilih memakai ketuk.
            child: _modePilih
                ? kartu
                : SwipeActionWrapper(
                    layar: 'alat_management',
                    onAksi: (SwipeActionType aksi) {
                      if (aksi == SwipeActionType.hapus) {
                        _hapus(a);
                      }
                    },
                    child: kartu,
                  ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pilih banyak alat + cetak label QR (WS N)
  // ---------------------------------------------------------------------------

  /// Tekan lama pada kartu: masuk mode pilih dan centang alat tersebut.
  void _mulaiPilih(String barcode) {
    if (_sedangEkspor) return;
    setState(() {
      _modePilih = true;
      _dipilih.add(barcode);
    });
  }

  /// Ketuk kartu/checkbox saat mode pilih: tambah atau lepas centang.
  void _togglePilih(String barcode) {
    if (_sedangEkspor) return;
    setState(() {
      if (!_dipilih.remove(barcode)) {
        _dipilih.add(barcode);
      }
      // Tidak ada lagi yang tercentang → keluar mode pilih.
      if (_dipilih.isEmpty) {
        _modePilih = false;
      }
    });
  }

  /// "Semua" — centang seluruh alat yang sedang tampil.
  void _pilihSemua(List<Alat> items) {
    setState(() {
      _dipilih
        ..clear()
        ..addAll(items.map((Alat a) => a.barcodeAlat));
      _modePilih = _dipilih.isNotEmpty;
    });
  }

  /// "BATAL" — kosongkan pilihan dan keluar mode pilih.
  void _batalPilih() {
    setState(() {
      _dipilih.clear();
      _modePilih = false;
    });
  }

  /// Muat ulang daftar; pilihan dipertahankan tetapi barcode yang hilang dibuang.
  Future<void> _muatUlang() async {
    await ref.read(masterAlatProvider.notifier).refresh();
    if (!mounted) return;
    _sinkronPilihan();
  }

  /// Buang barcode terpilih yang sudah tidak ada di daftar terbaru.
  void _sinkronPilihan() {
    if (_dipilih.isEmpty) return;
    final Set<String> ada =
        ref.read(masterAlatProvider).items.map((Alat a) => a.barcodeAlat).toSet();
    if (_dipilih.every(ada.contains)) return;
    setState(() {
      _dipilih.removeWhere((String b) => !ada.contains(b));
      if (_dipilih.isEmpty) {
        _modePilih = false;
      }
    });
  }

  /// "LABEL QR" — minta PDF label dari backend lalu serahkan ke pengguna.
  Future<void> _cetakLabel() async {
    if (_sedangEkspor) return;
    if (_dipilih.isEmpty) {
      AppSnackbar.show(
        context,
        'Pilih minimal satu alat terlebih dahulu.',
        type: AppSnackbarType.gagal,
      );
      return;
    }

    final List<String> barcode = _dipilih.toList()..sort();
    setState(() => _sedangEkspor = true);

    try {
      final List<int> bytes =
          await ref.read(dashboardRepositoryProvider).exportQrLabels(barcode);
      if (!mounted) return;
      setState(() => _sedangEkspor = false);

      // Jangan pernah menyerahkan berkas yang bukan PDF (mis. halaman galat).
      if (!FileExportSpec.tampakPdf(bytes)) {
        AppSnackbar.show(
          context,
          'Berkas label QR tidak valid (bukan PDF). Coba lagi.',
          type: AppSnackbarType.gagal,
        );
        return;
      }

      final HasilPenyerahan hasil = await FileDelivery.bagikanBerkas(
        bytes: bytes,
        nama: FileExportSpec.namaLabelQr(),
        mime: 'application/pdf',
        judul: 'Label QR ${barcode.length} alat',
      );
      if (!mounted) return;
      if (hasil.berhasil) {
        AppSnackbar.show(
          context,
          'Label QR ${barcode.length} alat siap dibagikan.',
          type: AppSnackbarType.sukses,
        );
      } else {
        AppSnackbar.show(
          context,
          hasil.pesan ?? 'Label QR gagal dibagikan.',
          type: AppSnackbarType.gagal,
        );
      }
    } catch (e, st) {
      debugPrint('AlatManagementScreen._cetakLabel gagal: $st');
      if (!mounted) return;
      setState(() => _sedangEkspor = false);
      // 422 dari backend memuat daftar barcode tak dikenal — tampilkan apa adanya.
      final String pesan =
          e is ApiException ? e.message : 'Gagal membuat label QR.';
      AppSnackbar.show(context, pesan, type: AppSnackbarType.gagal);
    }
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
      // Alat yang sudah terhapus tidak boleh tertinggal di pilihan label QR.
      if (ok) _sinkronPilihan();
    }
  }
}
