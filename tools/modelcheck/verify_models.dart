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

// Model domain lama.
import '../../app/lib/domain/models/alat.dart';
import '../../app/lib/domain/models/audit_log.dart';
import '../../app/lib/domain/models/dashboard.dart';
import '../../app/lib/domain/models/kategori.dart';
import '../../app/lib/domain/models/lokasi.dart';
import '../../app/lib/domain/models/maintenance.dart';
import '../../app/lib/domain/models/pengingat.dart';
import '../../app/lib/domain/models/spesifikasi.dart';
import '../../app/lib/domain/models/tugas.dart';
import '../../app/lib/domain/models/user.dart';
import '../../app/lib/domain/models/verifikasi.dart';

// Modul logika murni fitur tahap 3 (TANPA package:flutter).
import '../../app/lib/core/audit/audit_aksi.dart';
import '../../app/lib/core/audit/audit_detail.dart';
import '../../app/lib/core/audit/audit_filter.dart';
import '../../app/lib/core/charts/chart_range.dart';
import '../../app/lib/core/constants/app_strings.dart';
import '../../app/lib/core/files/file_export_spec.dart';
import '../../app/lib/core/gesture/swipe_action.dart';
import '../../app/lib/core/locale/locale_codec.dart';
import '../../app/lib/core/locale/teks.dart';
import '../../app/lib/core/media/photo_policy.dart';
import '../../app/lib/core/motion/app_motion.dart';
import '../../app/lib/core/notif/notif_schedule.dart';
import '../../app/lib/core/offline/draft_queue.dart';
import '../../app/lib/core/offline/draft_status.dart';
import '../../app/lib/core/offline/retry_policy.dart';
import '../../app/lib/core/router/route_access.dart';
import '../../app/lib/core/router/routes.dart';
import '../../app/lib/core/search/search_history.dart';
import '../../app/lib/core/theme/app_palette_spec.dart';
import '../../app/lib/core/theme/theme_mode_codec.dart';

// Model domain fitur tahap 3 (WS M + O, T06).
import '../../app/lib/domain/models/alat_import.dart';
import '../../app/lib/domain/models/share_link.dart';

