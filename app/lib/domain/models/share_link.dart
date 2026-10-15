/// Model tautan bagikan laporan (WS O, Fitur Tahap 3) — DART MURNI, tanpa
/// package:flutter sehingga dapat diverifikasi `tools/modelcheck`.
///
/// Kontrak JSON mengikuti respons backend `POST /api/v1/maintenance/{id}/share`
/// (201): `{ id_share, id_maintenance, token, url, expires_at, created_at }`.
///
/// AC-O6: `ShareLink.fromJson()` memetakan fixture buat-tautan
/// (url, token, expires_at). Lihat `docs/DESIGN-FEATURES-V3.md` §C.1.5.
library;

class ShareLink {
  const ShareLink({
    required this.idShare,
    required this.idMaintenance,
    required this.token,
    required this.url,
    this.expiresAt,
    this.revokedAt,
    required this.createdAt,
  });

  final int idShare;
  final int idMaintenance;

  /// Token acak >= 32 karakter, unik di tabel `share_links`.
  final String token;

  /// URL halaman publik lengkap (`<host>/share/<token>`).
  final String url;

  /// Opsional — null berarti tanpa kedaluwarsa.
  final DateTime? expiresAt;

  /// != null berarti tautan telah dicabut (soft revoke).
  final DateTime? revokedAt;

  final DateTime createdAt;

  /// Tautan masih aktif: belum dicabut dan belum kedaluwarsa.
  bool get aktif =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get dicabut => revokedAt != null;

  bool get kedaluwarsa => !aktif && revokedAt == null;

  factory ShareLink.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? raw) {
      final String s = '$raw';
      return s.isEmpty || s == 'null' ? null : DateTime.tryParse(s);
    }

    return ShareLink(
      idShare: int.tryParse('${json['id_share'] ?? json['idShare'] ?? 0}') ?? 0,
      idMaintenance:
          int.tryParse('${json['id_maintenance'] ?? json['idMaintenance'] ?? 0}') ?? 0,
      token: (json['token'] ?? '') as String,
      url: (json['url'] ?? json['share_url'] ?? '') as String,
      expiresAt: parse(json['expires_at'] ?? json['expiresAt']),
      revokedAt: parse(json['revoked_at'] ?? json['revokedAt']),
      createdAt: parse(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_share': idShare,
        'id_maintenance': idMaintenance,
        'token': token,
        'url': url,
        'expires_at': expiresAt?.toIso8601String(),
        'revoked_at': revokedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
