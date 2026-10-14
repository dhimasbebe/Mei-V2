import '../../domain/models/dashboard.dart';
import '../../domain/models/user.dart';
import '../api/api_service.dart';

/// Repository manajemen user (Admin). Tipis: hanya memanggil [ApiService].
class UserRepository {
  const UserRepository({ApiService? api}) : _api = api ?? const ApiService();

  final ApiService _api;

  Future<PagedResult<User>> list({
    String? q,
    String? role,
    int page = 1,
    int perPage = 20,
  }) =>
      _api.getUsers(q: q, role: role, page: page, perPage: perPage);

  Future<User> create({
    required String username,
    required String namaUsers,
    required String roleUsers,
    String? emailUsers,
    required String password,
  }) =>
      _api.createUser(
        username: username,
        namaUsers: namaUsers,
        roleUsers: roleUsers,
        emailUsers: emailUsers,
        password: password,
      );

  Future<User> update({
    required String username,
    String? namaUsers,
    String? roleUsers,
    String? emailUsers,
    String? password,
  }) =>
      _api.updateUser(
        username: username,
        namaUsers: namaUsers,
        roleUsers: roleUsers,
        emailUsers: emailUsers,
        password: password,
      );

  Future<void> remove(String username) => _api.deleteUser(username);

  Future<void> resetPassword({required String username, String? password}) =>
      _api.resetPassword(username: username, password: password);
}
