#!/usr/bin/env python3
"""Rekam respons API Mei-V2 yang ASLI menjadi fixture JSON.

Fixture ini dipakai oleh uji Dart (app/test/models_test.dart) supaya model
Flutter diuji terhadap bentuk JSON yang benar-benar dikirim Laravel - bukan
terhadap JSON yang dikarang sendiri.

Jalankan server dulu:
    cd backend && php artisan serve --host=127.0.0.1 --port=8123
"""
import json
import os
import sys
import urllib.request
import urllib.error

BASE = "http://127.0.0.1:8123/api/v1"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "app", "test", "fixtures")
OUT = os.path.normpath(OUT)

os.makedirs(OUT, exist_ok=True)


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path,
                                 data=json.dumps(body).encode() if body else None,
                                 method=method)
    req.add_header("Accept", "application/json")
    if body:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())


st, d = call("POST", "/auth/login", {"username": "12345", "password": "password"})
if st != 200:
    print("LOGIN GAGAL:", st, d)
    sys.exit(1)
token = d["data"]["token"]

fixtures = {
    "login.json": d,
    "kategori.json": call("GET", "/kategori", token=token)[1],
    "spesifikasi_ac.json": call("GET", "/kategori/1/spesifikasi", token=token)[1],
    "spesifikasi_genset.json": call("GET", "/kategori/7/spesifikasi", token=token)[1],
    "alat_list.json": call("GET", "/alat", token=token)[1],
    "alat_ac001.json": call("GET", "/alat/AC-001", token=token)[1],
    "alat_ac003.json": call("GET", "/alat/AC-003", token=token)[1],
    "lokasi.json": call("GET", "/lokasi", token=token)[1],
    "dashboard_kpi.json": call("GET", "/dashboard/kpi", token=token)[1],
    "dashboard_trends.json": call("GET", "/dashboard/trends?days=7", token=token)[1],
    "dashboard_distribution.json": call("GET", "/dashboard/distribution", token=token)[1],
    "dashboard_overdue.json": call("GET", "/dashboard/overdue?limit=5", token=token)[1],
    "maintenance_page.json": call("GET", "/maintenance?per_page=3", token=token)[1],
}

# Satu sesi maintenance lengkap (dengan detail) untuk menguji Maintenance.fromJson
mid = fixtures["maintenance_page.json"]["data"]["data"][0]["id_maintenance"]
fixtures["maintenance_detail.json"] = call("GET", "/maintenance/%s" % mid, token=token)[1]

for name, payload in fixtures.items():
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print("  %-28s %6d byte" % (name, os.path.getsize(os.path.join(OUT, name))))

print("\n%d fixture ditulis ke %s" % (len(fixtures), OUT))
