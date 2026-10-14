/// Model log audit (Admin) — `GET /v1/audit-log`.
///
/// Kontrak JSON mengikuti `docs/DESIGN-ROLE-UI-V2.md` §6.5:
/// ```json
/// { "id_audit": 12, "actor_username": "12345", "aksi": "update",
///   "entitas": "alat", "entitas_id": "AC-001",
///   "detail": "{\"merk_alat\":\"Daikin 2PK\"}", "created_at": "2026-07-15 09:00:00" }
/// ```
library;

import 'dart:convert';

/// Satu baris `audit_log`. Padanan tabel M2.
class AuditLogEntry {
  const AuditLogEntry({
    required this.idAudit,
    required this.actorUsername,
    required this.aksi,
    required this.entitas,
    required this.entitasId,
    this.detail,
    this.ipAddress,
    this.createdAt,
  });

  final int idAudit;
  final String actorUsername;

  /// `'create'` | `'update'` | `'delete'` | `'verify'` | `'assign'` | `'login'`.
  final String aksi;

  /// `'users'` | `'alat'` | `'kategori'` | `'lokasi'` | `'spesifikasi'` | `'maintenance'`.
  final String entitas;
  final String entitasId;

  /// Detail mentah (JSON string dari server), mis. `{"merk_alat":"Daikin 2PK"}`.
  final String? detail;
  final String? ipAddress;
  final DateTime? createdAt;

  bool get isDelete => aksi.toLowerCase() == 'delete';
  bool get isCreate => aksi.toLowerCase() == 'create';
  bool get isUpdate => aksi.toLowerCase() == 'update';

  /// Tanggal + jam gaya aplikasi lama: "2026-07-15 09:00:00".
  String get waktuTampil {
    final DateTime? w = createdAt;
    if (w == null) return '-';
    String p(int v) => v.toString().padLeft(2, '0');
    return '${w.year}-${p(w.month)}-${p(w.day)} '
        '${p(w.hour)}:${p(w.minute)}:${p(w.second)}';
  }

  /// Detail yang sudah dirapikan untuk kolom tabel (bila JSON string).
  String get detailTampil {
    final String raw = (detail ?? '').trim();
    if (raw.isEmpty) return '-';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.entries
            .map((MapEntry<dynamic, dynamic> e) => '${e.key}=${e.value}')
            .join(', ');
      }
      if (decoded is List) {
        return decoded.map((dynamic e) => '$e').join(', ');
      }
      return '$decoded';
    } catch (_) {
      return raw;
    }
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final Object? waktu = json['created_at'] ?? json['createdAt'] ?? json['waktu'];
    return AuditLogEntry(
      idAudit: int.tryParse('${json['id_audit'] ?? json['idAudit'] ?? 0}') ?? 0,
      actorUsername:
          (json['actor_username'] ?? json['actorUsername'] ?? '') as String,
      aksi: (json['aksi'] ?? '') as String,
      entitas: (json['entitas'] ?? '') as String,
      entitasId: '${json['entitas_id'] ?? json['entitasId'] ?? ''}',
      detail: json['detail'] as String?,
      ipAddress: (json['ip_address'] ?? json['ipAddress']) as String?,
      createdAt: waktu == null ? null : DateTime.tryParse('$waktu'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_audit': idAudit,
        'actor_username': actorUsername,
        'aksi': aksi,
        'entitas': entitas,
        'entitas_id': entitasId,
        'detail': detail,
        'ip_address': ipAddress,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// Alias yang dipakai dokumentasi desain (`AuditLog`).
typedef AuditLog = AuditLogEntry;
