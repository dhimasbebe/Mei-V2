import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_strings.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/models/user.dart';

/// Instance global repository (bisa di-override saat testing).
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// State auth: idle → loading → authenticated / unauthenticated.
@immutable
class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});
  final User? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? error, bool clearError = false}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final User? user = await _repo.getCurrentUser();
    state = state.copyWith(isLoading: false, user: user ?? state.user);
  }

  /// Login dengan NIP + password + [role] yang dipilih pengguna.
  ///
  /// [role] hanya disambiguasi UX; server tetap sumber kebenaran. Setelah
  /// autentikasi berhasil, role terpilih WAJIB cocok dengan `user.roleUsers`.
  /// Bila tidak cocok, sesi dibatalkan (logout) dan state kembali tanpa user
  /// dengan pesan [AppStrings.msgRoleTidakCocok] (AC-05).
  Future<void> login(String username, String password, String role) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final User user = await _repo.login(
        username: username,
        password: password,
        role: role,
      );
      final bool cocok =
          user.roleUsers.trim().toLowerCase() == role.trim().toLowerCase();
      if (!cocok) {
        await _repo.logout();
        state = const AuthState(error: AppStrings.msgRoleTidakCocok);
        return;
      }
      state = state.copyWith(isLoading: false, user: user, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Login gagal.',
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repo.logout();
    state = const AuthState();
  }

  Future<void> refresh() async {
    final User? user = await _repo.refreshUser();
    if (user != null) state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Stream provider untuk reaktifitas login/logout (bisa dipakai router).
final authStreamProvider = StreamProvider<AuthState>((ref) {
  return Stream<AuthState>.periodic(const Duration(seconds: 1), (_) => ref.read(authProvider))
      .distinct();
});
