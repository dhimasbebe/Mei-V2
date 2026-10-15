import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_palette.dart';

/// W6 — Chip peran berwarna (AC-43).
///
/// Memetakan nama peran ke warna [AppColors] yang tidak bersaing dengan merah
/// brand. [size] adalah tinggi chip (default 26). [outlined] menampilkan varian
/// garis tepi tanpa latar; [showIcon] menampilkan ikon peran.
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.size,
    this.showIcon = true,
    this.outlined = false,
  });

  final String role;
  final double? size;
  final bool showIcon;
  final bool outlined;

  static Color _solid(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return AppColors.roleAdmin;
      case 'supervisor':
        return AppColors.roleSupervisor;
      case 'teknisi':
        return AppColors.roleTeknisi;
      default:
        return AppColors.statusUnknown;
    }
  }

  static Color _soft(String role, AppPalette pal) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return AppColors.roleAdminSoft;
      case 'supervisor':
        return AppColors.roleSupervisorSoft;
      case 'teknisi':
        return AppColors.roleTeknisiSoft;
      default:
        return pal.surfaceMuted;
    }
  }

  static IconData _icon(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'supervisor':
        return Icons.verified_user_outlined;
      case 'teknisi':
        return Icons.engineering_outlined;
      default:
        return Icons.person_outline;
    }
  }

  static String _label(String role) {
    final String r = role.trim();
    if (r.isEmpty) return '-';
    return r[0].toUpperCase() + r.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final Color solid = _solid(role);
    final Color soft = _soft(role, context.pal);
    final double h = size ?? 26;
    final double fontSize = h * 0.46;
    final double iconSize = h * 0.62;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: h * 0.4),
      decoration: BoxDecoration(
        color: outlined ? null : soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: outlined ? Border.all(color: solid, width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(_icon(role), size: iconSize, color: solid),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            _label(role),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: solid,
            ),
          ),
        ],
      ),
    );
  }
}