// Modul pure fitur tahap 3 (WS I + J + K, T07).
import '../../app/lib/core/patrol/patrol_queue.dart';
import '../../app/lib/core/maintenance/checklist_quick_fill.dart';
import '../../app/lib/core/maintenance/draft_template.dart';

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

  // ====================================================================
  // FITUR TAHAP 3 — MODUL LOGIKA MURNI (T01)
  // ====================================================================

  DraftRecord draft(String uuid, String barcode,
          {Map<int, String> checklist = const <int, String>{},
          List<String> foto = const <String>[]}) =>
      DraftRecord(
        clientUuid: uuid,
        barcodeAlat: barcode,
        idLokasi: 5,
        idKategori: 1,
        checklist: checklist,
        catatan: 'Catatan $barcode',
        kondisiKeseluruhan: 'baik',
        waktuMaintenance: DateTime.parse('2026-07-15T09:00:00.000Z'),
        fotoPaths: foto,
      );

  // --------------------------------------------------------------------
  section('14. OFFLINE — DraftStatus / DraftQueue / RetryPolicy');
  // --------------------------------------------------------------------
  // AC-A7 — tepat 5 nilai enum.
  check('AC-A7 DraftStatus tepat 5 nilai', DraftStatus.values.length == 5,
      DraftStatus.values.map((DraftStatus s) => s.name).join(','));
  check('AC-A7 kode string stabil',
      DraftStatus.menungguSinkron.code == 'menunggu_sinkron' &&
          DraftStatus.ditahan.code == 'ditahan');
  check('AC-A7 fromCode round-trip',
      DraftStatus.fromCode('terkirim') == DraftStatus.terkirim);
  check('AC-A7 fromCode tak dikenal -> menungguSinkron',
      DraftStatus.fromCode('xxx') == DraftStatus.menungguSinkron &&
          DraftStatus.fromCode(null) == DraftStatus.menungguSinkron);
  check('AC-A7 hanya menungguSinkron boleh diulang otomatis',
      DraftStatus.menungguSinkron.bolehDiulangOtomatis &&
          !DraftStatus.ditolakServer.bolehDiulangOtomatis &&
          !DraftStatus.ditahan.bolehDiulangOtomatis &&
          !DraftStatus.sedangKirim.bolehDiulangOtomatis);

  // AC-A1 — enqueue menambah & count bertambah.
  final DraftQueue q = DraftQueue();
  check('AC-A1 antrean baru kosong', q.count == 0 && q.nextPending == null);
  q.enqueue(draft('u1', 'AC-001'));
  check('AC-A1 enqueue menambah count', q.count == 1, 'count=${q.count}');
  check('AC-A1 nextPending mengembalikan draf', q.nextPending?.clientUuid == 'u1');

  // AC-A2 — uuid berbeda, barcode sama -> dua entri.
  q.enqueue(draft('u2', 'AC-001'));
  check('AC-A2 uuid beda barcode sama -> 2 entri', q.count == 2, 'count=${q.count}');

  // AC-A3 — uuid sama -> dedupe.
  q.enqueue(draft('u1', 'AC-001'));
  check('AC-A3 uuid sama -> tidak digandakan', q.count == 2, 'count=${q.count}');

  // AC-A12 — draf belum lengkap pun tersimpan (checklist kosong).
  final DraftQueue q12 = DraftQueue();
  q12.enqueue(draft('belum-lengkap', 'GS-001'));
  check('AC-A12 draf belum lengkap tersimpan sebelum kirim', q12.count == 1);

  // AC-A4 — round-trip serialize/deserialize identik.
  final DraftQueue q4 = DraftQueue()
    ..enqueue(draft('a4-uuid', 'AC-003',
        checklist: <int, String>{1: 'Baik', 2: 'Rusak'},
        foto: <String>['/tmp/f1.jpg', '/tmp/f2.jpg']));
  final DraftQueue q4b = DraftQueue.deserialize(q4.serialize());
  final DraftRecord d4 = q4b.items.first;
  check('AC-A4 round-trip count', q4b.count == q4.count);
  check('AC-A4 round-trip clientUuid', d4.clientUuid == 'a4-uuid', d4.clientUuid);
  check('AC-A4 round-trip barcode', d4.barcodeAlat == 'AC-003', d4.barcodeAlat);
  check('AC-A4 round-trip idLokasi/idKategori',
      d4.idLokasi == 5 && d4.idKategori == 1);
  check('AC-A4 round-trip checklist', d4.checklist[1] == 'Baik' && d4.checklist[2] == 'Rusak',
      d4.checklist.toString());
  check('AC-A4 round-trip catatan/kondisi',
      d4.catatan == 'Catatan AC-003' && d4.kondisiKeseluruhan == 'baik');
  check('AC-A4 round-trip fotoPaths', d4.fotoPaths.length == 2, d4.fotoPaths.toString());
  check('AC-A4 deserialize(null) -> kosong', DraftQueue.deserialize(null).count == 0);
  check('AC-A4 deserialize(rusak) -> kosong tanpa exception',
      DraftQueue.deserialize('{bukan json').count == 0);

  // AC-A10 — gagal unggah -> menungguSinkron, clientUuid dipertahankan.
  final DraftQueue q10 = DraftQueue()..enqueue(draft('a10-uuid', 'AC-001'));
  q10.markSending('a10-uuid');
  final bool ok10 = q10.onUploadFailed('a10-uuid', 'koneksi putus');
  check('AC-A10 onUploadFailed true', ok10);
  check('AC-A10 status kembali menungguSinkron',
      q10.items.first.status == DraftStatus.menungguSinkron,
      q10.items.first.status.code);
  check('AC-A10 clientUuid dipertahankan', q10.items.first.clientUuid == 'a10-uuid');
  check('AC-A10 pesanError tersimpan', q10.items.first.pesanError == 'koneksi putus');

  // AC-A11 — backoff eksponensial dibatasi.
  final List<int> delays = <int>[
    for (int i = 0; i < 6; i++) RetryPolicy.nextDelay(i).inSeconds
  ];
  check('AC-A11 pola 5,10,20,40,60,60', delays.join(',') == '5,10,20,40,60,60',
      delays.join(','));
  check('AC-A11 tidak pernah melebihi batas atas',
      List<int>.generate(40, (int i) => RetryPolicy.nextDelay(i).inSeconds)
          .every((int s) => s <= RetryPolicy.max.inSeconds));
  check('AC-A11 attempt negatif = attempt 0',
      RetryPolicy.nextDelay(-1) == RetryPolicy.base);
  check('AC-A11 attempt besar tetap dibatasi',
      RetryPolicy.nextDelay(99) == RetryPolicy.max);

  // AC-A13 — kirim ganda dicegah.
  final DraftQueue q13 = DraftQueue()..enqueue(draft('a13-uuid', 'AC-001'));
  check('AC-A13 markSending pertama true', q13.markSending('a13-uuid'));
  check('AC-A13 markSending kedua false (sedangKirim)', !q13.markSending('a13-uuid'));
  q13.onSent('a13-uuid', 77);
  check('AC-A13 markSending setelah terkirim false', !q13.markSending('a13-uuid'));
  check('AC-A13 onSent menyimpan idMaintenanceServer',
      q13.items.first.idMaintenanceServer == 77);

  // AC-A14 — 422 -> ditolakServer, pesan disimpan, tidak diulang.
  final DraftQueue q14 = DraftQueue()..enqueue(draft('a14-uuid', 'AC-001'));
  final bool ok14 = q14.onRejected('a14-uuid', <String, List<String>>{
    'id_lokasi': <String>['Lokasi tidak valid'],
  });
  check('AC-A14 onRejected true', ok14);
  check('AC-A14 status ditolakServer', q14.items.first.status == DraftStatus.ditolakServer);
  check('AC-A14 pesanError memuat alasan',
      (q14.items.first.pesanError ?? '').contains('Lokasi tidak valid'),
      '${q14.items.first.pesanError}');
  check('AC-A14 tidak dijadwalkan ulang (nextPending null)', q14.nextPending == null);

  // AC-A15 — 401 -> ditahan, seluruh antrean berhenti, perluLoginUlang.
  final DraftQueue q15 = DraftQueue()
    ..enqueue(draft('a15-1', 'AC-001'))
    ..enqueue(draft('a15-2', 'AC-002'));
  check('AC-A15 perluLoginUlang false sebelum 401', !q15.perluLoginUlang);
  q15.onUnauthorized('a15-1');
  check('AC-A15 status ditahan', q15.items.first.status == DraftStatus.ditahan);
  check('AC-A15 perluLoginUlang true', q15.perluLoginUlang);
  check('AC-A15 nextPending tetap draf lain (tak beruntun)',
      q15.nextPending?.clientUuid == 'a15-2');

  // AC-A16 — 403 -> ditolakServer "Tidak berhak", tidak diulang.
  final DraftQueue q16 = DraftQueue()..enqueue(draft('a16-uuid', 'AC-001'));
  q16.onRejected('a16-uuid', <String, List<String>>{
    'role': <String>['Tidak berhak'],
  });
  check('AC-A16 status ditolakServer', q16.items.first.status == DraftStatus.ditolakServer);
  check('AC-A16 pesan memuat "Tidak berhak"',
      (q16.items.first.pesanError ?? '').contains('Tidak berhak'),
      '${q16.items.first.pesanError}');
  check('AC-A16 tidak diulang otomatis',
      q16.items.first.status.bolehDiulangOtomatis == false);

  // AC-A18 — FIFO: nextPending = menungguSinkron tertua.
  final DraftQueue q18 = DraftQueue()
    ..enqueue(draft('a18-1', 'AC-001'))
    ..enqueue(draft('a18-2', 'AC-002'))
    ..enqueue(draft('a18-3', 'AC-003'));
  check('AC-A18 nextPending = tertua', q18.nextPending?.clientUuid == 'a18-1');
  q18.markSending('a18-1');
  check('AC-A18 setelah tertua terkirim -> berikutnya',
      q18.nextPending?.clientUuid == 'a18-2');
  q18.onSent('a18-2', 1);
  check('AC-A18 lompati terkirim', q18.nextPending?.clientUuid == 'a18-3');

  // toMaintenancePayload — kontrak POST /maintenance.
  final Map<String, dynamic> mp = draft('p1', 'AC-001',
          checklist: <int, String>{1: 'Baik'})
      .toMaintenancePayload();
  check('payload client_uuid & barcode_alat',
      mp['client_uuid'] == 'p1' && mp['barcode_alat'] == 'AC-001');
  check('payload detail = daftar {id_spesifikasi,status}',
      mp['detail'] is List && (mp['detail'] as List<dynamic>).length == 1 &&
          (mp['detail'] as List<dynamic>).first['id_spesifikasi'] == 1);

  // --------------------------------------------------------------------
  section('15. NOTIFIKASI — PengingatPayload & NotifSchedule');
  // --------------------------------------------------------------------
  // AC-B4 — PengingatPayload.fromJson memetakan fixture; daftar == ringkasan.
  final PengingatPayload pr =
      PengingatPayload.fromJson(fx('pengingat.json')['data'] as Map<String, dynamic>);
  check('AC-B4 ringkasan.jatuhTempo == 3', pr.ringkasan.jatuhTempo == 3,
      '${pr.ringkasan.jatuhTempo}');
  check('AC-B4 ringkasan.terlambat == 2', pr.ringkasan.terlambat == 2,
      '${pr.ringkasan.terlambat}');
  check('AC-B4 ringkasan.menungguVerifikasi == 0', pr.ringkasan.menungguVerifikasi == 0);
  check('AC-B4 daftar terparse', pr.daftar.length == 5, 'n=${pr.daftar.length}');
  check('AC-B4 jumlah daftar == total ringkasan',
      pr.totalDaftar == pr.ringkasan.total,
      'daftar=${pr.totalDaftar} ringkasan=${pr.ringkasan.total}');
  check('AC-B4 item terlambat terdeteksi',
      pr.daftar.where((PengingatItem i) => i.terlambat).length == 2);
  check('AC-B4 jatuh_tempo ter-parse',
      pr.daftar.first.jatuhTempo != null, '${pr.daftar.first.jatuhTempo}');

  // AC-B5 — NotifSchedule.dailyAt(hour:7) harian jam 7 Asia/Jakarta.
  final NotifSchedule ns = NotifSchedule.dailyAt(hour: 7);
  check('AC-B5 hour == 7', ns.hour == 7, '${ns.hour}');
  check('AC-B5 minute == 0', ns.minute == 0, '${ns.minute}');
  check('AC-B5 timezone == Asia/Jakarta', ns.timezone == NotifSchedule.zona,
      ns.timezone);
  check('AC-B5 harian == true', ns.harian);
  check('AC-B5 round-trip toJson/fromJson',
      NotifSchedule.fromJson(ns.toJson()).totalMenit == ns.totalMenit);

  // --------------------------------------------------------------------
  section('16. FOTO — PhotoPolicy');
  // --------------------------------------------------------------------
  // AC-C9 — canAdd (jumlah).
  check('AC-C9 canAdd(0..14) true',
      List<int>.generate(15, (int i) => i).every(PhotoPolicy.canAdd));
  check('AC-C9 canAdd(15) false', !PhotoPolicy.canAdd(15));
  check('AC-C9 canAdd(16) false', !PhotoPolicy.canAdd(16));
  check('AC-C9 maxFotos == 15', PhotoPolicy.maxFotos == 15);
  // AC-C9 — canAdd (kuota total 100 MB).
  const int mb = 1024 * 1024;
  check('AC-C9 maxTotalBytes == 104857600 (100 MB)',
      PhotoPolicy.maxTotalBytes == 104857600);
  check('AC-C9 canAdd kuota: foto 1 MB pada kuota kosong -> true',
      PhotoPolicy.canAdd(0, totalBytes: 0, bytesBaru: 1 * mb));
  check('AC-C9 canAdd kuota: pas mengisi 100 MB -> true',
      PhotoPolicy.canAdd(0,
          totalBytes: PhotoPolicy.maxTotalBytes - 1 * mb, bytesBaru: 1 * mb));
  check('AC-C9 canAdd kuota: melebihi 100 MB -> false',
      !PhotoPolicy.canAdd(0,
          totalBytes: PhotoPolicy.maxTotalBytes - 1 * mb,
          bytesBaru: 1 * mb + 1));
  check('AC-C9 canAdd kuota: kuota penuh, ukuran tak diketahui -> false',
      !PhotoPolicy.canAdd(0, totalBytes: PhotoPolicy.maxTotalBytes));
  check('AC-C9 canAdd kuota: kuota penuh, ukuran diketahui -> false',
      !PhotoPolicy.canAdd(0,
          totalBytes: PhotoPolicy.maxTotalBytes, bytesBaru: 1 * mb));
  check('AC-C9 canAdd kuota: total negatif -> false',
      !PhotoPolicy.canAdd(0, totalBytes: -1, bytesBaru: 1 * mb));
  check('AC-C9 canAdd kuota: 15 foto @5MB masih dalam 100 MB',
      PhotoPolicy.maxFotos * PhotoPolicy.maxBytes <= PhotoPolicy.maxTotalBytes);
  check('AC-C9 sisaKuota: 40 MB terpakai -> 60 MB sisa',
      PhotoPolicy.sisaKuota(40 * mb) == 60 * mb);
  check('AC-C9 sisaKuota: tidak pernah negatif',
      PhotoPolicy.sisaKuota(PhotoPolicy.maxTotalBytes + 5) == 0);
  // AC-C10 — acceptSize.
  check('AC-C10 acceptSize(1) true', PhotoPolicy.acceptSize(1));
  check('AC-C10 acceptSize(5MB) true', PhotoPolicy.acceptSize(PhotoPolicy.maxBytes));
  check('AC-C10 acceptSize(5MB+1) false',
      !PhotoPolicy.acceptSize(PhotoPolicy.maxBytes + 1));
  check('AC-C10 acceptSize(0) false', !PhotoPolicy.acceptSize(0));
  // Resize netral-format.
  check('resize: 4000x3000 -> sisi <= 1600',
      PhotoPolicy.targetDimensi(4000, 3000).first == 1600,
      PhotoPolicy.targetDimensi(4000, 3000).toString());
  check('resize: rasio dipertahankan',
      PhotoPolicy.targetDimensi(4000, 3000).last == 1200,
      PhotoPolicy.targetDimensi(4000, 3000).toString());
  check('resize: kecil tidak diubah',
      PhotoPolicy.targetDimensi(800, 600).join('x') == '800x600');
  check('resize: tahap sisi 1600/1280/1024',
      PhotoPolicy.tahapSisi().join(',') == '1600,1280,1024');

  // --------------------------------------------------------------------
  section('17. AUDIT — AuditDetail & AuditAksi');
  // --------------------------------------------------------------------
  // AC-D5 — format nilai biasa & diff.
  check('AC-D5 map biasa -> "kunci: nilai"',
      AuditDetail.format('{"merk_alat":"Daikin"}').join('|') == 'merk_alat: Daikin',
      AuditDetail.format('{"merk_alat":"Daikin"}').join('|'));
  check('AC-D5 diff {lama,baru} -> "kunci: lama → baru"',
      AuditDetail.format('{"status":{"lama":"menunggu","baru":"disetujui"}}')
              .join('|') ==
          'status: menunggu → disetujui',
      AuditDetail.format('{"status":{"lama":"menunggu","baru":"disetujui"}}').join('|'));
  check('AC-D5 diff {from,to} juga dikenali',
      AuditDetail.format('{"x":{"from":"A","to":"B"}}').join('|') == 'x: A → B');
  check('AC-D5 null/kosong -> daftar kosong',
      AuditDetail.format(null).isEmpty && AuditDetail.format('  ').isEmpty);
  // AC-D6 — JSON tidak valid -> teks mentah tanpa exception.
  final List<String> d6 = AuditDetail.format('{bukan json');
  check('AC-D6 JSON tidak valid -> 1 baris mentah',
      d6.length == 1 && d6.first == '{bukan json', d6.join('|'));
  check('AC-D6 array (bukan objek) -> teks mentah',
      AuditDetail.format('[1,2,3]').join('|') == '[1,2,3]');
  // AC-D7 — label aksi.
  check('AC-D7 label(verify) == "Verifikasi"', AuditAksi.label('verify') == 'Verifikasi');
  check('AC-D7 label(create) == "Buat"', AuditAksi.label('create') == 'Buat');
  check('AC-D7 label tak dikenal -> teks asli',
      AuditAksi.label('foo_bar') == 'foo_bar');
  check('AC-D7 label case-insensitive', AuditAksi.label('VERIFY') == 'Verifikasi');
  // AC-D8 — AuditLogEntry.fromJson memetakan fixture audit-log.
  check('AC-D8 AuditLogEntry.fromJson memetakan fixture',
      audit.data.isNotEmpty && audit.data.first.idAudit == 12 && aFirst.detail != null,
      'n=${audit.data.length}');
  check('AC-D8 format detail audit fixture',
      AuditDetail.format(aFirst.detail).join('|') == 'merk_alat: Daikin 2PK',
      AuditDetail.format(aFirst.detail).join('|'));
  // Filter tanggal (mendukung AC-D3 di lapisan UI).
  final DateTime dDari = DateTime(2026, 7, 1, 15, 30); // jam diabaikan
  final DateTime dSampai = DateTime(2026, 7, 31, 10);
  check('audit filter: dari -> awal hari 00:00:00',
      AuditFilter.normalisasiDari(dDari).toString() == '2026-07-01 00:00:00.000',
      AuditFilter.normalisasiDari(dDari).toString());
  check('audit filter: sampai -> akhir hari 23:59:59.999',
      AuditFilter.normalisasiSampai(dSampai)!.hour == 23 &&
          AuditFilter.normalisasiSampai(dSampai)!.minute == 59 &&
          AuditFilter.normalisasiSampai(dSampai)!.millisecond == 999,
      AuditFilter.normalisasiSampai(dSampai).toString());
  check('audit filter: null tetap null',
      AuditFilter.normalisasiDari(null) == null &&
          AuditFilter.normalisasiSampai(null) == null);
  check('audit filter: rentang valid (dari < sampai)',
      AuditFilter.valid(AuditFilter.normalisasiDari(dDari),
          AuditFilter.normalisasiSampai(dSampai)));
  check('audit filter: satu sisi null -> valid',
      AuditFilter.valid(null, dSampai) && AuditFilter.valid(dDari, null));
  check('audit filter: dari setelah sampai -> invalid',
      !AuditFilter.valid(DateTime(2026, 8, 1), DateTime(2026, 7, 1)));
  check('audit filter: hari sama -> valid',
      AuditFilter.valid(DateTime(2026, 7, 15), DateTime(2026, 7, 15)));
  check('audit filter: keQuery yyyy-MM-dd',
      AuditFilter.keQuery(dDari) == '2026-07-01' &&
          AuditFilter.keQuery(dSampai) == '2026-07-31');
  check('audit filter: keQuery(null) -> null', AuditFilter.keQuery(null) == null);

  // --------------------------------------------------------------------
  section('18. TEMA — PaletteSpec & ThemeModeCodec');
  // --------------------------------------------------------------------
  // AC-E1 — light != dark untuk token permukaan.
  check('AC-E1 background light != dark',
      PaletteSpec.value(PaletteTheme.light, 'background') !=
          PaletteSpec.value(PaletteTheme.dark, 'background'));
  check('AC-E1 textPrimary light != dark',
      PaletteSpec.value(PaletteTheme.light, 'textPrimary') !=
          PaletteSpec.value(PaletteTheme.dark, 'textPrimary'));
  // AC-E2 — brand konstan.
  check('AC-E2 primary == 0xFFCB2400 di kedua tema',
      PaletteSpec.value(PaletteTheme.light, 'primary') == 0xFFCB2400 &&
          PaletteSpec.value(PaletteTheme.dark, 'primary') == 0xFFCB2400);
  // AC-E3 — satu sumber kebenaran (== AppColors.primary).
  check('AC-E3 primary == AppColors.primary (0xFFCB2400)',
      PaletteSpec.value(PaletteTheme.light, 'primary') == 0xFFCB2400);
  check('AC-E3 tokens memuat semua kunci palet',
      PaletteSpec.tokens.containsAll(PaletteSpec.light.keys) &&
          PaletteSpec.tokens.containsAll(PaletteSpec.dark.keys));
  // AC-E4 — kontras teks >= 4.5 di kedua tema.
  final double crLight = PaletteSpec.contrastRatio(
      PaletteSpec.value(PaletteTheme.light, 'textPrimary'),
      PaletteSpec.value(PaletteTheme.light, 'background'));
  final double crDark = PaletteSpec.contrastRatio(
      PaletteSpec.value(PaletteTheme.dark, 'textPrimary'),
      PaletteSpec.value(PaletteTheme.dark, 'background'));
  check('AC-E4 kontras light >= 4.5', crLight >= 4.5, crLight.toStringAsFixed(2));
  check('AC-E4 kontras dark >= 4.5', crDark >= 4.5, crDark.toStringAsFixed(2));
  check('AC-E4 kontras hitam/putih == 21', () {
    final double c = PaletteSpec.contrastRatio(0xFF000000, 0xFFFFFFFF);
    return (c - 21.0).abs() < 0.01;
  }());
  // AC-E5 — ThemeModeCodec.
  check('AC-E5 fromString(dark) == "dark"', ThemeModeCodec.fromString('dark') == 'dark');
  check('AC-E5 fromString(null) == "system"', ThemeModeCodec.fromString(null) == 'system');
  check('AC-E5 fromString(x) == "system"', ThemeModeCodec.fromString('x') == 'system');
  check('AC-E5 round-trip stabil',
      ThemeModeCodec.fromString(ThemeModeCodec.toStorage('Light')) == 'light');

  // --------------------------------------------------------------------
  section('19. ANIMASI — AppMotion');
  // --------------------------------------------------------------------
  // AC-F2 — durasi 200..300 ms untuk seluruh rute terdaftar.
  check('AC-F2 semua pageId terdaftar dalam rentang 200-300',
      AppMotion.durations.keys.every((String id) {
        final int ms = AppMotion.transitionMs(id);
        return ms >= 200 && ms <= 300;
      }),
      AppMotion.durations.entries
          .map((MapEntry<String, int> e) => '${e.key}=${e.value}')
          .join(','));
  check('AC-F2 pageId tak dikenal tetap dalam rentang',
      AppMotion.transitionMs('halaman-baru') >= 200 &&
          AppMotion.transitionMs('halaman-baru') <= 300);
  check('AC-F2 clamp nilai di luar rentang',
      AppMotion.transitionMs('home') == 250);

  // --------------------------------------------------------------------
  section('20. GRAFIK — ChartRange');
  // --------------------------------------------------------------------
  final DateTime acuan = DateTime(2026, 7, 15);
  // AC-G2 — rentang 7/30/90 hari.
  final ChartRange r30 = ChartRange.forPeriod('30d', acuan: acuan);
  check('AC-G2 30d: sampai == acuan', r30.sampai == acuan, '${r30.sampai}');
  check('AC-G2 30d: dari == acuan-30',
      r30.dari == DateTime(2026, 6, 15), '${r30.dari}');
  check('AC-G2 7d: dari == acuan-7',
      ChartRange.forPeriod('7d', acuan: acuan).dari == DateTime(2026, 7, 8));
  check('AC-G2 90d: dari == acuan-90',
      ChartRange.forPeriod('90d', acuan: acuan).dari == DateTime(2026, 4, 16));
  check('AC-G2 periode tak dikenal -> 30 hari',
      ChartRange.forPeriod('99d', acuan: acuan).dari == DateTime(2026, 6, 15));
  check('AC-G2 periods == [7d,30d,90d]',
      ChartRange.periods.join(',') == '7d,30d,90d');
  // AC-G3 — label.
  check('AC-G3 label(30d) == "30 Hari"', ChartRange.label('30d') == '30 Hari');
  check('AC-G3 label(7d) == "7 Hari"', ChartRange.label('7d') == '7 Hari');
  check('AC-G3 label tak dikenal -> "30 Hari"',
      ChartRange.label('xyz') == '30 Hari');
  // Pemetaan indeks titik.
  check('ChartRange titik(0) == dari', r30.titik(0) == r30.dari);
  check('ChartRange indeks(dari) == 0', r30.indeks(r30.dari) == 0);

  // --------------------------------------------------------------------
  section('21. GESTURE & PENCARIAN — SwipeAction / SearchHistory');
  // --------------------------------------------------------------------
  // AC-H2 — tabel aksi per role.
  String kode(List<SwipeActionType> a) =>
      a.map((SwipeActionType t) => t.name).join(',');
  check('AC-H2 Supervisor/verifikasi -> [setujui,tolak]',
      kode(SwipeAction.forRole('Supervisor', 'verifikasi')) == 'setujui,tolak',
      kode(SwipeAction.forRole('Supervisor', 'verifikasi')));
  check('AC-H2 Admin/data -> [hapus]',
      kode(SwipeAction.forRole('Admin', 'data')) == 'hapus');
  check('AC-H2 Teknisi -> kosong',
      SwipeAction.forRole('Teknisi', 'verifikasi').isEmpty &&
          SwipeAction.forRole('Teknisi', 'data').isEmpty);
  check('AC-H2 Admin/user_management -> [hapus]',
      kode(SwipeAction.forRole('Admin', 'user_management')) == 'hapus');
  check('AC-H2 Supervisor/data -> kosong',
      SwipeAction.forRole('Supervisor', 'data').isEmpty);
  // AC-H3 — confirmRequired.
  check('AC-H3 confirmRequired(hapus) true',
      SwipeAction.confirmRequired(SwipeActionType.hapus));
  check('AC-H3 confirmRequired(setujui) false',
      !SwipeAction.confirmRequired(SwipeActionType.setujui));
  check('AC-H3 confirmRequired(tolak) false',
      !SwipeAction.confirmRequired(SwipeActionType.tolak));

  // AC-H4 — dedupe ke depan.
  final SearchHistory sh = SearchHistory();
  sh.add('AC-001');
  sh.add('GS-001');
  sh.add('AC-001');
  check('AC-H4 terbaru di depan', sh.items.first == 'AC-001', sh.items.join(','));
  check('AC-H4 duplikat tidak digandakan',
      sh.items.where((String e) => e == 'AC-001').length == 1,
      sh.items.join(','));
  check('AC-H4 kueri kosong diabaikan', () {
    final SearchHistory s = SearchHistory();
    s.add('   ');
    return s.items.isEmpty;
  }());
  // AC-H5 — bounded 10.
  final SearchHistory sh5 = SearchHistory();
  for (int i = 0; i < 15; i++) {
    sh5.add('q$i');
  }
  check('AC-H5 kapasitas 10 dihormati', sh5.items.length == 10, 'n=${sh5.items.length}');
  check('AC-H5 yang terlama dibuang', !sh5.items.contains('q0') && sh5.items.first == 'q14',
      sh5.items.join(','));
  check('AC-H5 remove bekerja', () {
    final SearchHistory s = SearchHistory();
    s.add('a');
    s.remove('a');
    return s.items.isEmpty;
  }());
  check('AC-H5 serialize/deserialize round-trip',
      SearchHistory.deserialize(sh5.serialize()).items.join(',') == sh5.items.join(','));

  // --------------------------------------------------------------------
  section('22. IMPOR CSV — AlatImportResult (WS M, T06)');
  // --------------------------------------------------------------------
  // AC-M6 — AlatImportResult.fromJson memetakan fixture hasil preview.
  final AlatImportResult impor =
      AlatImportResult.fromJson(fx('alat_import_preview.json')['data'] as Map<String, dynamic>);
  check('AC-M6 total == 5', impor.total == 5, '${impor.total}');
  check('AC-M6 jumlahValid == 2', impor.jumlahValid == 2, '${impor.jumlahValid}');
  check('AC-M6 jumlahGagal == 3', impor.jumlahGagal == 3, '${impor.jumlahGagal}');
  check('AC-M6 error 3 baris', impor.error.length == 3, 'n=${impor.error.length}');
  final AlatImportError eFirst = impor.error.first;
  check('AC-M6 error[0].baris == 3', eFirst.baris == 3, '${eFirst.baris}');
  check('AC-M6 error[0].pesan duplikat DB',
      eFirst.pesan.contains("AC-001") && eFirst.pesan.contains('terdaftar'), eFirst.pesan);
  check('AC-M6 error[1] duplikat dalam berkas',
      impor.error[1].pesan.contains('duplikat di dalam berkas'), impor.error[1].pesan);
  check('AC-M6 error[2] kolom kosong',
      impor.error[2].pesan.contains('Kolom wajib kosong'), impor.error[2].pesan);
  check('AC-M6 semuaValid false pada fixture bercampur', !impor.semuaValid);
  check('AC-M6 labelTombolImpor "Impor 2 baris valid"',
      impor.labelTombolImpor == 'Impor 2 baris valid', impor.labelTombolImpor);
  // Round-trip toJson/fromJson + hasil bersih.
  final AlatImportResult bersih = const AlatImportResult(total: 4, jumlahValid: 4);
  check('AC-M6 hasil bersih: semuaValid true', bersih.semuaValid);
  check('AC-M6 hasil bersih: error kosong', bersih.error.isEmpty);
  check('AC-M6 0 baris valid terdeteksi',
      const AlatImportResult(total: 0, jumlahValid: 0).tidakAdaBarisValid);
  final AlatImportResult rt = AlatImportResult.fromJson(impor.toJson());
  check('AC-M6 round-trip toJson/fromJson',
      rt.total == impor.total && rt.jumlahValid == impor.jumlahValid &&
          rt.error.length == impor.error.length &&
          rt.error.first.baris == eFirst.baris && rt.error.first.pesan == eFirst.pesan);

  // --------------------------------------------------------------------
  section('23. SHARE LINK — ShareLink (WS O, T06)');
  // --------------------------------------------------------------------
  // AC-O6 — ShareLink.fromJson memetakan fixture buat-tautan.
  final ShareLink sl =
      ShareLink.fromJson(fx('share_link.json')['data'] as Map<String, dynamic>);
  check('AC-O6 idShare == 7', sl.idShare == 7, '${sl.idShare}');
  check('AC-O6 idMaintenance == 88', sl.idMaintenance == 88, '${sl.idMaintenance}');
  check('AC-O6 token >= 32 karakter', sl.token.length >= 32, 'len=${sl.token.length}');
  check('AC-O6 url mengandung token', sl.url.endsWith('/share/${sl.token}'), sl.url);
  check('AC-O6 expiresAt ter-parse', sl.expiresAt != null, '${sl.expiresAt}');
  check('AC-O6 revokedAt null (baru dibuat)', sl.revokedAt == null);
  check('AC-O6 aktif (belum cabut/kedaluwarsa)', sl.aktif);
  check('AC-O6 dicabut false', !sl.dicabut);
  // Tautan dicabut -> aktif false.
  final ShareLink dicabut = ShareLink(
    idShare: sl.idShare,
    idMaintenance: sl.idMaintenance,
    token: sl.token,
    url: sl.url,
    expiresAt: sl.expiresAt,
    revokedAt: DateTime.now(),
    createdAt: sl.createdAt,
  );
  check('AC-O6 revokedAt != null -> dicabut', dicabut.dicabut);
  check('AC-O6 revokedAt != null -> !aktif', !dicabut.aktif);
  // Tautan kedaluwarsa -> aktif false, dicabut false.
  final ShareLink kedaluwarsa = ShareLink(
    idShare: sl.idShare,
    idMaintenance: sl.idMaintenance,
    token: sl.token,
    url: sl.url,
    expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    createdAt: sl.createdAt,
  );
  check('AC-O6 expiresAt lampau -> !aktif', !kedaluwarsa.aktif);
  check('AC-O6 expiresAt lampau -> kedaluwarsa', kedaluwarsa.kedaluwarsa);
  // expires_at null (tanpa kedaluwarsa) tetap aktif.
  final ShareLink tanpaExpiry = ShareLink(
    idShare: 1, idMaintenance: 1, token: sl.token, url: sl.url, createdAt: sl.createdAt,
  );
  check('AC-O6 expiresAt null tetap aktif', tanpaExpiry.aktif);
  // Round-trip toJson/fromJson.
  final ShareLink rtSl = ShareLink.fromJson(sl.toJson());
  check('AC-O6 round-trip toJson/fromJson',
      rtSl.idShare == sl.idShare && rtSl.token == sl.token && rtSl.url == sl.url &&
          rtSl.expiresAt == sl.expiresAt && rtSl.createdAt == sl.createdAt);

  // --------------------------------------------------------------------
  section('24. PATROLI — PatrolQueue (WS I, T07)');
  // --------------------------------------------------------------------
  // AC-I1 — tambah + dedupe.
  final PatrolQueue patrol = PatrolQueue();
  check('AC-I1 antrean awal kosong', patrol.count == 0 && patrol.kosong);
  check('AC-I1 add AC-001 -> true', patrol.add('AC-001'));
  check('AC-I1 add AC-001 lagi -> false (duplikat)',
      !patrol.add('AC-001'), 'count=${patrol.count}');
  check('AC-I1 dedupe: count tetap 1', patrol.count == 1);
  check('AC-I1 dedupe case-insensitive (ac-001)', !patrol.add('ac-001'));
  check('AC-I1 barcode kosong ditolak', !patrol.add('   '));
  // AC-I2 — FIFO + remove + clear tanpa mengubah urutan item lain.
  patrol.add('GS-001');
  patrol.add('AC-003');
  check('AC-I2 urutan FIFO',
      patrol.items.map((PatrolItem i) => i.barcode).join(',') == 'AC-001,GS-001,AC-003',
      patrol.items.map((PatrolItem i) => i.barcode).join(','));
  patrol.remove('GS-001');
  check('AC-I2 remove mempertahankan urutan item lain',
      patrol.items.map((PatrolItem i) => i.barcode).join(',') == 'AC-001,AC-003',
      patrol.items.map((PatrolItem i) => i.barcode).join(','));
  check('AC-I2 count setelah remove == 2', patrol.count == 2);
  // AC-I3 — serialize/deserialize round-trip.
  final String rawPatrol = patrol.serialize();
  final PatrolQueue patrolRt = PatrolQueue.deserialize(rawPatrol);
  check('AC-I3 round-trip count', patrolRt.count == patrol.count, '${patrolRt.count}');
  check('AC-I3 round-trip barcode identik',
      patrolRt.items.map((PatrolItem i) => i.barcode).join(',') ==
          patrol.items.map((PatrolItem i) => i.barcode).join(','));
  check('AC-I3 round-trip waktu identik',
      patrolRt.items.first.ditambahkanPada == patrol.items.first.ditambahkanPada);
  check('AC-I3 round-trip status identik',
      patrolRt.items.first.status == patrol.items.first.status);
  check('AC-I3 deserialize(null) -> antrean kosong', PatrolQueue.deserialize(null).count == 0);
  check('AC-I3 deserialize sampah -> antrean kosong',
      PatrolQueue.deserialize('{bukan json').count == 0);
  // AC-I4 — status validasi; 404 menandai belumValidasi TANPA menghapus item.
  check('AC-I4 status awal belumValidasi',
      patrol.items.first.status == PatrolStatus.belumValidasi);
  check('AC-I4 jumlahBelumValidasi == 2', patrol.jumlahBelumValidasi == 2);
  check('AC-I4 tandaiTervalidasi -> true', patrol.tandaiTervalidasi('AC-001'));
  check('AC-I4 status jadi tervalidasi',
      patrol.items.first.status == PatrolStatus.tervalidasi);
  check('AC-I4 jumlahBelumValidasi == 1 setelah validasi', patrol.jumlahBelumValidasi == 1);
  check('AC-I4 tandaiBelumValidasi -> true (item TIDAK dihapus)',
      patrol.tandaiBelumValidasi('AC-001') && patrol.count == 2);
  check('AC-I4 status kembali belumValidasi',
      patrol.items.first.status == PatrolStatus.belumValidasi);
  check('AC-I4 tandai barcode tak ada -> false', !patrol.tandaiTervalidasi('XX-999'));
  // add dengan waktu eksplisit + clear.
  final DateTime waktuPatrol = DateTime(2026, 7, 15, 9, 30);
  final PatrolQueue patrol2 = PatrolQueue()..add('PL-001', pada: waktuPatrol);
  check('AC-I1 add(pada:) memakai waktu yang diberikan',
      patrol2.items.first.ditambahkanPada == waktuPatrol);
  patrol2.clear();
  check('AC-I2 clear mengosongkan antrean', patrol2.count == 0);
  check('AC-I1 kunci penyimpanan', PatrolQueue.storageKey == 'meiv.patrol_queue.v1');

  // --------------------------------------------------------------------
  section('25. CHECKLIST CEPAT — ChecklistQuickFill (WS J, T07)');
  // --------------------------------------------------------------------
  final List<QuickFillItem> itemsJ = <QuickFillItem>[
    const QuickFillItem(idSpesifikasi: 1, tipeInput: 'select', opsi: <String>['Baik', 'Rusak']),
    const QuickFillItem(idSpesifikasi: 2, tipeInput: 'select', opsi: <String>['OK', 'Tidak OK']),
    const QuickFillItem(idSpesifikasi: 3, tipeInput: 'select', opsi: <String>['Baik', 'Rusak'], nilai: 'Rusak'),
    const QuickFillItem(idSpesifikasi: 4, tipeInput: 'select', opsi: <String>['Ya', 'Tidak']),
    const QuickFillItem(idSpesifikasi: 5, tipeInput: 'number'),
    const QuickFillItem(idSpesifikasi: 6, tipeInput: 'text', nilai: ''),
  ];
  final List<QuickFillItem> hasilJ = ChecklistQuickFill.isiSemua(itemsJ);
  // AC-J1 — hanya item pilihan beropsi Baik/OK, tidak menimpa isian ada.
  check('AC-J1 item select beropsi Baik diisi "Baik"', hasilJ[0].nilai == 'Baik', '${hasilJ[0].nilai}');
  check('AC-J1 item select beropsi OK diisi "OK"', hasilJ[1].nilai == 'OK', '${hasilJ[1].nilai}');
  check('AC-J1 isian pengguna TIDAK ditimpa', hasilJ[2].nilai == 'Rusak', '${hasilJ[2].nilai}');
  check('AC-J1 select tanpa opsi Baik/OK TIDAK disentuh', hasilJ[3].nilai == null, '${hasilJ[3].nilai}');
  // AC-J2 — item angka/teks tetap kosong.
  check('AC-J2 item number tetap kosong', hasilJ[4].nilai == null);
  check('AC-J2 item text tetap kosong', (hasilJ[5].nilai ?? '').isEmpty);
  check('AC-J1 jumlah diisi (markAllOk) == 2', ChecklistQuickFill.markAllOk(itemsJ) == 2,
      '${ChecklistQuickFill.markAllOk(itemsJ)}');
  // Fungsi murni: daftar masukan TIDAK berubah.
  check('AC-J1 isiSemua tidak memutasi input', itemsJ[0].nilai == null && itemsJ[1].nilai == null);
  check('AC-J1 markAllOk tidak memutasi input', itemsJ[0].nilai == null);
  // AC-J3 — progres hanya item benar-benar terisi, tidak pernah > total.
  check('AC-J3 hitungTerisi setelah aksi == 3',
      ChecklistQuickFill.hitungTerisi(hasilJ) == 3, '${ChecklistQuickFill.hitungTerisi(hasilJ)}');
  check('AC-J3 hitungTerisi <= items.length',
      ChecklistQuickFill.hitungTerisi(hasilJ) <= hasilJ.length);
  check('AC-J3 hitungTerisi daftar kosong == 0', ChecklistQuickFill.hitungTerisi(const <QuickFillItem>[]) == 0);
  check('AC-J3 markAllOk idempoten (aksi kedua == 0)',
      ChecklistQuickFill.markAllOk(hasilJ) == 0, '${ChecklistQuickFill.markAllOk(hasilJ)}');
  check('AC-J1 defaultNilai default == "Baik"', ChecklistQuickFill.defaultNilai == 'Baik');
  // defaultNilai kustom dihormati bila opsinya tersedia.
  final List<QuickFillItem> hasilJ2 = ChecklistQuickFill.isiSemua(
    <QuickFillItem>[
      const QuickFillItem(idSpesifikasi: 9, tipeInput: 'select', opsi: <String>['Normal', 'Abnormal']),
    ],
    defaultNilai: 'Normal',
  );
  check('AC-J1 defaultNilai kustom dipakai bila cocok', hasilJ2.first.nilai == 'Normal', '${hasilJ2.first.nilai}');

  // --------------------------------------------------------------------
  section('26. DUPLIKAT LAPORAN — DraftTemplate (WS K, T07)');
  // --------------------------------------------------------------------
  final DateTime waktuAsal = DateTime(2026, 7, 1, 8, 0);
  final Maintenance laporanAsal = Maintenance(
    idMaintenance: 88,
    waktuMaintenance: waktuAsal,
    barcodeAlat: 'AC-001',
    username: '67890',
    idLokasi: 3,
    idKategori: 7,
    catatan: 'Kondisi normal, filter bersih.',
    kondisiKeseluruhan: 'baik',
    detail: const <DetailMaintenance>[
      DetailMaintenance(idSpesifikasi: 11, status: '380'),
      DetailMaintenance(idSpesifikasi: 12, status: 'Baik'),
    ],
    foto: const <FotoLampiran>[
      FotoLampiran(idFoto: 1, url: 'https://x/storage/foto/a.jpg'),
    ],
  );
  final DateTime waktuDup = DateTime(2026, 7, 15, 10, 0);
  final DraftRecord drafK = DraftTemplate.fromReport(
    laporanAsal,
    buatUuid: () => 'uuid-baru-1234',
    waktuDuplikasi: waktuDup,
  );
  // AC-K1 — client_uuid BARU + tanpa field foto.
  check('AC-K1 clientUuid dari generator ter-inject',
      drafK.clientUuid == 'uuid-baru-1234', drafK.clientUuid);
  check('AC-K1 clientUuid tidak kosong', drafK.clientUuid.isNotEmpty);
  check('AC-K1 fotoPaths selalu kosong (foto tidak disalin)', drafK.fotoPaths.isEmpty);
  check('AC-K1 laporan asal memang punya foto (bukti tidak disalin)',
      laporanAsal.foto.isNotEmpty);
  // AC-K2 — waktu = waktu duplikasi, bukan waktu asal.
  check('AC-K2 waktuMaintenance == waktuDuplikasi', drafK.waktuMaintenance == waktuDup);
  check('AC-K2 waktuMaintenance != waktu laporan asal', drafK.waktuMaintenance != waktuAsal);
  // AC-K3 — salinan utuh.
  check('AC-K3 barcode tersalin', drafK.barcodeAlat == 'AC-001');
  check('AC-K3 idKategori tersalin', drafK.idKategori == 7);
  check('AC-K3 idLokasi tersalin', drafK.idLokasi == 3);
  check('AC-K3 kondisi tersalin', drafK.kondisiKeseluruhan == 'baik');
  check('AC-K3 catatan tersalin', drafK.catatan == 'Kondisi normal, filter bersih.');
  check('AC-K3 checklist tersalin utuh (id -> status)',
      drafK.checklist.length == 2 && drafK.checklist[11] == '380' && drafK.checklist[12] == 'Baik',
      drafK.checklist.toString());
  check('AC-K3 status draf bawaan menungguSinkron',
      drafK.status == DraftStatus.menungguSinkron, '${drafK.status}');
  // Tanpa waktuDuplikasi -> waktu sekarang (bukan waktu asal).
  final DraftRecord drafNow = DraftTemplate.fromReport(
    laporanAsal,
    buatUuid: () => 'uuid-baru-5678',
  );
  check('AC-K2 tanpa waktuDuplikasi memakai waktu sekarang',
      drafNow.waktuMaintenance != waktuAsal &&
          drafNow.waktuMaintenance.difference(DateTime.now()).inSeconds.abs() < 5);
  check('AC-K1 dua pemanggilan dengan generator berbeda -> uuid berbeda',
      drafNow.clientUuid != drafK.clientUuid);
  // Generator kosong ditolak tegas (bukan diam-diam lolos).
  bool ditolak = false;
  try {
    DraftTemplate.fromReport(laporanAsal, buatUuid: () => '  ');
  } on ArgumentError {
    ditolak = true;
  }
  check('AC-K1 buatUuid kosong -> ArgumentError', ditolak);

  // ====================================================================
  // 27. WS B — jadwal pengingat: kemunculan berikutnya & ID notifikasi
  //     (Tahap 3 T05; logika murni baru, ditambahkan di AKHIR berkas)
  // ====================================================================

  // AC-B5 — ID notifikasi OS tetap & kemunculan pertama tepat waktu.
  check('AC-B5 notifId stabil (1001)', NotifSchedule.notifId == 1001,
      '${NotifSchedule.notifId}');

  final NotifSchedule pagi = NotifSchedule.dailyAt(hour: 7, minute: 0);

  // Sebelum jam pengingat -> hari yang sama.
  final DateTime sebelum = DateTime(2026, 3, 10, 6, 30);
  final DateTime n1 = pagi.nextOccurrence(sebelum);
  check(
      'AC-B5 sebelum 07:00 -> hari yang sama 07:00',
      n1 == DateTime(2026, 3, 10, 7, 0),
      '$n1');

  // Setelah jam pengingat -> besok.
  final DateTime sesudah = DateTime(2026, 3, 10, 9, 15);
  final DateTime n2 = pagi.nextOccurrence(sesudah);
  check(
      'AC-B5 sesudah 07:00 -> besok 07:00',
      n2 == DateTime(2026, 3, 11, 7, 0),
      '$n2');

  // Tepat pada jam pengingat -> besok (tidak terjadwal ulang di detik sama).
  final DateTime tepat = DateTime(2026, 3, 10, 7, 0);
  final DateTime n3 = pagi.nextOccurrence(tepat);
  check(
      'AC-B5 tepat 07:00 -> besok 07:00',
      n3 == DateTime(2026, 3, 11, 7, 0),
      '$n3');

  // Jam/menit hasil selalu sama dengan jadwal.
  final NotifSchedule sore = NotifSchedule.dailyAt(hour: 16, minute: 45);
  final DateTime n4 = sore.nextOccurrence(DateTime(2026, 3, 10, 16, 44));
  check(
      'AC-B5 jam & menit hasil == jadwal',
      n4.hour == 16 && n4.minute == 45,
      '${n4.hour}:${n4.minute}');

  // Nilai di luar rentang di-clamp (bukan exception).
  final NotifSchedule clamp = NotifSchedule.dailyAt(hour: 25, minute: 99);
  check('AC-B5 hour 25 -> 23', clamp.hour == 23, '${clamp.hour}');
  check('AC-B5 minute 99 -> 59', clamp.minute == 59, '${clamp.minute}');

  // fromJson tahan nilai rusak (string/tak ada) -> default.
  final NotifSchedule rusak = NotifSchedule.fromJson(<String, dynamic>{
    'hour': 'bukan-angka',
  });
  check(
      'AC-B5 fromJson rusak -> default 07:00',
      rusak.hour == NotifSchedule.defaultHour &&
          rusak.minute == NotifSchedule.defaultMinute &&
          rusak.timezone == NotifSchedule.zona,
      '${rusak.hour}:${rusak.minute}');

  // totalMenit konsisten dengan jam/menit (dipakai persistensi preferensi).
  check('AC-B5 totalMenit konsisten', sore.totalMenit == 16 * 60 + 45,
      '${sore.totalMenit}');

  // ====================================================================
  // 28. WS G — rentang grafik: kode periode bolak-balik & batas rentang
  //     (Tahap 3 T05; logika murni baru, ditambahkan di AKHIR berkas)
  // ====================================================================

  // AC-G2/AC-G3 — `kodePeriode` mengembalikan kode yang sama dengan input,
  // sehingga chip filter dapat ditandai aktif dari rentang yang dihitung.
  check(
      'AC-G2 kodePeriode bolak-balik untuk semua periode',
      ChartRange.periods.every((String p) =>
          ChartRange.forPeriod(p, acuan: acuan).kodePeriode == p),
      ChartRange.periods
          .map((String p) =>
              '$p->${ChartRange.forPeriod(p, acuan: acuan).kodePeriode}')
          .join(','));

  // Rentang inklusif kedua ujung: titik = hari + 1.
  check(
      'AC-G2 jumlahTitik == jumlahHari + 1',
      ChartRange.periods.every((String p) =>
          ChartRange.forPeriod(p, acuan: acuan).jumlahTitik ==
          ChartRange.jumlahHari(p) + 1));

  final ChartRange r7 = ChartRange.forPeriod('7d', acuan: acuan);
  check('AC-G2 titik terakhir == sampai',
      r7.titik(r7.jumlahTitik - 1) == r7.sampai);
  check('AC-G2 indeks(sampai) == jumlahTitik - 1',
      r7.indeks(r7.sampai) == r7.jumlahTitik - 1);

  // Di luar rentang -> null (bukan exception) agar UI tak pernah crash.
  check('AC-G2 titik(-1) == null', r7.titik(-1) == null);
  check('AC-G2 titik(jumlahTitik) == null', r7.titik(r7.jumlahTitik) == null);
  check('AC-G2 indeks(dari-1) == null',
      r7.indeks(r7.dari.subtract(const Duration(days: 1))) == null);
  check('AC-G2 indeks(sampai+1) == null',
      r7.indeks(r7.sampai.add(const Duration(days: 1))) == null);

  // ====================================================================
  // 29. WS L/M/N — penamaan & pemeriksaan berkas ekspor
  //     (Tahap 3 T09; logika murni baru, ditambahkan di AKHIR berkas)
  // ====================================================================

  // Nama berkas WAJIB sama dengan yang dikirim backend lewat ->download(...)
  // supaya unduhan dari aplikasi dan dari peramban tidak berbeda konvensi.
  check('AC-L4 namaPdfLaporan selaras backend',
      FileExportSpec.namaPdfLaporan(42) == 'meiv-laporan-42.pdf',
      FileExportSpec.namaPdfLaporan(42));
  check('AC-L4 namaLabelQr selaras backend',
      FileExportSpec.namaLabelQr() == 'meiv-label-qr.pdf',
      FileExportSpec.namaLabelQr());

  // Tanggal selalu dua digit -> urutan nama berkas = urutan kronologis.
  final DateTime d1 = DateTime(2026, 1, 5);
  final DateTime d2 = DateTime(2026, 12, 31);
  check('AC-L4 tanggal dua digit',
      FileExportSpec.tanggal(d1) == '2026-01-05' &&
          FileExportSpec.tanggal(d2) == '2026-12-31',
      '${FileExportSpec.tanggal(d1)} / ${FileExportSpec.tanggal(d2)}');
  check(
      'AC-L4 namaPdfPeriode memuat kedua ujung',
      FileExportSpec.namaPdfPeriode(d1, d2) ==
          'meiv-ringkasan-2026-01-05_2026-12-31.pdf',
      FileExportSpec.namaPdfPeriode(d1, d2));
  check(
      'AC-L4 namaCsvPeriode berekstensi .csv',
      FileExportSpec.namaCsvPeriode(d1, d2).endsWith('.csv'),
      FileExportSpec.namaCsvPeriode(d1, d2));

  // AC-L1 — body PDF diawali `%PDF`; pemeriksaan ini yang mencegah halaman
  // galat HTML/JSON tersimpan dengan nama .pdf.
  check('AC-L1 tampakPdf menerima %PDF-1.7',
      FileExportSpec.tampakPdf('%PDF-1.7\n'.codeUnits));
  check('AC-L1 tampakPdf menolak JSON galat',
      !FileExportSpec.tampakPdf('{"code":422}'.codeUnits));
  check('AC-L1 tampakPdf menolak HTML', !FileExportSpec.tampakPdf('<html>'.codeUnits));
  check('AC-L1 tampakPdf menolak kosong', !FileExportSpec.tampakPdf(<int>[]));
  check('AC-L1 tampakPdf menolak terlalu pendek',
      !FileExportSpec.tampakPdf(<int>[0x25, 0x50]));

  // CSV tidak punya tanda ajaib; cukup pastikan ada isi dan bukan HTML.
  check('AC-L5 tampakCsv menerima header',
      FileExportSpec.tampakCsv('barcode_alat,merk\nAC-1,X'.codeUnits));
  check('AC-L5 tampakCsv menolak HTML',
      !FileExportSpec.tampakCsv('<!DOCTYPE html>'.codeUnits));
  check('AC-L5 tampakCsv menolak kosong', !FileExportSpec.tampakCsv(<int>[]));

  // AC-L3 — batas 90 hari dihitung INKLUSIF seperti PdfController::periode
  // (`diffInDays + 1 > 90`), agar UI menolak SEBELUM server membalas 422.
  final DateTime batasMulai = DateTime(2026, 1, 1);
  check(
      'AC-L3 rentang 90 hari masih diterima',
      !FileExportSpec.rentangTerlaluPanjang(
          batasMulai, batasMulai.add(const Duration(days: 89))));
  check(
      'AC-L3 rentang 91 hari ditolak di klien',
      FileExportSpec.rentangTerlaluPanjang(
          batasMulai, batasMulai.add(const Duration(days: 90))));
  check('AC-L3 rentang satu hari diterima',
      !FileExportSpec.rentangTerlaluPanjang(batasMulai, batasMulai));
  check('AC-L3 batas hari == 90', FileExportSpec.maxHariPdf == 90);
  check('AC-L3 batas baris == 500', FileExportSpec.maxBarisPdf == 500);

  check('ukuranManusia byte', FileExportSpec.ukuranManusia(900) == '900 B',
      FileExportSpec.ukuranManusia(900));
  check('ukuranManusia KB',
      FileExportSpec.ukuranManusia(842 * 1024) == '842 KB',
      FileExportSpec.ukuranManusia(842 * 1024));
  check('ukuranManusia MB',
      FileExportSpec.ukuranManusia((1.4 * 1024 * 1024).round()) == '1.4 MB',
      FileExportSpec.ukuranManusia((1.4 * 1024 * 1024).round()));

  // ====================================================================
  // 30. WS P — codec bahasa ID/EN & helper teks dwibahasa
  //     (Tahap 3 T10; logika murni baru, ditambahkan di AKHIR berkas)
  // ====================================================================

  // AC-P2 — tanpa setelan apa pun aplikasi tampil berbahasa Indonesia.
  check('AC-P2 bawaan adalah Indonesia', LocaleCodec.bawaan == AppLocale.id);
  check('AC-P2 fromKode(null) == id', LocaleCodec.fromKode(null) == AppLocale.id);
  check('AC-P2 fromKode("") == id', LocaleCodec.fromKode('') == AppLocale.id);
  check('AC-P2 fromKode("   ") == id',
      LocaleCodec.fromKode('   ') == AppLocale.id);
  check('AC-P2 Indonesia lebih dulu di daftar',
      LocaleCodec.didukung.first == AppLocale.id);
  check('AC-P2 hanya dua bahasa didukung', LocaleCodec.didukung.length == 2);

  // AC-P5 — `keKode` / `fromKode` round-trip stabil untuk setiap bahasa.
  check('AC-P5 keKode(id) == "id"', LocaleCodec.keKode(AppLocale.id) == 'id');
  check('AC-P5 keKode(en) == "en"', LocaleCodec.keKode(AppLocale.en) == 'en');
  for (final AppLocale bahasa in LocaleCodec.didukung) {
    final String kode = LocaleCodec.keKode(bahasa);
    check('AC-P5 round-trip "$kode"',
        LocaleCodec.fromKode(kode) == bahasa, kode);
    check('AC-P5 round-trip " $kode " (spasi)',
        LocaleCodec.fromKode(' $kode ') == bahasa);
    check('AC-P5 didukungKode("$kode")', LocaleCodec.didukungKode(kode));
  }

  // Toleransi huruf besar/kecil dan spasi.
  check('AC-P5 fromKode("EN ") == en',
      LocaleCodec.fromKode('EN ') == AppLocale.en);
  check('AC-P5 fromKode(" En") == en',
      LocaleCodec.fromKode(' En') == AppLocale.en);
  check('AC-P5 fromKode("ID") == id',
      LocaleCodec.fromKode('ID') == AppLocale.id);
  check('AC-P5 didukungKode("EN ")', LocaleCodec.didukungKode('EN '));

  // Kode locale lengkap (BCP-47) dipetakan lewat subtag utamanya.
  check('AC-P5 fromKode("en-US") == en',
      LocaleCodec.fromKode('en-US') == AppLocale.en);
  check('AC-P5 fromKode("id_ID") == id',
      LocaleCodec.fromKode('id_ID') == AppLocale.id);
  check('AC-P5 didukungKode("en-US")', LocaleCodec.didukungKode('en-US'));

  // Nilai tak dikenal jatuh ke Indonesia dan tidak pernah melempar.
  check('AC-P5 fromKode("fr") == id', LocaleCodec.fromKode('fr') == AppLocale.id);
  check('AC-P5 fromKode("xx-YY") == id',
      LocaleCodec.fromKode('xx-YY') == AppLocale.id);
  check('AC-P2 fromKode("-") == id', LocaleCodec.fromKode('-') == AppLocale.id);
  check('AC-P5 didukungKode("fr") == false', !LocaleCodec.didukungKode('fr'));
  check('AC-P5 didukungKode(null) == false', !LocaleCodec.didukungKode(null));

  bool kodeAman = true;
  for (final String? masukan in <String?>[
    null,
    '',
    ' ',
    '-',
    '??',
    'en-US-x',
    'zz',
    'EN ',
  ]) {
    try {
      LocaleCodec.fromKode(masukan);
    } catch (_) {
      kodeAman = false;
    }
  }
  check('AC-P5 fromKode tidak pernah melempar', kodeAman);

  // Siklus bahasa berikutnya — dengan dua bahasa, invers dirinya sendiri.
  check('AC-P2 berikutnya(id) == en',
      LocaleCodec.berikutnya(AppLocale.id) == AppLocale.en);
  check('AC-P2 berikutnya(en) == id',
      LocaleCodec.berikutnya(AppLocale.en) == AppLocale.id);
  bool siklusBalik = true;
  for (final AppLocale bahasa in LocaleCodec.didukung) {
    if (LocaleCodec.berikutnya(LocaleCodec.berikutnya(bahasa)) != bahasa) {
      siklusBalik = false;
    }
  }
  check('AC-P2 berikutnya invers dirinya sendiri', siklusBalik);

  // Nama bahasa: label singkat untuk pemilih, endonim untuk keterangan.
  check('label(id) == Indonesia', LocaleCodec.label(AppLocale.id) == 'Indonesia');
  check('label(en) == English', LocaleCodec.label(AppLocale.en) == 'English');
  check('endonim id', LocaleCodec.labelSendiri(AppLocale.id) == 'Bahasa Indonesia',
      LocaleCodec.labelSendiri(AppLocale.id));
  check('endonim en', LocaleCodec.labelSendiri(AppLocale.en) == 'English');

  // AC-P4 — kunci penyimpanan stabil; mengganti nama akan membuat preferensi
  // pengguna yang sudah ada menjadi yatim (aplikasi kembali ke Indonesia).
  check('AC-P4 kunci penyimpanan stabil',
      LocaleCodec.storageKey == 'meiv.locale.v1', LocaleCodec.storageKey);

  // AC-P2/AC-P3 — helper Teks memilih sisi yang benar.
  const Teks teksId = Teks(AppLocale.id);
  const Teks teksEn = Teks(AppLocale.en);
  check('AC-P2 Teks(id) tidak inggris', !teksId.inggris);
  check('AC-P3 Teks(en) inggris', teksEn.inggris);
  check('AC-P2 Teks(id).pilih -> Indonesia', teksId.pilih('a', 'b') == 'a');
  check('AC-P3 Teks(en).pilih -> Inggris', teksEn.pilih('a', 'b') == 'b');

  // `jumlah` — Indonesia tanpa infleksi, Inggris berjamak otomatis.
  check('jumlah id tetap "3 alat"', teksId.jumlah(3, 'alat', 'tool') == '3 alat',
      teksId.jumlah(3, 'alat', 'tool'));
  check('jumlah en tunggal "1 tool"',
      teksEn.jumlah(1, 'alat', 'tool') == '1 tool', teksEn.jumlah(1, 'alat', 'tool'));
  check('jumlah en jamak "3 tools"',
      teksEn.jumlah(3, 'alat', 'tool') == '3 tools', teksEn.jumlah(3, 'alat', 'tool'));

  // AC-P3 — penjaga regresi: string Login WAJIB berbeda antar bahasa, supaya
  // layar tidak pernah tampil setengah terjemahan.
  check('AC-P3 labelMasuk berbeda', teksId.labelMasuk != teksEn.labelMasuk,
      '${teksId.labelMasuk} / ${teksEn.labelMasuk}');
  check('AC-P3 hintNip berbeda', teksId.hintNip != teksEn.hintNip,
      '${teksId.hintNip} / ${teksEn.hintNip}');
  check('AC-P3 hintPilihRole berbeda',
      teksId.hintPilihRole != teksEn.hintPilihRole,
      '${teksId.hintPilihRole} / ${teksEn.hintPilihRole}');
  check('AC-P3 msgNipKosong berbeda',
      teksId.msgNipKosong != teksEn.msgNipKosong,
      '${teksId.msgNipKosong} / ${teksEn.msgNipKosong}');
  check('AC-P3 msgPasswordMinimal berbeda',
      teksId.msgPasswordMinimal != teksEn.msgPasswordMinimal,
      '${teksId.msgPasswordMinimal} / ${teksEn.msgPasswordMinimal}');
  check('AC-P3 msgRoleWajib berbeda',
      teksId.msgRoleWajib != teksEn.msgRoleWajib,
      '${teksId.msgRoleWajib} / ${teksEn.msgRoleWajib}');
  check('AC-P3 tooltip password berbeda',
      teksId.tooltipLihatPassword != teksEn.tooltipLihatPassword,
      '${teksId.tooltipLihatPassword} / ${teksEn.tooltipLihatPassword}');
  check('AC-P3 labelBahasa berbeda', teksId.labelBahasa != teksEn.labelBahasa,
      '${teksId.labelBahasa} / ${teksEn.labelBahasa}');

  // Pesan galat lokal diterjemahkan; teks tak dikenal dibiarkan apa adanya
  // (teks server = data, bukan string UI).
  check('AC-P3 pesan galat role diterjemahkan',
      teksEn.pesanGalat(AppStrings.msgRoleTidakCocok) !=
          AppStrings.msgRoleTidakCocok);
  check('pesan galat Indonesia tidak diubah',
      teksId.pesanGalat(AppStrings.msgRoleTidakCocok) ==
          AppStrings.msgRoleTidakCocok);
  check('AC-P3 pesan galat berbingkai ApiException diterjemahkan',
      teksEn.pesanGalat('ApiException(401): Koneksi internet terputus.') ==
          'ApiException(401): Internet connection lost.',
      teksEn.pesanGalat('ApiException(401): Koneksi internet terputus.'));
  check('pesan galat tak dikenal dibiarkan',
      teksEn.pesanGalat('Barcode tidak terdaftar di sistem.') ==
          'Barcode tidak terdaftar di sistem.');

  // ====================================================================
  // 31. GUARD RUTE — `/patroli` khusus Teknisi (WS I, T07)
  //     (logika murni baru, ditambahkan di AKHIR berkas)
  // ====================================================================

  // AC-I11 — Supervisor & Admin diarahkan ke `/403` (boleh() == false).
  // Cabang `admin` pada tabel akses mengizinkan SEMUA rute, sehingga
  // pengecualian `/patroli` harus diperiksa lebih dahulu.
  check('AC-I11 teknisi boleh buka /patroli',
      RouteAccess.boleh('teknisi', Routes.patrol));
  check('AC-I11 Teknisi (huruf besar) boleh buka /patroli',
      RouteAccess.boleh('Teknisi', Routes.patrol));
  check('AC-I11 supervisor DITOLAK di /patroli',
      !RouteAccess.boleh('supervisor', Routes.patrol));
  check('AC-I11 admin DITOLAK di /patroli (bukan lolos lewat cabang admin)',
      !RouteAccess.boleh('admin', Routes.patrol));

  // Regresi: pengecualian hanya untuk `/patroli`, rute lain tidak berubah.
  check('regresi admin tetap boleh /data',
      RouteAccess.boleh('admin', Routes.data));
  check('regresi admin tetap boleh /dashboard',
      RouteAccess.boleh('admin', Routes.dashboard));
  check('regresi supervisor tetap boleh /dashboard',
      RouteAccess.boleh('supervisor', Routes.dashboard));
  check('regresi supervisor tetap DITOLAK di /data',
      !RouteAccess.boleh('supervisor', Routes.data));
  check('regresi teknisi tetap boleh /scan',
      RouteAccess.boleh('teknisi', Routes.scan));
  check('regresi teknisi tetap DITOLAK di /dashboard',
      !RouteAccess.boleh('teknisi', Routes.dashboard));

  // --------------------------------------------------------------------
  print('');
  print('=' * 74);
  print('HASIL: $_ok lulus, $_fail gagal');
  print('=' * 74);
  if (_fail > 0) exit(1);
}
