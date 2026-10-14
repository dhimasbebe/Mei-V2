// Uji kontrak model Flutter terhadap respons API Laravel yang ASLI.
//
// Fixture di test/fixtures/*.json direkam dari server Laravel yang berjalan
// (lihat backend/tools/capture_fixtures.py). Jadi uji ini membuktikan
// kontrak Laravel <-> Dart benar-benar cocok, bukan sekadar JSON karangan.
//
// Untuk merekam ulang fixture setelah backend berubah:
//   cd backend && php artisan serve --host=127.0.0.1 --port=8123
//   python tools/capture_fixtures.py
//
// Versi jalur-cepat (tanpa Flutter) dari uji yang sama ada di
// tools/modelcheck/verify_models.dart dan bisa dijalankan dengan `dart run`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mei_v/domain/models/alat.dart';
import 'package:mei_v/domain/models/audit_log.dart';
import 'package:mei_v/domain/models/dashboard.dart';
import 'package:mei_v/domain/models/kategori.dart';
import 'package:mei_v/domain/models/lokasi.dart';
import 'package:mei_v/domain/models/maintenance.dart';
import 'package:mei_v/domain/models/spesifikasi.dart';
import 'package:mei_v/domain/models/tugas.dart';
import 'package:mei_v/domain/models/user.dart';
import 'package:mei_v/domain/models/verifikasi.dart';

