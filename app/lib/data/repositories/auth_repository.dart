import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/models/user.dart';
import '../api/api_service.dart';

/// Key storage untuk token dan user.
const String _kToken = 'meiv_auth_token';
const String _kUser = 'meiv_auth_user';

/// Repository autentikasi dengan persistensi lokal (SecureStorage).
class AuthRepository {
  AuthRepository({ApiService? api, FlutterSecureStorage? storage})
      : _api = api ?? const ApiService(),
        _storage = storage ?? const FlutterSecureStorage();

  final ApiService _api;
  final FlutterSecureStorage _storage;

  User? _cachedUser;

  /// Login → simpan token + user secara lokal.
  ///
  /// [role] hanya disambiguasi UX (dropdown role di layar login); server tetap
  /// sumber kebenaran. Opsional agar pemanggil lama tidak putus.
  Future<User> login({
    required String username,
    required String password,
    String? role,
  }) async {
    final User user =
        await _api.login(username: username, password: password, role: role);
    _cachedUser = user;
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
    return user;
  }

  /// Ganti password milik sendiri.
  Future<void> changePassword({
    required String passwordLama,
    required String passwordBaru,
  }) =>
      _api.changePassword(passwordLama: passwordLama, passwordBaru: passwordBaru);

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Abaikan error network saat logout.
    } finally {
      _cachedUser = null;
      await _storage.delete(key: _kToken);
      await _storage.delete(key: _kUser);
    }
  }

  /// Ambil user dari cache / storage. Null bila belum login.
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    final String? raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final User user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _cachedUser = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Cek apakah ada sesi aktif (token tersimpan).
  Future<bool> get isLoggedIn async {
    final String? token = await _storage.read(key: _kToken);
    return token != null && token.isNotEmpty;
  }

  /// Refresh profil user dari server.
  Future<User?> refreshUser() async {
    try {
      final User user = await _api.getMe();
      _cachedUser = user;
      await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      return null;
    }
  }
}
