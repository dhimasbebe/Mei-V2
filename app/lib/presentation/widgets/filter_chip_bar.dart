import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';

/// W10 — Bar chip filter (kategori/lokasi/tanggal/teknisi, AC-38).
///
/// [multi] `false` = pilih tunggal (selalu satu terpilih); `true` = banyak
/// pilihan. [onChanged] menerima daftar item terpilih yang baru.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    this.selected = const <String>[],
    this.onChanged,
    this.multi = false,
    this.labelBuilder,
  });

  final List<String> items;
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;
  final bool multi;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(labelBuilder?.call(item) ?? item),
                selected: selected.contains(item),
                showCheckmark: false,
                onSelected: onChanged == null
                    ? null
                    : (bool value) {
                        if (multi) {
                          final List<String> next =
                              List<String>.from(selected);
                          if (value) {
                            if (!next.contains(item)) next.add(item);
                          } else {
                            next.remove(item);
                          }
                          onChanged!(next);
                        } else {
                          onChanged!(value ? <String>[item] : <String>[]);
                        }
                      },
              ),
            ),
        ],
      ),
    );
  }
}

/// Panel filter: kartu berjudul dengan isi widget (biasanya [FilterChipBar])
/// dan aksi reset opsional di kanan judul.
class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    this.title,
    this.children = const <Widget>[],
    this.onReset,
    this.resetLabel = 'Reset',
  });

  final String? title;
  final List<Widget> children;
  final VoidCallback? onReset;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null || onReset != null)
            Row(
              children: <Widget>[
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (onReset != null)
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, AppSizes.touchTarget),
                    ),
                    child: Text(resetLabel),
                  ),
              ],
            ),
          ...children,
        ],
      ),
    );
  }
}
