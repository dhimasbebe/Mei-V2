import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/press_button.dart';
import '../../widgets/role_badge.dart';
import '../../../core/theme/app_palette.dart';

/// Layar login Mei-V2 (PRD §6).
///
/// Hierarki: logo Mei-V 60px → tagline → form (NIP, password dengan toggle
/// mata, dropdown role) → tombol MASUK → footer ko-branding Telkom Property.
/// Dropdown role hanya disambiguasi UX; backend tetap sumber kebenaran. Bila
/// role terpilih tidak cocok, sesi dibatalkan (lihat [AuthNotifier.login]).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nipCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Role terpilih; null = belum ada seleksi (default sesuai PRD §6.2).
  String? _role;
  bool _obscure = true;

  /// Banner error disembunyikan lokal saat pengguna mengubah input.
  bool _dismissError = false;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppDurations.splash,
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: AppCurves.standard,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: AppCurves.standard));

  @override
  void dispose() {
    _anim.dispose();
    _nipCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authProvider.notifier)
        .login(_nipCtrl.text.trim(), _passCtrl.text, _role!);
  }

  /// Sembunyikan banner error saat input berubah (PRD §6.3).
  void _onInputChanged(String _) {
    if (ref.read(authProvider).error != null && !_dismissError) {
      setState(() => _dismissError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);

    // Reaksi terhadap error baru: tampilkan banner; bila error = role tidak
    // cocok, reset dropdown role (PRD §6.2).
    ref.listen<AuthState>(authProvider, (AuthState? prev, AuthState next) {
      if (next.error != null && next.error != prev?.error) {
        setState(() {
          _dismissError = false;
          if (next.error == AppStrings.msgRoleTidakCocok) _role = null;
        });
      }
    });

    final bool enabled = !auth.isLoading;
    final String? err = auth.error;
    final bool showError = err != null && !_dismissError;

    return AppScaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    // Logo Mei-V kompak (AC-01): tinggi 60px, contain, center.
                    Center(
                      child: Image.asset(
                        AppStrings.logoBlack,
                        height: AppSizes.logoLogin,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      controller: _nipCtrl,
                      label: AppStrings.labelNip,
                      hint: AppStrings.hintNip,
                      keyboardType: TextInputType.number,
                      enabled: enabled,
                      onChanged: _onInputChanged,
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty)
                              ? AppStrings.msgNipKosong
                              : null,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _passCtrl,
                      label: AppStrings.labelPassword,
                      hint: AppStrings.hintPassword,
                      obscure: _obscure,
                      enabled: enabled,
                      onChanged: _onInputChanged,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Lihat password'
                            : 'Sembunyikan password',
                        onPressed: enabled
                            ? () => setState(() => _obscure = !_obscure)
                            : null,
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.pal.textSecondary,
                        ),
                      ),
                      validator: (String? v) => (v == null || v.length < 4)
                          ? AppStrings.msgPasswordMinimal
                          : null,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                        ),
                        filled: true,
                        fillColor: context.pal.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: context.pal.divider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: context.pal.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      hint: Text(
                        AppStrings.hintPilihRole,
                        style: TextStyle(color: context.pal.textSecondary),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final String r in AppStrings.roles)
                          DropdownMenuItem<String>(
                            value: r,
                            child: Text(r),
                          ),
                      ],
                      onChanged: enabled
                          ? (String? v) => setState(() {
                                _role = v;
                                _dismissError = false;
                              })
                          : null,
                      validator: (String? v) =>
                          (v == null || v.isEmpty)
                              ? AppStrings.msgRoleWajib
                              : null,
                    ),
                    if (_role != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Center(child: RoleBadge(role: _role!)),
                    ],
                    if (showError) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _ErrorBanner(message: err),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PressButton(
                      label: AppStrings.labelMasuk,
                      isLoading: auth.isLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Footer ko-branding (AC-02): pemisah, logo Telkom
                    // Property 32px, nama instansi, versi aplikasi.
                    Divider(color: context.pal.divider, height: 1),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Image.asset(
                        AppStrings.logoTelkomProperty,
                        height: AppSizes.logoTelproLogin,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.telkomPropertySurabayaUtara,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      AppStrings.appVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner error server: latar merah muda, ikon + pesan.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.verifikasiDitolakSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.statusDanger.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            color: AppColors.statusDanger,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.statusDanger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
