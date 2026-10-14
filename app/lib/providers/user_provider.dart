import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../domain/models/dashboard.dart';
import '../domain/models/user.dart';

/// Instance repository user (bisa di-override saat testing).
final userRepositoryProvider = Provider<UserRepository>((ref) => const UserRepository());

/// State layar Manajemen User: daftar + filter + status submit.
@immutable
class UserListState {
  const UserListState({
    this.data,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isLoadingMore = false,
    this.query = '',
    this.roleFilter,
    this.error,
  });

  final PagedResult<User>? data;
  final bool isLoading;
  final bool isSubmitting;
  final bool isLoadingMore;

  /// Kata kunci pencarian (NIP / nama).
  final String query;

  /// Filter role: null = semua, 'Admin' | 'Teknisi' | 'Supervisor'.
  final String? roleFilter;
  final String? error;

  List<User> get users => data?.data ?? const <User>[];
  bool get isEmpty => users.isEmpty;
  bool get hasNext => data?.hasNext ?? false;
  int get total => data?.total ?? 0;

  /// Ada pencarian/filter aktif → EmptyState memakai pesan berbeda.
  bool get hasFilter => query.trim().isNotEmpty || (roleFilter ?? '').isNotEmpty;

  UserListState copyWith({
    PagedResult<User>? data,
    bool? isLoading,
    bool? isSubmitting,
    bool? isLoadingMore,
    String? query,
    String? roleFilter,
    bool clearRoleFilter = false,
    String? error,
    bool clearError = false,
  }) {
    return UserListState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
      roleFilter: clearRoleFilter ? null : (roleFilter ?? this.roleFilter),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier Manajemen User (Admin).
class UserListNotifier extends StateNotifier<UserListState> {
  UserListNotifier(this._repo) : super(const UserListState()) {
    load();
  }

  final UserRepository _repo;

  /// Muat halaman pertama memakai [UserListState.query] + `roleFilter` aktif.
  Future<void> load({int page = 1, int perPage = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final PagedResult<User> result = await _repo.list(
        q: state.query.trim().isEmpty ? null : state.query.trim(),
        role: state.roleFilter,
        page: page,
        perPage: perPage,
      );
      state = state.copyWith(isLoading: false, data: result);
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      debugPrint('UserListNotifier.load gagal: $st');
    }
  }

  /// Ubah kata kunci pencarian lalu muat ulang dari halaman pertama.
  Future<void> search(String q) async {
    state = state.copyWith(query: q);
    await load();
  }

  /// Filter role (null = semua) lalu muat ulang.
  Future<void> filterByRole(String? role) async {
    state = state.copyWith(roleFilter: role, clearRoleFilter: role == null);
    await load();
  }

  /// Muat ulang dari halaman pertama (pull-to-refresh).
  Future<void> refresh() => load();

  /// Tambah halaman berikutnya (infinite scroll).
  Future<void> loadMore() async {
    final PagedResult<User>? current = state.data;
    if (current == null || !current.hasNext || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final PagedResult<User> next = await _repo.list(
        q: state.query.trim().isEmpty ? null : state.query.trim(),
        role: state.roleFilter,
        page: current.currentPage + 1,
        perPage: current.perPage,
      );
      state = state.copyWith(
        isLoadingMore: false,
        data: PagedResult<User>(
          data: <User>[...current.data, ...next.data],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
          perPage: next.perPage,
        ),
      );
    } catch (e, st) {
      state = state.copyWith(isLoadingMore: false, error: _pesan(e));
      debugPrint('UserListNotifier.loadMore gagal: $st');
    }
  }

  /// Buat user baru. `true` bila berhasil (daftar dimuat ulang).
  Future<bool> create({
    required String username,
    required String namaUsers,
    required String roleUsers,
    String? emailUsers,
    required String password,
  }) =>
      _mutasi(() => _repo.create(
            username: username,
            namaUsers: namaUsers,
            roleUsers: roleUsers,
            emailUsers: emailUsers,
            password: password,
          ));

  /// Ubah user. `true` bila berhasil.
  Future<bool> update({
    required String username,
    String? namaUsers,
    String? roleUsers,
    String? emailUsers,
    String? password,
  }) =>
      _mutasi(() => _repo.update(
            username: username,
            namaUsers: namaUsers,
            roleUsers: roleUsers,
            emailUsers: emailUsers,
            password: password,
          ));

  /// Hapus user. `true` bila berhasil.
  Future<bool> remove(String username) => _mutasi(() => _repo.remove(username));

  /// Reset password user. `true` bila berhasil.
  Future<bool> resetPassword({required String username, String? password}) =>
      _mutasi(() => _repo.resetPassword(username: username, password: password));

  /// Bersihkan pesan error (mis. setelah snackbar ditutup).
  void clearError() => state = state.copyWith(clearError: true);

  /// Jalankan aksi tulis, lalu muat ulang daftar bila berhasil.
  Future<bool> _mutasi(Future<void> Function() aksi) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await aksi();
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e, st) {
      state = state.copyWith(isSubmitting: false, error: _pesan(e));
      debugPrint('UserListNotifier mutasi gagal: $st');
      return false;
    }
  }

  String _pesan(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Terjadi kesalahan.';
}

final userListProvider =
    StateNotifierProvider<UserListNotifier, UserListState>((ref) {
  return UserListNotifier(ref.watch(userRepositoryProvider));
});
