#!/usr/bin/env python3
"""Uji end-to-end API Mei-V2 lewat HTTP nyata.

Memverifikasi bahwa bentuk JSON dari Laravel benar-benar cocok dengan yang
dibaca model Dart (kunci datar, bukan objek bersarang).
"""
import json
import sys
import urllib.request
import urllib.error
import urllib.parse
import uuid

BASE = "http://127.0.0.1:8123/api/v1"
TOKEN = open("token.txt").read().strip()

ok_count = 0
fail_count = 0


def call(method, path, body=None, token=TOKEN):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"_raw": raw}


def check(label, cond, detail=""):
    global ok_count, fail_count
    if cond:
        ok_count += 1
        print("  PASS  %s%s" % (label, ("  " + detail) if detail else ""))
    else:
        fail_count += 1
        print("  FAIL  %s%s" % (label, ("  " + detail) if detail else ""))


print("=" * 74)
print("1. ENVELOPE & AUTH")
print("=" * 74)
st, d = call("GET", "/auth/me")
check("GET /auth/me -> 200", st == 200, "status=%s" % st)
check("envelope punya code/data/message", set(["code", "data", "message"]).issubset(d), str(list(d.keys())))
check("me mengembalikan role_users", "role_users" in (d.get("data") or {}), str(d.get("data")))

st, d = call("GET", "/kategori", token=None)
check("tanpa token -> 401", st == 401, "status=%s code=%s" % (st, d.get("code")))
check("401 tetap ber-envelope", "message" in d, str(d.get("message")))

print()
print("=" * 74)
print("2. KATEGORI  (Dart: Kategori.fromJson butuh 'jumlah_alat')")
print("=" * 74)
st, d = call("GET", "/kategori")
kats = d.get("data") or []
check("GET /kategori -> 200", st == 200, "status=%s" % st)
check("7 kategori", len(kats) == 7, "n=%d" % len(kats))
sample = kats[0] if kats else {}
check("kunci 'jumlah_alat' ada", "jumlah_alat" in sample, str(sorted(sample.keys())))
check("jumlah_alat bertipe int", isinstance(sample.get("jumlah_alat"), int), repr(sample.get("jumlah_alat")))
check("kunci 'icon_asset' ada", "icon_asset" in sample, repr(sample.get("icon_asset")))
check("kunci 'maintenance_cycle_days' ada", "maintenance_cycle_days" in sample, repr(sample.get("maintenance_cycle_days")))
total_alat = sum(k.get("jumlah_alat", 0) for k in kats)
check("total jumlah_alat = 21", total_alat == 21, "total=%d" % total_alat)
for k in kats:
    print("        %-20s id=%-3s cycle=%-4s alat=%-3s %s"
          % (k.get("nama"), k.get("id_kategori"), k.get("maintenance_cycle_days"),
             k.get("jumlah_alat"), k.get("icon_asset")))

print()
print("=" * 74)
print("3. CHECKLIST DINAMIS  (satu form, bukan enam)")
print("=" * 74)
expect = {"AC": 8, "Penangkal Petir": 5, "Panel Listrik": 9, "APAR": 6,
          "Fire Alarm": 5, "Hydrant": 5, "Genset": 7}
for k in kats:
    st, d = call("GET", "/kategori/%s/spesifikasi" % k["id_kategori"])
    items = d.get("data") or []
    nama = k.get("nama")
    want = expect.get(nama, 0)
    check("checklist %-16s -> %d item" % (nama, want), len(items) == want, "dapat=%d" % len(items))
    if items:
        it = items[0]
        need = ["id_spesifikasi", "nama_spesifikasi", "tipe_input", "satuan", "opsi", "urutan"]
        missing = [x for x in need if x not in it]
        check("  kunci lengkap utk Dart Spesifikasi", not missing, "kurang=%s" % missing)

print()
print("=" * 74)
print("4. ALAT  (Dart: Alat.fromJson butuh kolom DATAR hasil join)")
print("=" * 74)
st, d = call("GET", "/alat")
alats = d.get("data") or []
check("GET /alat -> 200", st == 200, "status=%s" % st)
check("21 alat", len(alats) == 21, "n=%d" % len(alats))
need_flat = ["barcode_alat", "merk_alat", "nama_kategori", "deskripsi",
             "nama_lokasi", "lantai", "maintenance_cycle_days", "terakhir_maintenance"]
a0 = alats[0] if alats else {}
missing = [x for x in need_flat if x not in a0]
check("semua kunci datar ada di /alat", not missing, "kurang=%s" % missing)
nested = [x for x in ["kategori", "lokasi", "maintenance"] if x in a0]
check("relasi mentah disembunyikan ($hidden)", not nested, "bocor=%s" % nested)
check("lantai bertipe int", isinstance(a0.get("lantai"), int), repr(a0.get("lantai")))
check("maintenance_cycle_days int", isinstance(a0.get("maintenance_cycle_days"), int), repr(a0.get("maintenance_cycle_days")))

