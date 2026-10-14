/// Pengguna Mei-V. Padanan tabel `users` pada sistem lama.
///
/// Kolom asli: username (NIP), nama_users, role_users, email_users.
class User {
  const User({
    required this.username,
    required this.namaUsers,
    required this.roleUsers,
    this.emailUsers,
    this.jumlahMaintenance,
  });

  final String username; // NIP
  final String namaUsers;
  final String roleUsers; // 'Admin' | 'Teknisi' | 'Supervisor'
  final String? emailUsers;

  /// Jumlah maintenance yang pernah dilakukan (kolom baca-saja `GET /users`).
  final int? jumlahMaintenance;

  bool get isAdmin => roleUsers.toLowerCase() == 'admin';
  bool get isTeknisi => roleUsers.toLowerCase() == 'teknisi';
  bool get isSupervisor => roleUsers.toLowerCase() == 'supervisor';

  /// Role dikenal (salah satu dari tiga peran resmi).
  bool get roleDikenal => isAdmin || isTeknisi || isSupervisor;

  /// Role siap tampil pada badge (kapital di awal, fallback ke nilai mentah).
  String get roleTampil {
    final String r = roleUsers.trim();
    if (r.isEmpty) return '-';
    return r[0].toUpperCase() + r.substring(1).toLowerCase();
  }

  /// Inisial untuk avatar profil (aplikasi lama menampilkan nama + role).
  String get inisial {
    final List<String> parts =
        namaUsers.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: (json['username'] ?? '') as String,
      namaUsers: (json['nama_users'] ?? json['namaUsers'] ?? '') as String,
      roleUsers: (json['role_users'] ?? json['roleUsers'] ?? '') as String,
      emailUsers: json['email_users'] as String?,
      jumlahMaintenance: json['jumlah_maintenance'] == null
          ? null
          : int.tryParse('${json['jumlah_maintenance']}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        'nama_users': namaUsers,
        'role_users': roleUsers,
        'email_users': emailUsers,
        'jumlah_maintenance': jumlahMaintenance,
      };
}
