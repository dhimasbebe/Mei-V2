import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/models/user.dart';
import '../../../providers/user_provider.dart';
import '../../widgets/swipe_action_wrapper.dart';
import '../../../core/gesture/swipe_action.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/press_button.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/skeleton.dart';
import '../../../core/theme/app_palette.dart';

/// Manajemen User (Admin) — daftar akun, pencarian, filter role, CRUD.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _cari = TextEditingController();

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserListState state = ref.watch(userListProvider);

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
                hint: 'Cari nama atau NIP...',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                onSubmitted: (String v) =>
                    ref.read(userListProvider.notifier).search(v),
              ),
              const SizedBox(height: AppSpacing.md),
              FilterChipBar(
                items: const <String>['Semua', 'Admin', 'Supervisor', 'Teknisi'],
                selected: <String>[
                  state.roleFilter ?? 'Semua',
                ],
                multi: false,
                onChanged: (List<String> pilih) {
                  final String v = pilih.isEmpty ? 'Semua' : pilih.last;
                  ref
                      .read(userListProvider.notifier)
                      .filterByRole(v == 'Semua' ? null : v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              PressButton(
                label: 'TAMBAH USER',
                icon: Icon(Icons.person_add_alt, size: AppSizes.iconSm),
                onPressed: () => _form(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _Isi(
            state: state,
            onEdit: (User u) => _form(user: u),
            onDelete: _hapus,
          ),
        ),
      ],
    );
  }

  Future<void> _form({User? user}) async {
    final TextEditingController nip = TextEditingController(text: user?.username ?? '');
    final TextEditingController nama = TextEditingController(text: user?.namaUsers ?? '');
    final TextEditingController email = TextEditingController(text: user?.emailUsers ?? '');
    final TextEditingController sandi = TextEditingController();
    String role = user?.roleUsers ?? 'Teknisi';
    String? pesanError;

    final bool? simpan = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(user == null ? 'Tambah user' : 'Ubah user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppTextField(
                  controller: nip,
                  label: 'NIP',
                  hint: 'mis. 67891',
                  readOnly: user != null,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: nama, label: 'Nama lengkap'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: email, label: 'Email (opsional)'),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(labelText: 'Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'Admin', child: Text('Admin')),
                    DropdownMenuItem<String>(
                      value: 'Supervisor',
                      child: Text('Supervisor'),
                    ),
                    DropdownMenuItem<String>(value: 'Teknisi', child: Text('Teknisi')),
                  ],
                  onChanged: (String? v) =>
                      setLocal(() => role = v ?? role),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: sandi,
                  label: user == null ? 'Password' : 'Password baru (opsional)',
                  obscure: true,
                ),
                if (pesanError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    pesanError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.statusDanger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('BATAL'),
            ),
            TextButton(
              onPressed: () {
                if (nip.text.trim().isEmpty || nama.text.trim().isEmpty) {
                  setLocal(() => pesanError = 'NIP dan nama wajib diisi.');
                  return;
                }
                if (user == null && sandi.text.length < 6) {
                  setLocal(
                    () => pesanError = 'Password minimal 6 karakter.',
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );

    if (simpan ?? false) {
      final UserListNotifier notifier = ref.read(userListProvider.notifier);
      final bool ok = user == null
          ? await notifier.create(
              username: nip.text.trim(),
              namaUsers: nama.text.trim(),
              roleUsers: role,
              emailUsers: email.text.trim().isEmpty ? null : email.text.trim(),
              password: sandi.text,
            )
          : await notifier.update(
              username: user.username,
              namaUsers: nama.text.trim(),
              roleUsers: role,
              emailUsers: email.text.trim().isEmpty ? null : email.text.trim(),
              password: sandi.text.isEmpty ? null : sandi.text,
            );
      if (mounted) {
        AppSnackbar.show(
          context,
          ok ? 'Data user tersimpan.' : (ref.read(userListProvider).error ?? 'Gagal menyimpan.'),
          type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
        );
      }
    }

    nip.dispose();
    nama.dispose();
    email.dispose();
    sandi.dispose();
  }

  Future<void> _hapus(User user) async {
    final bool? ya = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Hapus user?'),
        content: Text(
          'Akun ${user.namaUsers} (${user.username}) akan dihapus permanen. '
          'Tindakan ini tidak dapat dibatalkan.',
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
    );
    if (!(ya ?? false)) return;
    final bool ok = await ref.read(userListProvider.notifier).remove(user.username);
    if (mounted) {
      AppSnackbar.show(
        context,
        ok ? 'User dihapus.' : (ref.read(userListProvider).error ?? 'Gagal menghapus.'),
        type: ok ? AppSnackbarType.sukses : AppSnackbarType.gagal,
      );
    }
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  final UserListState state;
  final ValueChanged<User> onEdit;
  final Future<void> Function(User) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.data == null) {
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

    if (state.error != null && state.data == null) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(userListProvider.notifier).load(),
      );
    }

    if (state.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: state.hasFilter ? 'Tidak ada hasil' : 'Belum ada user',
        message: state.hasFilter
            ? 'Coba kata kunci atau filter role lain.'
            : 'Tambahkan akun pertama lewat tombol TAMBAH USER.',
      );
    }

    final List<User> users = state.data!.data;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(userListProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: users.length,
        itemBuilder: (BuildContext context, int i) {
          final User u = users[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SwipeActionWrapper(
              layar: 'user_management',
              onAksi: (SwipeActionType aksi) {
                if (aksi == SwipeActionType.hapus) {
                  onDelete(u);
                }
              },
              child: AppCard(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      u.inisial,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          u.namaUsers,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${u.username}${u.emailUsers == null ? '' : ' • ${u.emailUsers}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.pal.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        RoleBadge(role: u.roleUsers, size: 22),
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
                    onPressed: () => onEdit(u),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: Icon(
                      Icons.delete_outline,
                      size: AppSizes.iconSm,
                      color: AppColors.statusDanger,
                    ),
                    onPressed: () => onDelete(u),
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
}