st, d = call("GET", "/alat/AC-001")
ac1 = d.get("data") or {}
check("GET /alat/AC-001 -> 200", st == 200, "status=%s" % st)
check("AC-001 nama_kategori=AC", ac1.get("nama_kategori") == "AC", repr(ac1.get("nama_kategori")))
check("AC-001 nama_lokasi=Aula Besar", ac1.get("nama_lokasi") == "Aula Besar", repr(ac1.get("nama_lokasi")))
check("AC-001 lantai=7", ac1.get("lantai") == 7, repr(ac1.get("lantai")))
check("AC-001 cycle=30", ac1.get("maintenance_cycle_days") == 30, repr(ac1.get("maintenance_cycle_days")))
print("        AC-001: %s | %s lantai %s | cycle %s hari | terakhir %s"
      % (ac1.get("merk_alat"), ac1.get("nama_lokasi"), ac1.get("lantai"),
         ac1.get("maintenance_cycle_days"), ac1.get("terakhir_maintenance")))

st, d = call("GET", "/alat/AC-003")
ac3 = d.get("data") or {}
check("AC-003 belum pernah dipelihara -> terakhir_maintenance null",
      ac3.get("terakhir_maintenance") is None, repr(ac3.get("terakhir_maintenance")))

for term, want in [("genset", 4), ("GENSET", 4), ("GenSet", 4),
                   ("hydrant", 3), ("basement", 5), ("aula", 3),
                   ("GS-001", 1), ("caterpillar", 1), ("ruang server", 3),
                   ("zzz-tidak-ada", 0)]:
    st, d = call("GET", "/alat?q=%s" % urllib.parse.quote(term))
    got = d.get("data") or []
    check("cari %-16r -> %d hasil" % (term, want), st == 200 and len(got) == want,
          "dapat=%d" % len(got))

print()
print("=" * 74)
print("5. LOKASI  (Dart: Lokasi.fromJson butuh 'jumlah_alat')")
print("=" * 74)
st, d = call("GET", "/lokasi")
loks = d.get("data") or []
check("GET /lokasi -> 200", st == 200, "status=%s" % st)
check("8 lokasi", len(loks) == 8, "n=%d" % len(loks))
check("jumlah_alat ada", "jumlah_alat" in (loks[0] if loks else {}), str(sorted((loks[0] if loks else {}).keys())))
check("lantai int", isinstance((loks[0] if loks else {}).get("lantai"), int), repr((loks[0] if loks else {}).get("lantai")))

print()
print("=" * 74)
print("6. DASHBOARD")
print("=" * 74)
st, d = call("GET", "/dashboard/kpi")
kpi = d.get("data") or {}
check("GET /dashboard/kpi -> 200", st == 200, "status=%s" % st)
need_kpi = ["total_alat", "total_kategori", "pemeliharaan_bulan_ini", "pemeliharaan_tepat_waktu",
            "alat_overdue", "teknisi_aktif", "persen_tepat_waktu", "rata_rata_interval_hari"]
missing = [x for x in need_kpi if x not in kpi]
check("semua kunci KPI ada", not missing, "kurang=%s" % missing)
check("total_alat = 21", kpi.get("total_alat") == 21, repr(kpi.get("total_alat")))
check("total_kategori = 7", kpi.get("total_kategori") == 7, repr(kpi.get("total_kategori")))
check("alat_overdue > 0", (kpi.get("alat_overdue") or 0) > 0, repr(kpi.get("alat_overdue")))
print("        KPI: %s" % json.dumps(kpi, ensure_ascii=False))

st, d = call("GET", "/dashboard/trends?days=7")
tr = d.get("data") or []
check("GET /dashboard/trends?days=7 -> 200", st == 200, "status=%s" % st)
check("7 titik (semua hari terisi)", len(tr) == 7, "n=%d" % len(tr))
check("tiap titik punya label & jumlah", all("label" in x and "jumlah" in x for x in tr), str(tr[:2]))

st, d = call("GET", "/dashboard/distribution")
dist = d.get("data") or []
check("GET /dashboard/distribution -> 200", st == 200, "status=%s" % st)
check("7 kategori terdistribusi", len(dist) == 7, "n=%d" % len(dist))
check("tiap item punya icon_asset", all("icon_asset" in x for x in dist), str(dist[0] if dist else {}))

