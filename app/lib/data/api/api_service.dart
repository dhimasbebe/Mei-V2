import 'dart:convert';

import 'package:dio/dio.dart';
import '../../domain/models/alat.dart';
import '../../domain/models/alat_import.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/models/dashboard.dart';
import '../../domain/models/kategori.dart';
import '../../domain/models/lokasi.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/pengingat.dart';
import '../../domain/models/share_link.dart';
import '../../domain/models/spesifikasi.dart';
import '../../domain/models/tugas.dart';
import '../../domain/models/user.dart';
import '../../domain/models/verifikasi.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Semua endpoint Mei-V API v1.
///
/// Kontrak endpoint baru mengikuti `docs/DESIGN-ROLE-UI-V2.md` §6.5.
class ApiService {
  const ApiService();

  Dio get _dio => ApiClient.instance;

  // --------------------------------------------------------------------------
  // Auth
  // --------------------------------------------------------------------------

  /// Login. `role` bersifat disambiguasi UX — server tetap sumber kebenaran
  /// (dikirim di body hanya bila tidak null, demi kompatibilitas pemanggil lama).
  Future<User> login({
    required String username,
    required String password,
    String? role,
  }) async {
    final Response<dynamic> res = await _dio.post(
      '/auth/login',
      data: <String, dynamic>{
        'username': username,
        'password': password,
        if (role != null) 'role': role,
      },
    );
    final Map<String, dynamic> json = _unwrap(res);
    final String token = json['token'] as String;
    ApiClient.setToken(token);
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      ApiClient.clearToken();
    }
  }

  Future<User> getMe() async {
    final Response<dynamic> res = await _dio.get('/auth/me');
    return User.fromJson(_unwrap(res));
  }

  /// Ganti password milik sendiri — `POST /auth/change-password`.
  Future<void> changePassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    await _dio.post(
      '/auth/change-password',
      data: <String, dynamic>{
        'password_lama': passwordLama,
        'password_baru': passwordBaru,
      },
    );
  }

  // --------------------------------------------------------------------------
  // Kategori
  // --------------------------------------------------------------------------

  Future<List<Kategori>> getKategoriList() async {
    final Response<dynamic> res = await _dio.get('/kategori');
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => Kategori.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /kategori` (Admin).
  Future<Kategori> createKategori({
    required String nama,
    String? deskripsi,
    int? maintenanceCycleDays,
    String? iconAsset,
  }) async {
    final Response<dynamic> res = await _dio.post(
      '/kategori',
      data: <String, dynamic>{
        'nama': nama,
        if (deskripsi != null) 'deskripsi': deskripsi,
        if (maintenanceCycleDays != null) 'maintenance_cycle_days': maintenanceCycleDays,
        if (iconAsset != null) 'icon_asset': iconAsset,
      },
    );
    return Kategori.fromJson(_unwrap(res));
  }

  /// `PUT /kategori/{id}` (Admin).
  Future<Kategori> updateKategori({
    required int id,
    String? nama,
    String? deskripsi,
    String? iconAsset,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/kategori/$id',
      data: <String, dynamic>{
        if (nama != null) 'nama': nama,
        if (deskripsi != null) 'deskripsi': deskripsi,
        if (iconAsset != null) 'icon_asset': iconAsset,
      },
    );
    return Kategori.fromJson(_unwrap(res));
  }

  /// `DELETE /kategori/{id}` (Admin).
  Future<void> deleteKategori(int id) async {
    await _dio.delete('/kategori/$id');
  }

  /// `PUT /kategori/{id}/cycle` (Admin) — atur siklus pemeliharaan.
  Future<Kategori> updateKategoriCycle({
    required int id,
    required int maintenanceCycleDays,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/kategori/$id/cycle',
      data: <String, dynamic>{'maintenance_cycle_days': maintenanceCycleDays},
    );
    return Kategori.fromJson(_unwrap(res));
  }

  // --------------------------------------------------------------------------
  // Spesifikasi (checklist dinamis per kategori)
  // --------------------------------------------------------------------------

  Future<List<Spesifikasi>> getSpesifikasiByKategori(int idKategori) async {
    final Response<dynamic> res = await _dio.get('/kategori/$idKategori/spesifikasi');
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => Spesifikasi.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /spesifikasi?=id_kategori` (Admin) — daftar seluruh/ per kategori.
  Future<List<Spesifikasi>> getSpesifikasiList({int? idKategori}) async {
    final Response<dynamic> res = await _dio.get(
      '/spesifikasi',
      queryParameters: <String, dynamic>{
        if (idKategori != null) 'id_kategori': idKategori,
      },
    );
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => Spesifikasi.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /spesifikasi` (Admin).
  Future<Spesifikasi> createSpesifikasi({
    required int idKategori,
    required String namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) async {
    final Response<dynamic> res = await _dio.post(
      '/spesifikasi',
      data: <String, dynamic>{
        'id_kategori': idKategori,
        'nama_spesifikasi': namaSpesifikasi,
        if (tipeInput != null) 'tipe_input': tipeInput,
        if (satuan != null) 'satuan': satuan,
        if (opsi != null) 'opsi': opsi,
        if (urutan != null) 'urutan': urutan,
      },
    );
    return Spesifikasi.fromJson(_unwrap(res));
  }

  /// `PUT /spesifikasi/{id}` (Admin).
  Future<Spesifikasi> updateSpesifikasi({
    required int id,
    String? namaSpesifikasi,
    String? tipeInput,
    String? satuan,
    String? opsi,
    int? urutan,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/spesifikasi/$id',
      data: <String, dynamic>{
        if (namaSpesifikasi != null) 'nama_spesifikasi': namaSpesifikasi,
        if (tipeInput != null) 'tipe_input': tipeInput,
        if (satuan != null) 'satuan': satuan,
        if (opsi != null) 'opsi': opsi,
        if (urutan != null) 'urutan': urutan,
      },
    );
    return Spesifikasi.fromJson(_unwrap(res));
  }

  /// `DELETE /spesifikasi/{id}` (Admin).
  Future<void> deleteSpesifikasi(int id) async {
    await _dio.delete('/spesifikasi/$id');
  }

  /// `PUT /spesifikasi/reorder` (Admin) — urutan baru checklist per kategori.
  ///
  /// [urutanIds] = daftar `id_spesifikasi` sesuai urutan yang diinginkan
  /// (indeks 0 = urutan pertama).
  Future<void> reorderSpesifikasi({
    required int idKategori,
    required List<int> urutanIds,
  }) async {
    await _dio.put(
      '/spesifikasi/reorder',
      data: <String, dynamic>{
        'id_kategori': idKategori,
        'urutan': urutanIds,
      },
    );
  }

  // --------------------------------------------------------------------------
  // Lokasi
  // --------------------------------------------------------------------------

  Future<List<Lokasi>> getLokasiList() async {
    final Response<dynamic> res = await _dio.get('/lokasi');
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => Lokasi.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /lokasi` (Admin).
  Future<Lokasi> createLokasi({required String namaLokasi, int? lantai}) async {
    final Response<dynamic> res = await _dio.post(
      '/lokasi',
      data: <String, dynamic>{
        'nama_lokasi': namaLokasi,
        if (lantai != null) 'lantai': lantai,
      },
    );
    return Lokasi.fromJson(_unwrap(res));
  }

  /// `PUT /lokasi/{id}` (Admin).
  Future<Lokasi> updateLokasi({
    required int id,
    String? namaLokasi,
    int? lantai,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/lokasi/$id',
      data: <String, dynamic>{
        if (namaLokasi != null) 'nama_lokasi': namaLokasi,
        if (lantai != null) 'lantai': lantai,
      },
    );
    return Lokasi.fromJson(_unwrap(res));
  }

  /// `DELETE /lokasi/{id}` (Admin).
  Future<void> deleteLokasi(int id) async {
    await _dio.delete('/lokasi/$id');
  }

  // --------------------------------------------------------------------------
  // Alat
  // --------------------------------------------------------------------------

  Future<Alat> getAlatByBarcode(String barcode) async {
    final Response<dynamic> res = await _dio.get('/alat/$barcode');
    return Alat.fromJson(_unwrap(res));
  }

  Future<List<Alat>> searchAlat({
    String? query,
    int? idKategori,
    int? idLokasi,
    bool? overdue,
    String? penanggungJawab,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/alat',
      queryParameters: <String, dynamic>{
        if (query != null && query.isNotEmpty) 'q': query,
        if (idKategori != null) 'id_kategori': idKategori,
        if (idLokasi != null) 'id_lokasi': idLokasi,
        if (overdue != null) 'overdue': overdue,
        if (penanggungJawab != null) 'penanggung_jawab': penanggungJawab,
      },
    );
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => Alat.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /alat` (Admin).
  Future<Alat> createAlat({
    required String barcodeAlat,
    required String merkAlat,
    required int idKategori,
    int? idLokasi,
  }) async {
    final Response<dynamic> res = await _dio.post(
      '/alat',
      data: <String, dynamic>{
        'barcode_alat': barcodeAlat,
        'merk_alat': merkAlat,
        'id_kategori': idKategori,
        if (idLokasi != null) 'id_lokasi': idLokasi,
      },
    );
    return Alat.fromJson(_unwrap(res));
  }

  /// `PUT /alat/{barcode}` (Admin).
  Future<Alat> updateAlat({
    required String barcode,
    String? merkAlat,
    int? idKategori,
    int? idLokasi,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/alat/$barcode',
      data: <String, dynamic>{
        if (merkAlat != null) 'merk_alat': merkAlat,
        if (idKategori != null) 'id_kategori': idKategori,
        if (idLokasi != null) 'id_lokasi': idLokasi,
      },
    );
    return Alat.fromJson(_unwrap(res));
  }

  /// `DELETE /alat/{barcode}` (Admin).
  Future<void> deleteAlat(String barcode) async {
    await _dio.delete('/alat/$barcode');
  }

  /// `POST /alat/{barcode}/assign` (Supervisor/Admin) — tandai ditugaskan.
  Future<Alat> assignAlat({required String barcode, required String username}) async {
    final Response<dynamic> res = await _dio.post(
      '/alat/$barcode/assign',
      data: <String, dynamic>{'username': username},
    );
    return Alat.fromJson(_unwrap(res));
  }

  // --------------------------------------------------------------------------
  // Maintenance
  // --------------------------------------------------------------------------

  Future<Maintenance> submitMaintenance(MaintenancePayload payload) async {
    final Response<dynamic> res = await _dio.post(
      '/maintenance',
      data: payload.toJson(),
    );
    return Maintenance.fromJson(_unwrap(res));
  }

  Future<PagedResult<Maintenance>> getMaintenanceList({
    int page = 1,
    int perPage = 20,
    String? barcodeAlat,
    int? idKategori,
    String? username,
    String? statusVerifikasi,
    DateTime? dari,
    DateTime? sampai,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/maintenance',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (barcodeAlat != null) 'barcode_alat': barcodeAlat,
        if (idKategori != null) 'id_kategori': idKategori,
        if (username != null && username.isNotEmpty) 'username': username,
        if (statusVerifikasi != null && statusVerifikasi.isNotEmpty)
          'status_verifikasi': statusVerifikasi,
        if (dari != null) 'dari': dari.toIso8601String(),
        if (sampai != null) 'sampai': sampai.toIso8601String(),
      },
    );
    final Map<String, dynamic> json = _unwrap(res);
    final List<dynamic> list = json['data'] as List<dynamic>? ?? <dynamic>[];
    return PagedResult<Maintenance>(
      data: list.map((dynamic e) => Maintenance.fromJson(e as Map<String, dynamic>)).toList(),
      currentPage: json['current_page'] as int? ?? page,
      lastPage: json['last_page'] as int? ?? page,
      total: json['total'] as int? ?? list.length,
    );
  }

  Future<Maintenance> getMaintenanceDetail(int id) async {
    final Response<dynamic> res = await _dio.get('/maintenance/$id');
    return Maintenance.fromJson(_unwrap(res));
  }

  // --------------------------------------------------------------------------
  // Foto lampiran (Fitur Tahap 3)
  // --------------------------------------------------------------------------

  /// `POST /maintenance/{id}/foto` (multipart field `foto`).
  ///
  /// Mengirim BYTES (bukan path) supaya jalur yang sama bekerja di mobile
  /// maupun web. `namaFile` menentukan ekstensi yang divalidasi server
  /// (`mimes:jpg,jpeg,png`).
  Future<FotoLampiran> uploadFotoBytes(
    int id, {
    required List<int> bytes,
    required String namaFile,
  }) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'foto': MultipartFile.fromBytes(bytes, filename: namaFile),
    });
    final Response<dynamic> res = await _dio.post(
      '/maintenance/$id/foto',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return FotoLampiran.fromJson(_unwrap(res));
  }

  /// `GET /maintenance/{id}/foto` — daftar foto lampiran.
  Future<List<FotoLampiran>> getFotos(int id) async {
    final Response<dynamic> res = await _dio.get('/maintenance/$id/foto');
    return _unwrapList(res)
        .map((dynamic e) => FotoLampiran.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `DELETE /maintenance/foto/{id_foto}` (Supervisor/Admin).
  Future<void> deleteFoto(int idFoto) async {
    await _dio.delete('/maintenance/foto/$idFoto');
  }

  /// `GET /maintenance/pending?page=&per_page=` (Supervisor/Admin).
  Future<PagedResult<VerifikasiItem>> getMaintenancePending({
    int page = 1,
    int perPage = 20,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/maintenance/pending',
      queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return PagedResult<VerifikasiItem>.fromJson(_unwrap(res), VerifikasiItem.fromJson);
  }

  /// `GET /maintenance/pending/count` (Supervisor/Admin).
  Future<PendingCount> getMaintenancePendingCount() async {
    final Response<dynamic> res = await _dio.get('/maintenance/pending/count');
    return PendingCount.fromJson(_unwrap(res));
  }

  /// `POST /maintenance/{id}/verify` (Supervisor/Admin).
  Future<Maintenance> verifyMaintenance(int id, VerifikasiPayload payload) async {
    final Response<dynamic> res = await _dio.post(
      '/maintenance/$id/verify',
      data: payload.toJson(),
    );
    return Maintenance.fromJson(_unwrap(res));
  }

  /// `GET /maintenance/overdue` (Supervisor/Admin) — papan keterlambatan.
  Future<PagedResult<Maintenance>> getMaintenanceOverdue({
    int page = 1,
    int perPage = 20,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/maintenance/overdue',
      queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return PagedResult<Maintenance>.fromJson(_unwrap(res), Maintenance.fromJson);
  }

  // --------------------------------------------------------------------------
  // Tugas Hari Ini (Teknisi)
  // --------------------------------------------------------------------------

  /// `GET /tugas-hari-ini` (Teknisi).
  Future<TugasHariIni> getTugasHariIni() async {
    final Response<dynamic> res = await _dio.get('/tugas-hari-ini');
    return TugasHariIni.fromJson(_unwrap(res));
  }

  // --------------------------------------------------------------------------
  // Users (Admin)
  // --------------------------------------------------------------------------

  /// `GET /users?q=&role=&page=` (Admin).
  Future<PagedResult<User>> getUsers({
    String? q,
    String? role,
    int page = 1,
    int perPage = 20,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/users',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (q != null && q.isNotEmpty) 'q': q,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
    return PagedResult<User>.fromJson(_unwrap(res), User.fromJson);
  }

  /// `POST /users` (Admin).
  Future<User> createUser({
    required String username,
    required String namaUsers,
    required String roleUsers,
    String? emailUsers,
    required String password,
  }) async {
    final Response<dynamic> res = await _dio.post(
      '/users',
      data: <String, dynamic>{
        'username': username,
        'nama_users': namaUsers,
        'role_users': roleUsers,
        'email_users': emailUsers,
        'password': password,
      },
    );
    return User.fromJson(_unwrap(res));
  }

  /// `PUT /users/{username}` (Admin).
  Future<User> updateUser({
    required String username,
    String? namaUsers,
    String? roleUsers,
    String? emailUsers,
    String? password,
  }) async {
    final Response<dynamic> res = await _dio.put(
      '/users/$username',
      data: <String, dynamic>{
        if (namaUsers != null) 'nama_users': namaUsers,
        if (roleUsers != null) 'role_users': roleUsers,
        if (emailUsers != null) 'email_users': emailUsers,
        if (password != null) 'password': password,
      },
    );
    return User.fromJson(_unwrap(res));
  }

  /// `DELETE /users/{username}` (Admin).
  Future<void> deleteUser(String username) async {
    await _dio.delete('/users/$username');
  }

  /// `POST /users/{username}/reset-password` (Admin).
  ///
  /// Bila [password] null, server membuat password acak.
  Future<void> resetPassword({required String username, String? password}) async {
    await _dio.post(
      '/users/$username/reset-password',
      data: <String, dynamic>{
        if (password != null) 'password': password,
      },
    );
  }

  // --------------------------------------------------------------------------
  // Audit log (Admin)
  // --------------------------------------------------------------------------

  /// `GET /audit-log?page=&entitas=&actor=&dari=&sampai=` (Admin, Supervisor).
  ///
  /// [dari]/[sampai] berformat `yyyy-MM-dd` (lihat `AuditFilter.keQuery`).
  Future<PagedResult<AuditLogEntry>> getAuditLog({
    int page = 1,
    int perPage = 20,
    String? entitas,
    String? actor,
    String? aksi,
    String? dari,
    String? sampai,
  }) async {
    final Response<dynamic> res = await _dio.get(
      '/audit-log',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (entitas != null && entitas.isNotEmpty) 'entitas': entitas,
        if (actor != null && actor.isNotEmpty) 'actor': actor,
        if (aksi != null && aksi.isNotEmpty) 'aksi': aksi,
        if (dari != null && dari.isNotEmpty) 'dari': dari,
        if (sampai != null && sampai.isNotEmpty) 'sampai': sampai,
      },
    );
    return PagedResult<AuditLogEntry>.fromJson(_unwrap(res), AuditLogEntry.fromJson);
  }

  // --------------------------------------------------------------------------
  // Pengingat (Tahap 3 — WS B)
  // --------------------------------------------------------------------------

  /// `GET /pengingat` — ringkasan + daftar pengingat milik pengguna
  /// (Teknisi: jatuh tempo/terlambat miliknya; Supervisor/Admin:
  /// `menunggu_verifikasi`). Tahap 3 WS B, AC-B1/AC-B2.
  Future<PengingatPayload> getPengingat() async {
    final Response<dynamic> res = await _dio.get('/pengingat');
    return PengingatPayload.fromJson(_unwrap(res));
  }

  // --------------------------------------------------------------------------
  // Dashboard (web)
  // --------------------------------------------------------------------------

  Future<DashboardKpi> getDashboardKpi() async {
    final Response<dynamic> res = await _dio.get('/dashboard/kpi');
    return DashboardKpi.fromJson(_unwrap(res));
  }

  Future<List<TrendPoint>> getDashboardTrends({required int hari}) async {
    final Response<dynamic> res = await _dio.get(
      '/dashboard/trends',
      queryParameters: <String, dynamic>{'days': hari},
    );
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DistributionItem>> getDashboardDistribution() async {
    final Response<dynamic> res = await _dio.get('/dashboard/distribution');
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => DistributionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OverdueItem>> getDashboardOverdue({int limit = 10}) async {
    final Response<dynamic> res = await _dio.get(
      '/dashboard/overdue',
      queryParameters: <String, dynamic>{'limit': limit},
    );
    final List<dynamic> list = _unwrapList(res);
    return list.map((dynamic e) => OverdueItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /dashboard/parameter-abnormal` (Supervisor/Admin).
  Future<List<ParameterAbnormal>> getParameterAbnormal() async {
    final Response<dynamic> res = await _dio.get('/dashboard/parameter-abnormal');
    final List<dynamic> list = _unwrapList(res);
    return list
        .map((dynamic e) => ParameterAbnormal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /dashboard/export?format=csv&dari=&sampai=` (Supervisor/Admin).
  ///
  /// Respons berupa berkas CSV biner (BUKAN envelope JSON), sehingga tidak
  /// melewati [_unwrap]; dipaksa `ResponseType.bytes` dan dikembalikan sebagai
  /// daftar byte siap ditulis ke berkas.
  Future<List<int>> exportLaporan({
    DateTime? dari,
    DateTime? sampai,
    String format = 'csv',
  }) async {
    final Response<List<int>> res = await _dio.get<List<int>>(
      '/dashboard/export',
      queryParameters: <String, dynamic>{
        'format': format,
        if (dari != null) 'dari': dari.toIso8601String(),
        if (sampai != null) 'sampai': sampai.toIso8601String(),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final List<int>? bytes = res.data;
    return bytes ?? <int>[];
  }

  // --------------------------------------------------------------------------
  // Ekspor PDF / label QR / impor CSV / tautan bagikan
  // (WS L, M, N, O — Fitur Tahap 3, T09)
  // --------------------------------------------------------------------------

  /// `GET /maintenance/{id}/pdf` (Supervisor/Admin) — PDF resmi satu laporan.
  ///
  /// Respons BINER `application/pdf` tanpa envelope → pola sama dengan
  /// [exportLaporan], dipaksa [ResponseType.bytes] (AC-L1).
  Future<List<int>> getMaintenancePdf(int id) => _bytes(
        () => _dio.get<List<int>>(
          '/maintenance/$id/pdf',
          options: Options(responseType: ResponseType.bytes),
        ),
      );

  /// `GET /dashboard/export/pdf?dari=&sampai=` (Supervisor/Admin).
  ///
  /// Server menolak 422 bila rentang > 90 hari atau baris > 500. Karena body
  /// galat ikut dibaca sebagai bytes, pesan aslinya dipulihkan oleh
  /// [_exceptionDariBytes] supaya pengguna melihat ALASANNYA (AC-L3).
  Future<List<int>> getPeriodePdf({
    required DateTime dari,
    required DateTime sampai,
  }) =>
      _bytes(
        () => _dio.get<List<int>>(
          '/dashboard/export/pdf',
          queryParameters: <String, dynamic>{
            'dari': dari.toIso8601String(),
            'sampai': sampai.toIso8601String(),
          },
          options: Options(responseType: ResponseType.bytes),
        ),
      );

  /// `POST /dashboard/export/qr-labels` (Supervisor/Admin).
  ///
  /// Body `{ "barcode": ["AC-001", ...] }` → PDF grid label. Daftar kosong
  /// atau barcode tak dikenal ditolak 422 beserta daftarnya (AC-N2, AC-N3).
  Future<List<int>> postQrLabels(List<String> barcode) => _bytes(
        () => _dio.post<List<int>>(
          '/dashboard/export/qr-labels',
          data: <String, dynamic>{'barcode': barcode},
          options: Options(responseType: ResponseType.bytes),
        ),
      );

  /// `POST /alat/impor/preview` (Admin) — validasi per baris, TANPA menulis DB.
  ///
  /// Dua sumber input (AC-M9): [csv] = teks CSV yang ditempel (jalur ponsel),
  /// atau [fileBytes] = isi berkas CSV multipart (jalur web). [fileBytes]
  /// menang bila keduanya diisi.
  Future<AlatImportResult> previewImporCsv({
    String? csv,
    List<int>? fileBytes,
    String namaFile = 'alat.csv',
  }) async {
    final Response<dynamic> res = await _dio.post<dynamic>(
      '/alat/impor/preview',
      data: _formImpor(csv: csv, fileBytes: fileBytes, namaFile: namaFile),
      options: _opsiImpor(fileBytes),
    );
    return AlatImportResult.fromJson(_unwrap(res));
  }

  /// `POST /alat/impor/commit` (Admin) — menulis HANYA baris valid.
  ///
  /// 0 baris valid → 422 (AC-M3). Respons memuat `diimpor`/`gagal` yang tetap
  /// terbaca oleh [AlatImportResult.fromJson].
  Future<AlatImportResult> commitImporCsv({
    String? csv,
    List<int>? fileBytes,
    String namaFile = 'alat.csv',
  }) async {
    final Response<dynamic> res = await _dio.post<dynamic>(
      '/alat/impor/commit',
      data: _formImpor(csv: csv, fileBytes: fileBytes, namaFile: namaFile),
      options: _opsiImpor(fileBytes),
    );
    return AlatImportResult.fromJson(_unwrap(res));
  }

  /// `POST /maintenance/{id}/share` (Supervisor/Admin) — buat tautan publik.
  ///
  /// [expiresAt] opsional (null = tanpa kedaluwarsa). Dua permintaan pada
  /// laporan yang sama menghasilkan dua token berbeda (AC-O1).
  Future<ShareLink> buatShareLink(int id, {DateTime? expiresAt}) async {
    final Response<dynamic> res = await _dio.post<dynamic>(
      '/maintenance/$id/share',
      data: <String, dynamic>{
        if (expiresAt != null)
          'expires_at': _formatSqlDateTime(expiresAt),
      },
    );
    return ShareLink.fromJson(_unwrap(res));
  }

  /// `DELETE /share/{token}` (Supervisor/Admin) — cabut tautan (soft revoke).
  ///
  /// Idempoten: token yang sudah dicabut tetap dianggap berhasil.
  Future<void> cabutShareLink(String token) async {
    await _dio.delete<dynamic>('/share/$token');
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  /// Konvensi respons server Laravel (envelope):
  /// ```json
  /// { "code": 200, "data": { ... }, "message": "OK" }
  /// ```
  /// Bila `data` berupa array maka mapping dilakukan per-item di [_unwrapList].
  Map<String, dynamic> _unwrap(Response<dynamic> res) {
    if (res.data is Map<String, dynamic>) {
      final Map<String, dynamic> json = res.data as Map<String, dynamic>;
      if (json.containsKey('data')) {
        final dynamic d = json['data'];
        if (d is Map<String, dynamic>) return d;
        // Bila data bukan objek (misal string), bungkus agar konsisten.
        return <String, dynamic>{'value': d};
      }
      return json;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(Response<dynamic> res) {
    if (res.data is Map<String, dynamic>) {
      final Map<String, dynamic> json = res.data as Map<String, dynamic>;
      final dynamic d = json['data'];
      if (d is List) return d;
      if (d == null) return <dynamic>[];
      return <dynamic>[d];
    }
    if (res.data is List) return res.data as List<dynamic>;
    return <dynamic>[];
  }

  // --------------------------------------------------------------------------
  // Helper ekspor biner + impor (WS L, M, N — T09)
  // --------------------------------------------------------------------------

  /// Menjalankan permintaan [ResponseType.bytes] dan mengembalikan isinya.
  ///
  /// Endpoint biner tetap memakai route `api/*`, sehingga kegagalan validasi
  /// datang sebagai envelope JSON yang—karena respons diminta sebagai bytes—
  /// tidak dapat dibaca `_ErrorInterceptor` (data bukan `Map`). Tanpa
  /// penanganan di sini pengguna hanya melihat "Terjadi kesalahan." alih-alih
  /// "Rentang maksimal 90 hari." (AC-L3). Karena itu body galat di-decode
  /// ulang di [_exceptionDariBytes].
  Future<List<int>> _bytes(Future<Response<List<int>>> Function() jalankan) async {
    try {
      final Response<List<int>> res = await jalankan();
      return res.data ?? <int>[];
    } on DioException catch (e) {
      throw _exceptionDariBytes(e);
    }
  }

  /// Membangun [ApiException] bertipe benar dari body galat berformat bytes.
  ///
  /// Bila body bukan JSON (mis. halaman HTML 500), jatuh ke [ServerException]
  /// dengan pesan bawaan sehingga pemanggil tetap mendapat tipe yang dapat
  /// ditangani.
  ApiException _exceptionDariBytes(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final int? status = e.response?.statusCode;
    Map<String, dynamic>? body;

    final dynamic data = e.response?.data;
    if (data is List<int> && data.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        body = null;
      }
    } else if (data is Map<String, dynamic>) {
      body = data;
    }

    final String pesan = (body?['message'] as String?) ??
        (body?['error'] as String?) ??
        'Gagal mengunduh berkas.';

    switch (status) {
      case 401:
        return UnauthorizedException(pesan);
      case 403:
        return ForbiddenException(pesan);
      case 404:
        return NotFoundException(pesan);
      case 409:
        return ConflictException(pesan);
      case 422:
        final dynamic errors = body?['errors'];
        Map<String, List<String>>? peta;
        if (errors is Map<String, dynamic>) {
          peta = errors.map((String k, dynamic v) => MapEntry<String, List<String>>(
                k,
                v is List ? v.map((dynamic x) => '$x').toList() : <String>['$v'],
              ));
        }
        return ValidationException(peta, message: pesan);
      default:
        return status == null ? const NetworkException() : ServerException(pesan);
    }
  }

  /// Body impor: multipart bila [fileBytes] ada, selain itu JSON teks `csv`.
  dynamic _formImpor({
    String? csv,
    List<int>? fileBytes,
    required String namaFile,
  }) {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(fileBytes, filename: namaFile),
      });
    }
    return <String, dynamic>{'csv': csv ?? ''};
  }

  /// Multipart butuh header yang dibiarkan Dio lengkapi (boundary).
  Options? _opsiImpor(List<int>? fileBytes) =>
      fileBytes != null && fileBytes.isNotEmpty
          ? Options(contentType: 'multipart/form-data')
          : null;

  /// Format `Y-m-d H:i:s` yang diterima validasi `date` di backend.
  String _formatSqlDateTime(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dua(d.month)}-${dua(d.day)} '
        '${dua(d.hour)}:${dua(d.minute)}:${dua(d.second)}';
  }
}
