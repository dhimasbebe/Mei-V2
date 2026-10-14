// Harness verifikasi model Flutter terhadap respons API Laravel yang ASLI.
//
// Fixture di app/test/fixtures/*.json direkam dari server Laravel yang
// berjalan (lihat backend/tools/capture_fixtures.py). Jadi berkas ini
// membuktikan kontrak Laravel <-> Dart benar-benar cocok, bukan sekadar
// JSON karangan.
//
// Kenapa paket terpisah? Karena model hanya butuh `intl`, sedangkan
// menjalankan skrip di dalam paket Flutter akan memicu "native assets build
// hooks" (objective_c) yang men-spawn proses tambahan. Paket kecil ini
// membuat verifikasi model bisa dijalankan dengan `dart run` biasa.
//
// Jalankan dari folder ini:
//   dart pub get
//   dart run verify_models.dart
//
// Versi flutter_test dari uji yang sama ada di app/test/models_test.dart
// (dijalankan CI lewat `flutter test`).

import 'dart:convert';
import 'dart:io';

import '../../app/lib/domain/models/alat.dart';
import '../../app/lib/domain/models/audit_log.dart';
import '../../app/lib/domain/models/dashboard.dart';
import '../../app/lib/domain/models/kategori.dart';
import '../../app/lib/domain/models/lokasi.dart';
import '../../app/lib/domain/models/maintenance.dart';
import '../../app/lib/domain/models/spesifikasi.dart';
import '../../app/lib/domain/models/tugas.dart';
import '../../app/lib/domain/models/user.dart';
import '../../app/lib/domain/models/verifikasi.dart';

/// Folder fixture, relatif terhadap root paket ini.
const String _fixtureDir = '../../app/test/fixtures';

int _ok = 0;
int _fail = 0;

void check(String label, bool condition, [String detail = '']) {
  if (condition) {
    _ok++;
    print('  PASS  $label${detail.isEmpty ? '' : '  $detail'}');
  } else {
    _fail++;
    print('  FAIL  $label${detail.isEmpty ? '' : '  $detail'}');
  }
}

void section(String title) {
  print('');
  print('=' * 74);
  print(title);
  print('=' * 74);
}