st, d = call("GET", "/dashboard/overdue?limit=5")
ov = d.get("data") or []
check("GET /dashboard/overdue -> 200", st == 200, "status=%s" % st)
check("overdue <= limit 5", len(ov) <= 5, "n=%d" % len(ov))
if ov:
    need_ov = ["barcode_alat", "merk_alat", "nama_kategori", "nama_lokasi", "lantai",
               "terlambat_hari", "nama_users"]
    missing = [x for x in need_ov if x not in ov[0]]
    check("kunci overdue lengkap", not missing, "kurang=%s" % missing)
    desc = all(ov[i]["terlambat_hari"] >= ov[i + 1]["terlambat_hari"] for i in range(len(ov) - 1))
    check("urut terlambat_hari menurun", desc, str([x["terlambat_hari"] for x in ov]))
    for x in ov:
        print("        %-9s %-14s %-15s lantai %-3s terlambat %s hari"
              % (x["barcode_alat"], x["merk_alat"], x["nama_lokasi"], x["lantai"], x["terlambat_hari"]))

print()
print("=" * 74)
print("7. MAINTENANCE  (paginasi + idempotency client_uuid)")
print("=" * 74)
st, d = call("GET", "/maintenance?per_page=5")
pg = d.get("data") or {}
check("GET /maintenance -> 200", st == 200, "status=%s" % st)
check("berbentuk paginator Laravel",
      all(k in pg for k in ["data", "total", "current_page", "last_page", "per_page"]),
      str(sorted(pg.keys())))
check("per_page dihormati = 5", pg.get("per_page") == 5, repr(pg.get("per_page")))
rows = pg.get("data") or []
check("baris punya kolom join datar",
      all(k in (rows[0] if rows else {}) for k in ["nama_kategori", "merk_alat", "nama_users", "nama_lokasi", "lantai"]),
      str(sorted((rows[0] if rows else {}).keys())))

st, d = call("GET", "/maintenance/%s" % rows[0]["id_maintenance"])
det = d.get("data") or {}
check("GET /maintenance/{id} -> 200", st == 200, "status=%s" % st)
details = det.get("detail") or []
check("detail terisi", len(details) > 0, "n=%d" % len(details))
if details:
    # Dart DetailMaintenance.fromJson membaca: id_spesifikasi, status,
    # nama_spesifikasi, satuan  (lihat app/lib/domain/models/maintenance.dart)
    need_det = ["id_spesifikasi", "status", "nama_spesifikasi", "satuan"]
    missing = [x for x in need_det if x not in details[0]]
    check("kunci detail cocok dgn Dart DetailMaintenance", not missing, "kurang=%s" % missing)
    print("        contoh detail: %s" % json.dumps(details[0], ensure_ascii=False))

# --- Idempotency: payload persis seperti MaintenancePayload.toJson() di Dart ---
st, d = call("GET", "/kategori/%s/spesifikasi" % [k for k in kats if k["nama"] == "AC"][0]["id_kategori"])
spec_ac = d.get("data") or []
cu = str(uuid.uuid4())
payload = {
    "client_uuid": cu,
    "barcode_alat": "AC-001",
    "id_lokasi": 5,
    "waktu_maintenance": "2026-10-13T20:15:00+07:00",
    "catatan": "Uji idempotency otomatis",
    "kondisi_keseluruhan": "baik",
    "detail": [{"id_spesifikasi": s["id_spesifikasi"], "status": "Baik"} for s in spec_ac],
}
st1, r1 = call("POST", "/maintenance", payload)
st2, r2 = call("POST", "/maintenance", payload)
check("POST pertama -> 201", st1 == 201, "status=%s msg=%s" % (st1, r1.get("message")))
check("POST ulang (client_uuid sama) -> 200", st2 == 200, "status=%s msg=%s" % (st2, r2.get("message")))
id1 = (r1.get("data") or {}).get("id_maintenance")
id2 = (r2.get("data") or {}).get("id_maintenance")
check("kedua respons menunjuk record yang SAMA", id1 is not None and id1 == id2, "%s vs %s" % (id1, id2))
check("pesan POST ulang menjelaskan duplikat", "sudah" in (r2.get("message") or "").lower(), repr(r2.get("message")))
check("detail tersimpan utuh (%d item)" % len(spec_ac),
      len((r1.get("data") or {}).get("detail") or []) == len(spec_ac),
      "tersimpan=%d" % len((r1.get("data") or {}).get("detail") or []))

# Hitung baris di DB untuk client_uuid ini -> harus tepat 1
st, d = call("GET", "/maintenance?per_page=100")
same = [x for x in (d.get("data") or {}).get("data", []) if x.get("client_uuid") == cu]
check("di DB hanya ada 1 baris utk client_uuid itu", len(same) == 1, "n=%d" % len(same))

print()
print("=" * 74)
print("HASIL: %d lulus, %d gagal" % (ok_count, fail_count))
print("=" * 74)
sys.exit(1 if fail_count else 0)
