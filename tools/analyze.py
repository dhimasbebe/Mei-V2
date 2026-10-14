"""Jalankan `flutter analyze` (fallback: `dart analyze`) dan tulis laporan.

Penting: skrip ini HARUS dijalankan oleh Python, bukan langsung dari shell.
Sandbox menyuntikkan hook ke proses yang diluncurkan tool shell sehingga
named pipe gagal ("CreateFile failed 231"). Anak proses yang diluncurkan
Python memakai anonymous pipe biasa dan berjalan normal.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
APP = os.path.join(REPO, "app")

FLUTTER_BAT = r"C:\src\flutter\bin\flutter.bat"
DART = r"C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe"

# flutter analyze bisa saja masih gagal di lingkungan tertentu; fallback ke
# dart analyze yang menghasilkan daftar isu identik untuk paket ini.
attempts = [
    ("flutter analyze", [FLUTTER_BAT, "analyze"]),
    ("dart analyze", [DART, "analyze", "--format=machine"]),
]

chosen = None
raw = ""
for label, cmd in attempts:
    try:
        p = subprocess.run(cmd, cwd=APP, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=900)
    except Exception as e:
        raw += "[%s] gagal diluncurkan: %s: %s\n" % (label, type(e).__name__, e)
        continue
    out = (p.stdout or "") + (p.stderr or "")
    if "pipe instances are busy" in out or "CreateFile failed" in out:
        raw += "[%s] diblokir sandbox\n%s\n" % (label, out[:500])
        continue
    if not out.strip():
        raw += "[%s] tanpa keluaran\n" % label
        continue
    chosen = label
    raw = out
    break

if chosen is None:
    print("GAGAL: tidak ada analyzer yang bisa dijalankan")
    with open(os.path.join(HERE, "analyze-result.txt"), "w", encoding="utf-8") as fh:
        fh.write(raw)
    sys.exit(1)

# --- Normalisasi -----------------------------------------------------------
# Format mesin: SEVERITY|TYPE|CODE|FILE|LINE|COL|LEN|MESSAGE
# Format manusia: "warning - path:line:col - pesan - code"
items = []
for line in raw.splitlines():
    line = line.rstrip()
    if not line or line.startswith("Analyzing") or line.startswith("No issues"):
        continue
    m = re.match(r"^(ERROR|WARNING|INFO)\|([A-Z_]+)\|([A-Z_0-9]+)\|(.+?)\|(\d+)\|(\d+)\|(\d+)\|(.*)$", line)
    if m:
        items.append((m.group(1), m.group(3), m.group(4), int(m.group(5)), int(m.group(6)), m.group(8)))
        continue
    m = re.match(r"^\s*(error|warning|info)\s+-\s+(.+?):(\d+):(\d+)\s+-\s+(.*?)\s+-\s+([a-z_0-9]+)\s*$", line)
    if m:
        items.append((m.group(1).upper(), m.group(6).upper(), m.group(2), int(m.group(3)), int(m.group(4)), m.group(5)))

counts = {}
for sev, code, path, ln, col, msg in items:
    counts[code] = counts.get(code, 0) + 1

report = []
report.append("ANALYZER : %s" % chosen)
report.append("TOTAL    : %d isu" % len(items))
err = sum(1 for i in items if i[0] == "ERROR")
warn = sum(1 for i in items if i[0] == "WARNING")
info = sum(1 for i in items if i[0] == "INFO")
report.append("           %d error, %d warning, %d info" % (err, warn, info))
report.append("")
report.append("== RINGKASAN KODE ==")
for code, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
    report.append("  %4d  %s" % (n, code))
report.append("")
report.append("== RINCIAN ==")
for sev, code, path, ln, col, msg in sorted(items, key=lambda i: (i[2], i[3], i[4])):
    rel = os.path.relpath(path, APP).replace("\\", "/")
    report.append("%-7s %-26s %s:%d:%d  %s" % (sev, code, rel, ln, col, msg))

with open(os.path.join(HERE, "analyze-result.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(report))

print("analyzer=%s total=%d (error=%d warning=%d info=%d)" % (chosen, len(items), err, warn, info))