Map<String, dynamic> fx(String name) {
  final File f = File('test/fixtures/$name');
  if (!f.existsSync()) {
    fail('Fixture tidak ada: ${f.path}\n'
        'Rekam ulang dengan: cd backend && php artisan serve '
        'lalu python tools/capture_fixtures.py');
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

List<Map<String, dynamic>> listOf(Map<String, dynamic> env) =>
    (env['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

void main() {
  group('Envelope & User', () {
    test('login mengembalikan envelope {code, data, message}', () {
      final Map<String, dynamic> login = fx('login.json');
      expect(login['code'], 200);
      expect(login.keys, containsAll(<String>['code', 'data', 'message']));
    });

    test('User.fromJson membaca profil', () {
      final Map<String, dynamic> login = fx('login.json');
      final User user = User.fromJson(
          (login['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>);

      expect(user.username, '12345');
      expect(user.namaUsers, 'Admin Mei-V');
      expect(user.roleUsers, 'Admin');
      expect(user.emailUsers, 'admin@meiv.test');
      expect(user.isAdmin, isTrue);
      expect(user.inisial, 'AM');
    });
  });

  group('Kategori', () {
    test('7 kategori dengan jumlah_alat', () {
      final List<Kategori> kats = listOf(fx('kategori.json')).map(Kategori.fromJson).toList();

      expect(kats, hasLength(7));
      expect(kats.fold<int>(0, (int a, Kategori k) => a + (k.jumlahAlat ?? 0)), 21);
      expect(kats.every((Kategori k) => k.iconAsset != null && k.iconAsset!.isNotEmpty), isTrue);
    });

    test('AC punya siklus 30 hari, Penangkal Petir 90 hari', () {
      final List<Kategori> kats = listOf(fx('kategori.json')).map(Kategori.fromJson).toList();

      expect(kats.firstWhere((Kategori k) => k.nama == 'AC').maintenanceCycleDays, 30);
      expect(kats.firstWhere((Kategori k) => k.nama == 'Penangkal Petir').maintenanceCycleDays, 90);
    });
  });

  group('Spesifikasi (checklist dinamis)', () {
    test('jumlah item per kategori sesuai', () {
      expect(listOf(fx('spesifikasi_ac.json')), hasLength(8));
      expect(listOf(fx('spesifikasi_genset.json')), hasLength(7));
    });

    test('id_spesifikasi unik lintas kategori (bug collision versi lama)', () {
      final List<Spesifikasi> a =
          listOf(fx('spesifikasi_ac.json')).map(Spesifikasi.fromJson).toList();
      final List<Spesifikasi> g =
          listOf(fx('spesifikasi_genset.json')).map(Spesifikasi.fromJson).toList();

      final Set<int> ids = <int>{
        ...a.map((Spesifikasi s) => s.idSpesifikasi),
        ...g.map((Spesifikasi s) => s.idSpesifikasi),
      };
      expect(ids, hasLength(a.length + g.length));
      expect(a.every((Spesifikasi s) => s.idKategori == 1), isTrue);
      expect(g.every((Spesifikasi s) => s.idKategori == 7), isTrue);
    });

    test('opsi dipecah dari tanda pipe', () {
      final List<Spesifikasi> a =
          listOf(fx('spesifikasi_ac.json')).map(Spesifikasi.fromJson).toList();
      final Spesifikasi sel = a.firstWhere((Spesifikasi s) => s.tipeInput == 'select');

      expect(sel.opsi, <String>['Bersih', 'Tidak']);
    });
  });

  group('Alat (kolom datar hasil join)', () {
    test('21 alat, semua kolom datar terisi', () {
      final List<Alat> alats = listOf(fx('alat_list.json')).map(Alat.fromJson).toList();

      expect(alats, hasLength(21));
      expect(alats.every((Alat a) => (a.namaKategori ?? '').isNotEmpty), isTrue);
      expect(alats.every((Alat a) => (a.namaLokasi ?? '').isNotEmpty), isTrue);
      expect(alats.every((Alat a) => a.lantai != null), isTrue);
      expect(alats.every((Alat a) => a.siklusHari > 0), isTrue);
    });

    test('AC-001 terbaca lengkap', () {
      final Alat ac1 = Alat.fromJson(fx('alat_ac001.json')['data'] as Map<String, dynamic>);

      expect(ac1.barcodeAlat, 'AC-001');
      expect(ac1.namaKategori, 'AC');
      expect(ac1.namaLokasi, 'Aula Besar');
      expect(ac1.lantai, 7);
      expect(ac1.siklusHari, 30);
      expect(ac1.terakhirMaintenance, isNotNull);
      expect(ac1.detailLokasi, 'Aula Besar Lantai 7');
      expect(ac1.deskripsiKategori, isNotEmpty);
    });

    test('AC-003 belum pernah dipelihara -> overdue', () {
      final Alat ac3 = Alat.fromJson(fx('alat_ac003.json')['data'] as Map<String, dynamic>);

      expect(ac3.terakhirMaintenance, isNull);
      expect(ac3.umurHari, isNull);
      expect(ac3.overdue, isTrue);
    });
  });

  group('Lokasi', () {
    test('8 lokasi dengan jumlah_alat dan label', () {
      final List<Lokasi> loks = listOf(fx('lokasi.json')).map(Lokasi.fromJson).toList();

      expect(loks, hasLength(8));
      expect(loks.fold<int>(0, (int a, Lokasi l) => a + (l.jumlahAlat ?? 0)), 21);

      final Lokasi basement = loks.firstWhere((Lokasi l) => l.namaLokasi == 'Basement');
      expect(basement.lantai, -1);
      expect(basement.label, 'Basement Lantai -1');
      expect(loks.firstWhere((Lokasi l) => l.namaLokasi == 'Ruang ME').label, 'Ruang ME Lantai 7');
    });
  });

  group('Dashboard', () {
    test('KPI ter-parse', () {
      final DashboardKpi kpi =
          DashboardKpi.fromJson(fx('dashboard_kpi.json')['data'] as Map<String, dynamic>);

      expect(kpi.totalAlat, 21);
      expect(kpi.totalKategori, 7);
      expect(kpi.alatOverdue, greaterThan(0));
      expect(kpi.persenTepatWaktu, greaterThan(0));
      expect(kpi.rataRataIntervalHari, isNotNull);
    });

    test('tren mengisi semua hari (tanpa lubang)', () {
      final List<TrendPoint> t =
          listOf(fx('dashboard_trends.json')).map(TrendPoint.fromJson).toList();

      expect(t, hasLength(7));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t.first.label), isTrue);
    });

    test('distribusi 7 kategori dengan icon_asset', () {
      final List<DistributionItem> d =
          listOf(fx('dashboard_distribution.json')).map(DistributionItem.fromJson).toList();

      expect(d, hasLength(7));
      expect(d.every((DistributionItem x) => (x.iconAsset ?? '').isNotEmpty), isTrue);
      expect(d.fold<int>(0, (int a, DistributionItem x) => a + x.jumlah), 21);
    });

    test('overdue terurut menurun dan lengkap', () {
      final List<OverdueItem> o =
          listOf(fx('dashboard_overdue.json')).map(OverdueItem.fromJson).toList();

      expect(o.length, lessThanOrEqualTo(5));
      for (int i = 0; i + 1 < o.length; i++) {
        expect(o[i].terlambatHari, greaterThanOrEqualTo(o[i + 1].terlambatHari));
      }
      expect(o.every((OverdueItem x) => x.namaKategori.isNotEmpty && x.namaLokasi.isNotEmpty), isTrue);
    });
  });

  group('Maintenance', () {
    test('PagedResult membaca paginator Laravel', () {
      final PagedResult<Maintenance> page = PagedResult<Maintenance>.fromJson(
          fx('maintenance_page.json')['data'] as Map<String, dynamic>, Maintenance.fromJson);

      expect(page.perPage, 3);
      expect(page.total, greaterThan(0));
      expect(page.currentPage, 1);
      expect(page.data, isNotEmpty);
      expect(page.hasNext, page.currentPage < page.lastPage);
    });

    test('baris riwayat memuat kolom join datar', () {
      final PagedResult<Maintenance> page = PagedResult<Maintenance>.fromJson(
          fx('maintenance_page.json')['data'] as Map<String, dynamic>, Maintenance.fromJson);

      for (final Maintenance m in page.data) {
        expect(m.namaKategori, isNotEmpty);
        expect(m.namaUsers, isNotEmpty);
        expect(m.namaLokasi, isNotEmpty);
        expect(m.lantai, isNotNull);
        expect(m.waktuMaintenance.year, greaterThan(2000));
      }
    });

    test('detail memuat nama_spesifikasi + satuan', () {
      final Maintenance full =
          Maintenance.fromJson(fx('maintenance_detail.json')['data'] as Map<String, dynamic>);

      expect(full.detail, isNotEmpty);
      for (final DetailMaintenance d in full.detail) {
        expect(d.namaSpesifikasi, isNotEmpty);
        expect(d.status, isNotEmpty);
        expect(d.teksLaporan, contains(':'));
      }
      expect(RiwayatItem.fromMaintenance(full).teknisi, isNotEmpty);
    });
  });

  group('MaintenancePayload', () {
    List<DetailMaintenance> detailContoh() =>
        listOf(fx('spesifikasi_ac.json'))
            .map(Spesifikasi.fromJson)
            .map((Spesifikasi s) =>
                DetailMaintenance(idSpesifikasi: s.idSpesifikasi, status: 'Baik'))
            .toList();

    test('toJson mengirim client_uuid, waktu, dan detail', () {
      final Map<String, dynamic> json = MaintenancePayload(
        barcodeAlat: 'AC-001',
        idLokasi: 5,
        kondisiKeseluruhan: 'baik',
        catatan: 'Uji',
        detail: detailContoh(),
      ).toJson();

      expect(json['client_uuid'], isNotEmpty);
      expect(json['waktu_maintenance'], isNotNull);
      expect(json['detail'], hasLength(8));
      expect(json['kondisi_keseluruhan'], 'baik');
      expect(
        (json['detail'] as List<dynamic>).every((dynamic d) =>
            (d as Map<String, dynamic>)['id_spesifikasi'] != null && d['status'] != null),
        isTrue,
      );
    });

    test('client_uuid berbentuk UUID v4 yang valid', () {
      final String cu = MaintenancePayload(
        barcodeAlat: 'AC-001',
        idLokasi: 1,
        detail: detailContoh(),
      ).clientUuid;

      // Regresi: dulu menghasilkan "-344e620--344-4-34-a-34--344e62065db"
      // karena (microsecondsSinceEpoch << 13) melampaui int64 -> negatif.
      expect(cu, hasLength(36));
      expect(cu, isNot(contains('--')));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(cu),
        isTrue,
        reason: 'client_uuid tidak berbentuk UUID v4: $cu',
      );
    });

    test('3000 client_uuid beruntun semuanya unik', () {
      // Regresi: DateTime.now() di Windows hanya bergranularitas ~1 ms,
      // sehingga tanpa penghitung urut semua UUID dalam satu milidetik
      // IDENTIK (terukur: hanya 5 nilai unik dari 3000). Saat antrean
      // offline dikirim beruntun, server akan menganggap kiriman ke-2 dst.
      // sebagai duplikat lalu membuangnya - data hilang.
      const int n = 3000;
      final RegExp v4 =
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final List<DetailMaintenance> det = detailContoh();

      final List<String> uuids = List<String>.generate(
        n,
        (int i) => MaintenancePayload(
          barcodeAlat: 'AC-001',
          idLokasi: 1,
          detail: det,
        ).clientUuid,
      );

      expect(uuids.every(v4.hasMatch), isTrue,
          reason: 'ada UUID yang tidak valid: '
              '${uuids.firstWhere((String u) => !v4.hasMatch(u), orElse: () => '-')}');
      expect(uuids.toSet(), hasLength(n),
          reason: 'hanya ${uuids.toSet().length} dari $n UUID yang unik');
    });
  });

  group('TugasHariIni (tugas-hari-ini)', () {
    test('ringkasan + daftar ter-parse', () {
      final TugasHariIni t = TugasHariIni.fromJson(
          fx('tugas_hari_ini.json')['data'] as Map<String, dynamic>);

      expect(t.ringkasan.total, 12);
      expect(t.ringkasan.overdue, 4);
      expect(t.ringkasan.jatuhTempoHariIni, 3);
      expect(t.kosong, isFalse);
      expect(t.daftar, hasLength(3));
    });

    test('TugasItem membaca status, keterlambatan, dan lokasi', () {
      final TugasHariIni t = TugasHariIni.fromJson(
          fx('tugas_hari_ini.json')['data'] as Map<String, dynamic>);

      final TugasItem ac = t.daftar.firstWhere((TugasItem x) => x.barcodeAlat == 'AC-001');
      expect(ac.isOverdue, isTrue);
      expect(ac.terlambatHari, 6);
      expect(ac.detailLokasi, 'Ruang Server Lantai 2');
      expect(ac.teksKeterlambatan, 'Terlambat 6 hari');
      expect(ac.terakhirMaintenance, isNotNull);

      final TugasItem apar = t.daftar.firstWhere((TugasItem x) => x.barcodeAlat == 'APAR-004');
      expect(apar.belumPernahDipelihara, isTrue);
      expect(apar.terakhirMaintenance, isNull);
      expect(t.belumPernahDipelihara, 1);
    });
  });

  group('Verifikasi (pending + verify)', () {
    test('PagedResult<VerifikasiItem> membaca paginator', () {
      final PagedResult<VerifikasiItem> page = PagedResult<VerifikasiItem>.fromJson(
          fx('maintenance_pending.json')['data'] as Map<String, dynamic>,
          VerifikasiItem.fromJson);

      expect(page.perPage, 20);
      expect(page.total, 47);
      expect(page.lastPage, 3);
      expect(page.data, hasLength(2));
      expect(page.data.first.menunggu, isTrue);
      expect(page.data.first.teknisi, 'Teknisi A');
      expect(page.data.first.detailLokasi, 'Aula Besar Lantai 7');
      expect(page.data.first.detail, isNotEmpty);
    });

    test('PendingCount membaca jumlah menunggu', () {
      final PendingCount c = PendingCount.fromJson(
          fx('maintenance_pending_count.json')['data'] as Map<String, dynamic>);

      expect(c.menunggu, 47);
      expect(c.kosong, isFalse);
      expect(c.label, '47');
    });

    test('VerifikasiPayload.toJson mengirim status + komentar', () {
      final Map<String, dynamic> json =
          VerifikasiPayload.setujui(komentar: 'Data lengkap.').toJson();

      expect(json['status'], 'disetujui');
      expect(json['komentar'], 'Data lengkap.');
      expect(VerifikasiPayload.setujui().valid, isTrue);
      expect(VerifikasiPayload.tolak(komentar: 'Kurang bukti').status, 'ditolak');
    });

    test('Maintenance membaca kolom verifikasi dari respons verify', () {
      final Maintenance m =
          Maintenance.fromJson(fx('maintenance_verify.json')['data'] as Map<String, dynamic>);

      expect(m.idMaintenance, 88);
      expect(m.statusVerifikasi, 'disetujui');
      expect(m.disetujui, isTrue);
      expect(m.menungguVerifikasi, isFalse);
      expect(m.diverifikasiOleh, '11111');
      expect(m.waktuVerifikasi, isNotNull);
      expect(m.komentarVerifikasi, 'Data lengkap.');
    });

    test('Maintenance lama tanpa kolom verifikasi tetap terparse (menunggu)', () {
      final Maintenance m =
          Maintenance.fromJson(fx('maintenance_detail.json')['data'] as Map<String, dynamic>);

      expect(m.statusVerifikasi, isNull);
      expect(m.menungguVerifikasi, isTrue);
      expect(m.statusVerifikasiTampil, 'menunggu');
    });
  });

  group('AuditLog (audit-log)', () {
    test('PagedResult<AuditLogEntry> membaca paginator', () {
      final PagedResult<AuditLogEntry> page = PagedResult<AuditLogEntry>.fromJson(
          fx('audit_log_page.json')['data'] as Map<String, dynamic>, AuditLogEntry.fromJson);

      expect(page.total, 2);
      expect(page.data, hasLength(2));

      final AuditLogEntry e = page.data.first;
      expect(e.idAudit, 12);
      expect(e.actorUsername, '12345');
      expect(e.aksi, 'update');
      expect(e.isUpdate, isTrue);
      expect(e.entitas, 'alat');
      expect(e.entitasId, 'AC-001');
      expect(e.waktuTampil, '2026-07-15 09:00:00');
      expect(e.detailTampil, 'merk_alat=Daikin 2PK');
      expect(page.data.last.isDelete, isTrue);
      expect(page.data.last.detailTampil, '-');
    });
  });

  group('Users & Alat (endpoint baru)', () {
    test('PagedResult<User> membaca jumlah_maintenance', () {
      final PagedResult<User> page = PagedResult<User>.fromJson(
          fx('users_page.json')['data'] as Map<String, dynamic>, User.fromJson);

      expect(page.total, 2);
      expect(page.data.first.username, '67890');
      expect(page.data.first.jumlahMaintenance, 34);
      expect(page.data.first.isTeknisi, isTrue);
      expect(page.data.first.roleTampil, 'Teknisi');
      expect(page.data.last.isSupervisor, isTrue);
    });

    test('Alat.assign membaca penanggung_jawab', () {
      final Alat a = Alat.fromJson(fx('alat_assign.json')['data'] as Map<String, dynamic>);

      expect(a.barcodeAlat, 'AC-001');
      expect(a.penanggungJawab, '67890');
      expect(a.namaPenanggungJawab, 'Teknisi A');
      expect(a.ditugaskan, isTrue);
      expect(a.penanggungJawabTampil, 'Teknisi A');
      expect(a.ditugaskanPada, isNotNull);
    });

    test('ParameterAbnormal membaca nilai + ambang', () {
      final List<ParameterAbnormal> list =
          listOf(fx('parameter_abnormal.json')).map(ParameterAbnormal.fromJson).toList();

      expect(list, hasLength(2));
      expect(list.first.barcodeAlat, 'PL-002');
      expect(list.first.namaSpesifikasi, 'Tegangan R-N');
      expect(list.first.nilaiTampil, '198 V');
      expect(list.first.nilaiDenganAmbang, '198 V (>=215)');
      expect(list.first.waktu, isNotNull);
    });
  });
}
