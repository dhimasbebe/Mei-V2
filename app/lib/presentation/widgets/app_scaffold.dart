import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';

/// Scaffold konsisten: AppBar hitam (home) atau merah (detail), dengan logo putih.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.leading,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.useRedAppBar = false,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool useRedAppBar;

  @override
  Widget build(BuildContext context) {
    final bool isHome = title == null && !useRedAppBar;
    final Color appBarColor = useRedAppBar ? AppColors.primary : AppColors.black;

    return Scaffold(
      backgroundColor: backgroundColor ?? context.pal.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: leading,
        title: isHome
            ? Image.asset('assets/logos/logoputih.png', height: AppSizes.logoAppBar)
            : Text(title ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
