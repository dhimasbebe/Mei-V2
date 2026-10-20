import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/search/search_history.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import 'app_text_field.dart';

/// Kunci `SharedPreferences` riwayat kueri pencarian (Tahap 3 — WS H).
const String kSearchHistoryKey = 'meiv.search_history';

/// Kotak pencarian + chip riwayat kueri terakhir.
///
/// Riwayat dikelola modul **Dart murni** [SearchHistory] (kapasitas 10,
/// dedupe ke depan — AC-H4/H5); widget ini hanya menyediakan tampilan dan
/// persistensi `shared_preferences`.
class SearchHistoryField extends StatefulWidget {
  const SearchHistoryField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// Dipanggil saat pengguna menekan enter atau memilih chip riwayat.
  final ValueChanged<String> onSubmitted;
  final String? hint;
  final Widget? prefixIcon;
  final bool enabled;

  @override
  State<SearchHistoryField> createState() => _SearchHistoryFieldState();
}

class _SearchHistoryFieldState extends State<SearchHistoryField> {
  SearchHistory _riwayat = SearchHistory();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(kSearchHistoryKey) ?? <String>[];
      final SearchHistory h = SearchHistory.deserialize(raw);
      if (!mounted) return;
      setState(() => _riwayat = h);
    } catch (_) {
      // Penyimpanan tidak tersedia: pencarian tetap berfungsi tanpa riwayat.
    }
  }

  Future<void> _simpan() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kSearchHistoryKey, _riwayat.serialize());
    } catch (_) {
      // Diabaikan: riwayat hanya kenyamanan, bukan data pokok.
    }
  }

  void _catat(String q) {
    _riwayat.add(q);
    setState(() {});
    _simpan();
  }

  void _pilih(String q) {
    widget.controller.text = q;
    widget.controller.selection = TextSelection.collapsed(offset: q.length);
    _catat(q);
    widget.onSubmitted(q);
  }

  Future<void> _bersihkan() async {
    _riwayat.clear();
    setState(() {});
    await _simpan();
  }

  /// AC-H10: hapus satu entri tanpa mengorbankan seluruh riwayat.
  Future<void> _hapus(String q) async {
    _riwayat.remove(q);
    setState(() {});
    await _simpan();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette pal = context.pal;
    final List<String> items = _riwayat.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: widget.controller,
          hint: widget.hint,
          prefixIcon: widget.prefixIcon,
          enabled: widget.enabled,
          onSubmitted: (String q) {
            _catat(q);
            widget.onSubmitted(q);
          },
        ),
        if (items.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(Icons.history, size: 14, color: pal.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Pencarian terakhir',
                style: TextStyle(fontSize: 11, color: pal.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed: _bersihkan,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: Text(
                  'Hapus semua',
                  style: TextStyle(fontSize: 11, color: pal.textSecondary),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String q in items)
                // InputChip (bukan ActionChip) agar tiap entri punya tombol
                // hapus sendiri — AC-H10.
                InputChip(
                  label: Text(q),
                  labelStyle: TextStyle(fontSize: 11, color: pal.textPrimary),
                  backgroundColor: pal.surfaceMuted,
                  side: BorderSide(color: pal.borderSubtle),
                  onPressed: () => _pilih(q),
                  onDeleted: () => _hapus(q),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  deleteIconColor: pal.textSecondary,
                  deleteButtonTooltipMessage: 'Hapus "$q" dari riwayat',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