Map<String, dynamic> fx(String name) {
  final File f = File('$_fixtureDir/$name');
  if (!f.existsSync()) {
    throw StateError('Fixture tidak ada: ${f.path}\n'
        'Jalankan dulu: cd backend && php artisan serve  lalu  '
        'python tools/capture_fixtures.py');
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

List<Map<String, dynamic>> listOf(Map<String, dynamic> env) =>
    (env['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

void main() {
  // --------------------------------------------------------------------
  section('1. ENVELOPE + USER');
  // --------------------------------------------------------------------
  final Map<String, dynamic> login = fx('login.json');
  check('envelope login punya code/data/message',
      login.containsKey('code') && login.containsKey('data') && login.containsKey('message'),
      login.keys.join(', '));
  check('code == 200', login['code'] == 200, '${login['code']}');

  final Map<String, dynamic> loginData = login['data'] as Map<String, dynamic>;
  final User user = User.fromJson(loginData['user'] as Map<String, dynamic>);
  check('User.username', user.username == '12345', user.username);
  check('User.namaUsers', user.namaUsers == 'Admin Mei-V', user.namaUsers);
  check('User.roleUsers', user.roleUsers == 'Admin', user.roleUsers);
  check('User.emailUsers', user.emailUsers == 'admin@meiv.test', '${user.emailUsers}');
  check('User.inisial == "AM"', user.inisial == 'AM', user.inisial);
  check('User.isAdmin terdeteksi', user.isAdmin, 'isAdmin=${user.isAdmin}');

  // --------------------------------------------------------------------
  section('2. KATEGORI');
  // --------------------------------------------------------------------
  final List<Kategori> kats = listOf(fx('kategori.json')).map(Kategori.fromJson).toList();
  check('7 kategori', kats.length == 7, 'n=${kats.length}');
  final Kategori ac = kats.firstWhere((Kategori k) => k.nama == 'AC');
  check('AC.idKategori == 1', ac.idKategori == 1, '${ac.idKategori}');
  check('AC.maintenanceCycleDays == 30', ac.maintenanceCycleDays == 30, '${ac.maintenanceCycleDays}');
  check('AC.jumlahAlat == 3', ac.jumlahAlat == 3, '${ac.jumlahAlat}');
  check('AC.iconAsset terisi', ac.iconAsset == 'assets/images/ac.png', '${ac.iconAsset}');
  final Kategori pp = kats.firstWhere((Kategori k) => k.nama == 'Penangkal Petir');
  check('Penangkal Petir siklus 90 hari', pp.maintenanceCycleDays == 90, '${pp.maintenanceCycleDays}');
  check('total jumlahAlat == 21',
      kats.fold<int>(0, (int a, Kategori k) => a + (k.jumlahAlat ?? 0)) == 21);
  for (final Kategori k in kats) {
    print('        ${k.nama.padRight(20)} id=${k.idKategori}  siklus=${k.maintenanceCycleDays}h  '
        'alat=${k.jumlahAlat}  ${k.iconAsset}');
  }

  // --------------------------------------------------------------------
  section('3. SPESIFIKASI (checklist dinamis)');
  // --------------------------------------------------------------------
  final List<Spesifikasi> specAc =
      listOf(fx('spesifikasi_ac.json')).map(Spesifikasi.fromJson).toList();
  final List<Spesifikasi> specGs =
      listOf(fx('spesifikasi_genset.json')).map(Spesifikasi.fromJson).toList();
  check('checklist AC = 8 item', specAc.length == 8, 'n=${specAc.length}');
  check('checklist Genset = 7 item', specGs.length == 7, 'n=${specGs.length}');
  check('AC semua idKategori == 1', specAc.every((Spesifikasi s) => s.idKategori == 1));
  check('Genset semua idKategori == 7', specGs.every((Spesifikasi s) => s.idKategori == 7));
  check('id_spesifikasi unik lintas kategori (bug collision lama)',
      <int>{...specAc.map((Spesifikasi s) => s.idSpesifikasi),
              ...specGs.map((Spesifikasi s) => s.idSpesifikasi)}.length ==
          specAc.length + specGs.length);
  final Spesifikasi selectItem =
      specAc.firstWhere((Spesifikasi s) => s.tipeInput == 'select', orElse: () => specAc.first);
  check('tipeInput select -> opsi terpecah dari "|"',
      selectItem.tipeInput != 'select' || selectItem.opsi.isNotEmpty,
      'opsi=${selectItem.opsi}');
  check('labelDenganSatuan menggabungkan satuan',
      specAc.first.satuan == null || specAc.first.labelDenganSatuan.contains(specAc.first.satuan!),
      specAc.first.labelDenganSatuan);
  for (final Spesifikasi s in specAc) {
    print('        [${s.urutan}] ${s.namaSpesifikasi.padRight(26)} '
        '${s.tipeInput.padRight(8)} ${s.satuan ?? "-"}  ${s.opsiRaw ?? ""}');
  }

  // --------------------------------------------------------------------
  section('4. ALAT (kolom datar hasil join)');
  // --------------------------------------------------------------------
  final List<Alat> alats = listOf(fx('alat_list.json')).map(Alat.fromJson).toList();
  check('21 alat', alats.length == 21, 'n=${alats.length}');
  check('semua alat punya namaKategori', alats.every((Alat a) => (a.namaKategori ?? '').isNotEmpty));
  check('semua alat punya namaLokasi', alats.every((Alat a) => (a.namaLokasi ?? '').isNotEmpty));
  check('semua alat punya lantai', alats.every((Alat a) => a.lantai != null));
  check('semua alat punya siklusHari > 0', alats.every((Alat a) => a.siklusHari > 0));

  final Alat ac1 = Alat.fromJson(fx('alat_ac001.json')['data'] as Map<String, dynamic>);
  check('AC-001 barcodeAlat', ac1.barcodeAlat == 'AC-001', ac1.barcodeAlat);
  check('AC-001 namaKategori == AC', ac1.namaKategori == 'AC', '${ac1.namaKategori}');
  check('AC-001 namaLokasi == Aula Besar', ac1.namaLokasi == 'Aula Besar', '${ac1.namaLokasi}');
  check('AC-001 lantai == 7', ac1.lantai == 7, '${ac1.lantai}');
  check('AC-001 siklusHari == 30', ac1.siklusHari == 30, '${ac1.siklusHari}');
  check('AC-001 terakhirMaintenance ter-parse', ac1.terakhirMaintenance != null,
      '${ac1.terakhirMaintenance}');
  check('AC-001 detailLokasi == "Aula Besar Lantai 7"',
      ac1.detailLokasi == 'Aula Besar Lantai 7', ac1.detailLokasi);
  check('AC-001 deskripsiKategori terisi', (ac1.deskripsiKategori ?? '').isNotEmpty,
      '${ac1.deskripsiKategori}');

  final Alat ac3 = Alat.fromJson(fx('alat_ac003.json')['data'] as Map<String, dynamic>);
  check('AC-003 terakhirMaintenance == null (sengaja belum dipelihara)',
      ac3.terakhirMaintenance == null, '${ac3.terakhirMaintenance}');
  check('AC-003 overdue == true (belum pernah dipelihara)', ac3.overdue);
  check('AC-003 umurHari == null', ac3.umurHari == null, '${ac3.umurHari}');

  // --------------------------------------------------------------------
  section('5. LOKASI');
  // --------------------------------------------------------------------
  final List<Lokasi> loks = listOf(fx('lokasi.json')).map(Lokasi.fromJson).toList();
  check('8 lokasi', loks.length == 8, 'n=${loks.length}');
  check('semua lokasi punya jumlahAlat', loks.every((Lokasi l) => l.jumlahAlat != null));
  check('total alat dari lokasi == 21',
      loks.fold<int>(0, (int a, Lokasi l) => a + (l.jumlahAlat ?? 0)) == 21);
  final Lokasi basement = loks.firstWhere((Lokasi l) => l.namaLokasi == 'Basement');
  check('Basement lantai == -1', basement.lantai == -1, '${basement.lantai}');
  check('Basement.label == "Basement Lantai -1"', basement.label == 'Basement Lantai -1',
      basement.label);
  final Lokasi ruangMe = loks.firstWhere((Lokasi l) => l.namaLokasi == 'Ruang ME');
  check('Ruang ME.label menyertakan lantai', ruangMe.label == 'Ruang ME Lantai 7', ruangMe.label);

  // --------------------------------------------------------------------
  section('6. DASHBOARD');
  // --------------------------------------------------------------------
  final DashboardKpi kpi =
      DashboardKpi.fromJson(fx('dashboard_kpi.json')['data'] as Map<String, dynamic>);
  check('KPI totalAlat == 21', kpi.totalAlat == 21, '${kpi.totalAlat}');
  check('KPI totalKategori == 7', kpi.totalKategori == 7, '${kpi.totalKategori}');
  check('KPI alatOverdue > 0', kpi.alatOverdue > 0, '${kpi.alatOverdue}');
  check('KPI persenTepatWaktu > 0', kpi.persenTepatWaktu > 0, '${kpi.persenTepatWaktu}');
  check('KPI rataRataIntervalHari ter-parse', kpi.rataRataIntervalHari != null,
      '${kpi.rataRataIntervalHari}');
  print('        KPI: totalAlat=${kpi.totalAlat} totalKategori=${kpi.totalKategori} '
      'bulanIni=${kpi.pemeliharaanBulanIni} tepatWaktu=${kpi.pemeliharaanTepatWaktu} '
      'overdue=${kpi.alatOverdue} teknisiAktif=${kpi.teknisiAktif} '
      'persen=${kpi.persenTepatWaktu} interval=${kpi.rataRataIntervalHari}');

  final List<TrendPoint> trends =
      listOf(fx('dashboard_trends.json')).map(TrendPoint.fromJson).toList();
  check('trends 7 titik (semua hari terisi, tanpa lubang)', trends.length == 7, 'n=${trends.length}');
  check('trend label berupa tanggal', RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trends.first.label),
      trends.first.label);
  check('trend ada nilai > 0', trends.any((TrendPoint t) => t.jumlah > 0),
      trends.map((TrendPoint t) => t.jumlah).join(','));

  final List<DistributionItem> dist =
      listOf(fx('dashboard_distribution.json')).map(DistributionItem.fromJson).toList();
  check('distribusi 7 kategori', dist.length == 7, 'n=${dist.length}');
  check('semua distribusi punya iconAsset',
      dist.every((DistributionItem d) => (d.iconAsset ?? '').isNotEmpty));
  check('total distribusi == 21',
      dist.fold<int>(0, (int a, DistributionItem d) => a + d.jumlah) == 21);

  final List<OverdueItem> overdue =
      listOf(fx('dashboard_overdue.json')).map(OverdueItem.fromJson).toList();
  check('overdue <= limit 5', overdue.length <= 5, 'n=${overdue.length}');
  check('overdue terurut menurun',
      List<int>.generate(overdue.length - 1, (int i) => i)
          .every((int i) => overdue[i].terlambatHari >= overdue[i + 1].terlambatHari),
      overdue.map((OverdueItem o) => o.terlambatHari).join(','));
  check('overdue punya namaKategori & namaLokasi',
      overdue.every((OverdueItem o) => o.namaKategori.isNotEmpty && o.namaLokasi.isNotEmpty));
  for (final OverdueItem o in overdue) {
    print('        ${o.barcodeAlat.padRight(9)} ${o.merkAlat.padRight(26)} '
        '${o.namaLokasi.padRight(22)} terlambat ${o.terlambatHari} hari');
  }

  // --------------------------------------------------------------------
  section('7. MAINTENANCE (paginasi + detail)');
  // --------------------------------------------------------------------
  final PagedResult<Maintenance> page = PagedResult<Maintenance>.fromJson(
      fx('maintenance_page.json')['data'] as Map<String, dynamic>, Maintenance.fromJson);
  check('perPage dihormati == 3', page.perPage == 3, '${page.perPage}');
  check('total > 0', page.total > 0, '${page.total}');
  check('currentPage == 1', page.currentPage == 1, '${page.currentPage}');
  check('data terisi', page.data.isNotEmpty, 'n=${page.data.length}');
  check('semua baris punya kolom join datar',
      page.data.every((Maintenance m) =>
          (m.namaKategori ?? '').isNotEmpty &&
          (m.namaUsers ?? '').isNotEmpty &&
          (m.namaLokasi ?? '').isNotEmpty &&
          m.lantai != null));
  check('waktuMaintenance ter-parse', page.data.first.waktuMaintenance.year > 2000,
      page.data.first.waktuTampil);
  check('hasNext konsisten', page.hasNext == (page.currentPage < page.lastPage),
      'hasNext=${page.hasNext}');

  final Maintenance full =
      Maintenance.fromJson(fx('maintenance_detail.json')['data'] as Map<String, dynamic>);
  check('detail terisi', full.detail.isNotEmpty, 'n=${full.detail.length}');
  check('detail punya namaSpesifikasi',
      full.detail.every((DetailMaintenance d) => (d.namaSpesifikasi ?? '').isNotEmpty));
  check('detail punya status tidak kosong',
      full.detail.every((DetailMaintenance d) => d.status.isNotEmpty));
  check('detailRingkas menghasilkan teks laporan',
      full.detailRingkas.isNotEmpty && full.detailRingkas.contains(':'),
      full.detailRingkas.split('\n').first);
  check('RiwayatItem.fromMaintenance jalan', RiwayatItem.fromMaintenance(full).teknisi.isNotEmpty,
      RiwayatItem.fromMaintenance(full).teknisi);
  for (final DetailMaintenance d in full.detail) {
    print('        ${d.teksLaporan}');
  }

  // --------------------------------------------------------------------
  section('8. PAYLOAD KIRIM (MaintenancePayload.toJson)');
  // --------------------------------------------------------------------
  final MaintenancePayload payload = MaintenancePayload(
    barcodeAlat: 'AC-001',
    idLokasi: 5,
    kondisiKeseluruhan: 'baik',
    catatan: 'Uji kontrak',
    detail: specAc
        .map((Spesifikasi s) => DetailMaintenance(idSpesifikasi: s.idSpesifikasi, status: 'Baik'))
        .toList(),
  );
  final Map<String, dynamic> json = payload.toJson();
  final String cu = '${json['client_uuid']}';
  check('payload punya client_uuid', cu.isNotEmpty, cu);
  final RegExp uuidV4 =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  check('client_uuid berpola UUID v4', uuidV4.hasMatch(cu), cu);
  check('client_uuid panjang 36', cu.length == 36, 'len=${cu.length}');
  check('client_uuid tanpa tanda "-" ganda', !cu.contains('--'), cu);
  check('payload punya waktu_maintenance', json['waktu_maintenance'] != null);
  check('payload punya detail (min. 1) — server menolak array kosong',
      (json['detail'] as List<dynamic>).isNotEmpty, 'n=${(json['detail'] as List<dynamic>).length}');
  check('setiap detail punya id_spesifikasi & status',
      (json['detail'] as List<dynamic>).every((dynamic d) =>
          (d as Map<String, dynamic>)['id_spesifikasi'] != null && d['status'] != null));
  check('kondisi_keseluruhan salah satu nilai enum server',
      <String>['baik', 'kurang_baik', 'rusak'].contains(json['kondisi_keseluruhan']),
      '${json['kondisi_keseluruhan']}');

  // Regresi: _uuid() dulu menghasilkan string tidak valid karena
  // `microsecondsSinceEpoch << 13` melampaui int64 -> negatif -> ada '-'.
  const int n = 3000;
  final List<String> uuids = List<String>.generate(
      n,
      (int i) => MaintenancePayload(
            barcodeAlat: 'AC-001',
            idLokasi: 1,
            detail: const <DetailMaintenance>[
              DetailMaintenance(idSpesifikasi: 1, status: 'Baik'),
            ],
          ).clientUuid);
  check('$n UUID semuanya valid v4', uuids.every(uuidV4.hasMatch),
      uuids.firstWhere((String u) => !uuidV4.hasMatch(u), orElse: () => '(semua valid)'));
  check('$n UUID semuanya unik', uuids.toSet().length == n,
      'unik=${uuids.toSet().length}');
  print('        contoh: ${uuids.first} / ${uuids[n ~/ 2]} / ${uuids.last}');
  print('        payload: ${jsonEncode(json).substring(0, 120)}...');

  // --------------------------------------------------------------------
  section('9. TUGAS HARI INI (Teknisi)');
  // --------------------------------------------------------------------
  final TugasHariIni tugas =
      TugasHariIni.fromJson(fx('tugas_hari_ini.json')['data'] as Map<String, dynamic>);
  check('ringkasan.total == 12', tugas.ringkasan.total == 12, '${tugas.ringkasan.total}');
  check('ringkasan.overdue == 4', tugas.ringkasan.overdue == 4, '${tugas.ringkasan.overdue}');
  check('ringkasan.jatuhTempoHariIni == 3', tugas.ringkasan.jatuhTempoHariIni == 3,
      '${tugas.ringkasan.jatuhTempoHariIni}');
  check('daftar berisi 3 tugas', tugas.daftar.length == 3, 'n=${tugas.daftar.length}');
  final TugasItem tAc = tugas.daftar.firstWhere((TugasItem t) => t.barcodeAlat == 'AC-001');
  check('AC-001 isOverdue', tAc.isOverdue, '${tAc.status}');
  check('AC-001 terlambat 6 hari', tAc.terlambatHari == 6, '${tAc.terlambatHari}');
  check('AC-001 detailLokasi "Ruang Server Lantai 2"',
      tAc.detailLokasi == 'Ruang Server Lantai 2', tAc.detailLokasi);
  check('AC-001 terakhirMaintenance ter-parse', tAc.terakhirMaintenance != null,
      '${tAc.terakhirMaintenance}');
  check('AC-001 teksKeterlambatan', tAc.teksKeterlambatan == 'Terlambat 6 hari',
      tAc.teksKeterlambatan);
  final TugasItem tApar = tugas.daftar.firstWhere((TugasItem t) => t.barcodeAlat == 'APAR-004');
  check('APAR-004 belum pernah dipelihara', tApar.belumPernahDipelihara);
  check('APAR-004 terakhirMaintenance null', tApar.terakhirMaintenance == null);
  check('hitung belum pernah dipelihara == 1', tugas.belumPernahDipelihara == 1,
      '${tugas.belumPernahDipelihara}');

  // --------------------------------------------------------------------
  section('10. VERIFIKASI (pending + count + verify)');
  // --------------------------------------------------------------------
  final PagedResult<VerifikasiItem> pending = PagedResult<VerifikasiItem>.fromJson(
      fx('maintenance_pending.json')['data'] as Map<String, dynamic>, VerifikasiItem.fromJson);
  check('pending.total == 47', pending.total == 47, '${pending.total}');
  check('pending.lastPage == 3', pending.lastPage == 3, '${pending.lastPage}');
  check('pending.perPage == 20', pending.perPage == 20, '${pending.perPage}');
  check('pending berisi 2 item', pending.data.length == 2, 'n=${pending.data.length}');
  final VerifikasiItem vFirst = pending.data.first;
  check('item pertama menunggu', vFirst.menunggu, '${vFirst.statusVerifikasi}');
  check('item pertama teknisi "Teknisi A"', vFirst.teknisi == 'Teknisi A', vFirst.teknisi);
  check('item pertama detailLokasi "Aula Besar Lantai 7"',
      vFirst.detailLokasi == 'Aula Besar Lantai 7', vFirst.detailLokasi);
  check('item pertama punya detail checklist', vFirst.detail.isNotEmpty, 'n=${vFirst.detail.length}');
  for (final VerifikasiItem v in pending.data) {
    print('        #${v.idMaintenance} ${v.barcodeAlat.padRight(9)} ${v.teknisi.padRight(12)} '
        '${v.statusVerifikasi}  ${v.kondisiKeseluruhan}');
  }

  final PendingCount pc =
      PendingCount.fromJson(fx('maintenance_pending_count.json')['data'] as Map<String, dynamic>);
  check('pendingCount.menunggu == 47', pc.menunggu == 47, '${pc.menunggu}');
  check('pendingCount.label == "47"', pc.label == '47', pc.label);
  check('pendingCount.kosong == false', !pc.kosong);

  final Map<String, dynamic> vp = VerifikasiPayload.setujui(komentar: 'Data lengkap.').toJson();
  check('VerifikasiPayload status disetujui', vp['status'] == 'disetujui', '${vp['status']}');
  check('VerifikasiPayload komentar diteruskan', vp['komentar'] == 'Data lengkap.',
      '${vp['komentar']}');
  check('VerifikasiPayload.setujui valid', VerifikasiPayload.setujui().valid);
  check('VerifikasiPayload.tolak valid', VerifikasiPayload.tolak().valid);

  final Maintenance verified =
      Maintenance.fromJson(fx('maintenance_verify.json')['data'] as Map<String, dynamic>);
  check('verify idMaintenance == 88', verified.idMaintenance == 88, '${verified.idMaintenance}');
  check('verify statusVerifikasi == disetujui', verified.statusVerifikasi == 'disetujui',
      '${verified.statusVerifikasi}');
  check('verify disetujui getter', verified.disetujui);
  check('verify menungguVerifikasi false', !verified.menungguVerifikasi);
  check('verify diverifikasiOleh == 11111', verified.diverifikasiOleh == '11111',
      '${verified.diverifikasiOleh}');
  check('verify waktuVerifikasi ter-parse', verified.waktuVerifikasi != null,
      '${verified.waktuVerifikasi}');
  check('verify komentarVerifikasi', verified.komentarVerifikasi == 'Data lengkap.',
      '${verified.komentarVerifikasi}');

  final Maintenance legacy =
      Maintenance.fromJson(fx('maintenance_detail.json')['data'] as Map<String, dynamic>);
  check('Maintenance lama tanpa kolom verifikasi -> menungguVerifikasi', legacy.menungguVerifikasi);
  check('Maintenance lama statusVerifikasiTampil == "menunggu"',
      legacy.statusVerifikasiTampil == 'menunggu', legacy.statusVerifikasiTampil);

  final PagedResult<Maintenance> overduePage = PagedResult<Maintenance>.fromJson(
      fx('maintenance_overdue.json')['data'] as Map<String, dynamic>, Maintenance.fromJson);
  check('overdue page total == 1', overduePage.total == 1, '${overduePage.total}');
  check('overdue baris punya statusVerifikasi', overduePage.data.first.statusVerifikasi != null,
      '${overduePage.data.first.statusVerifikasi}');

  // --------------------------------------------------------------------
  section('11. AUDIT LOG (Admin)');
  // --------------------------------------------------------------------
  final PagedResult<AuditLogEntry> audit = PagedResult<AuditLogEntry>.fromJson(
      fx('audit_log_page.json')['data'] as Map<String, dynamic>, AuditLogEntry.fromJson);
  check('audit total == 2', audit.total == 2, '${audit.total}');
  final AuditLogEntry aFirst = audit.data.first;
  check('audit idAudit == 12', aFirst.idAudit == 12, '${aFirst.idAudit}');
  check('audit actorUsername == 12345', aFirst.actorUsername == '12345', aFirst.actorUsername);
  check('audit aksi update', aFirst.isUpdate, aFirst.aksi);
  check('audit entitas alat', aFirst.entitas == 'alat', aFirst.entitas);
  check('audit entitasId AC-001', aFirst.entitasId == 'AC-001', aFirst.entitasId);
  check('audit waktuTampil', aFirst.waktuTampil == '2026-07-15 09:00:00', aFirst.waktuTampil);
  check('audit detailTampil dirapikan', aFirst.detailTampil == 'merk_alat=Daikin 2PK',
      aFirst.detailTampil);
  check('audit baris delete terdeteksi', audit.data.last.isDelete);
  check('audit detail null -> "-"', audit.data.last.detailTampil == '-',
      audit.data.last.detailTampil);

  // --------------------------------------------------------------------
  section('12. USERS & ALAT (endpoint baru)');
  // --------------------------------------------------------------------
  final PagedResult<User> usersPage = PagedResult<User>.fromJson(
      fx('users_page.json')['data'] as Map<String, dynamic>, User.fromJson);
  check('users total == 2', usersPage.total == 2, '${usersPage.total}');
  check('user pertama username 67890', usersPage.data.first.username == '67890',
      usersPage.data.first.username);
  check('user pertama jumlahMaintenance == 34', usersPage.data.first.jumlahMaintenance == 34,
      '${usersPage.data.first.jumlahMaintenance}');
  check('user pertama roleTampil Teknisi', usersPage.data.first.roleTampil == 'Teknisi',
      usersPage.data.first.roleTampil);
  check('user kedua Supervisor', usersPage.data.last.isSupervisor);
  check('user lama tanpa jumlah_maintenance tetap terparse', user.jumlahMaintenance == null,
      '${user.jumlahMaintenance}');

  final Alat assigned = Alat.fromJson(fx('alat_assign.json')['data'] as Map<String, dynamic>);
  check('assign barcodeAlat AC-001', assigned.barcodeAlat == 'AC-001', assigned.barcodeAlat);
  check('assign penanggungJawab 67890', assigned.penanggungJawab == '67890',
      '${assigned.penanggungJawab}');
  check('assign namaPenanggungJawab Teknisi A', assigned.namaPenanggungJawab == 'Teknisi A',
      '${assigned.namaPenanggungJawab}');
  check('assign ditugaskan getter', assigned.ditugaskan);
  check('assign ditugaskanPada ter-parse', assigned.ditugaskanPada != null,
      '${assigned.ditugaskanPada}');
  check('alat lama tanpa penanggung_jawab tetap terparse', !ac1.ditugaskan,
      ac1.penanggungJawabTampil);

  // --------------------------------------------------------------------
  section('13. PARAMETER ABNORMAL (Supervisor/Admin)');
  // --------------------------------------------------------------------
  final List<ParameterAbnormal> abnormal =
      listOf(fx('parameter_abnormal.json')).map(ParameterAbnormal.fromJson).toList();
  check('parameter abnormal 2 item', abnormal.length == 2, 'n=${abnormal.length}');
  check('abnormal barcode PL-002', abnormal.first.barcodeAlat == 'PL-002',
      abnormal.first.barcodeAlat);
  check('abnormal namaSpesifikasi', abnormal.first.namaSpesifikasi == 'Tegangan R-N',
      abnormal.first.namaSpesifikasi);
  check('abnormal nilaiTampil "198 V"', abnormal.first.nilaiTampil == '198 V',
      abnormal.first.nilaiTampil);
  check('abnormal nilaiDenganAmbang', abnormal.first.nilaiDenganAmbang == '198 V (>=215)',
      abnormal.first.nilaiDenganAmbang);
  check('abnormal waktu ter-parse', abnormal.first.waktu != null, '${abnormal.first.waktu}');
  for (final ParameterAbnormal a in abnormal) {
    print('        ${a.barcodeAlat.padRight(9)} ${a.namaSpesifikasi.padRight(20)} '
        '${a.nilaiDenganAmbang}');
  }

  // --------------------------------------------------------------------
  print('');
  print('=' * 74);
  print('HASIL: $_ok lulus, $_fail gagal');
  print('=' * 74);
  if (_fail > 0) exit(1);
}
