import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';

/// Menu konteks tekan-lama untuk kartu alat (Tahap 3 — WS H, AC-H9).
///
/// Dipakai di tiga beranda: tekan lama pada kartu tugas/overdue menampilkan
/// pilihan **Salin barcode** dan **Lihat detail**. Aksi dibatasi pada dua
/// pilihan tersebut agar tidak ada operasi merusak dari daftar beranda.
Future<void> tampilkanMenuKonteksAlat(
  BuildContext context, {
  required String barcode,
  VoidCallback? onDetail,
}) {
  final AppPalette pal = context.pal;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: pal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.qr_code_2, size: AppSizes.iconMd, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      barcode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: pal.borderSubtle),
            ListTile(
              leading: Icon(Icons.copy_all_outlined, color: pal.textSecondary),
              title: Text(
                'Salin barcode',
                style: TextStyle(fontSize: 14, color: pal.textPrimary),
              ),
              onTap: () async {
                final NavigatorState nav = Navigator.of(ctx);
                await Clipboard.setData(ClipboardData(text: barcode));
                nav.pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Barcode $barcode disalin.')),
                );
              },
            ),
            if (onDetail != null)
              ListTile(
                leading: Icon(Icons.open_in_new, color: pal.textSecondary),
                title: Text(
                  'Lihat detail',
                  style: TextStyle(fontSize: 14, color: pal.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDetail();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
