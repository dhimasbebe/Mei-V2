"""Jalankan `dart analyze` / `flutter analyze` sebagai anak proses Python.

Blokir sandbox sebelumnya terjadi pada proses yang diluncurkan langsung oleh
tool shell. Ketika Python yang meluncurkannya (dengan pipe biasa), capture
stdout terbukti bekerja - lihat pipeprobe.py.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
APP = os.path.join(REPO, "app")

DART = r"C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe"
FLUTTER_BAT = r"C:\src\flutter\bin\flutter.bat"

log = []


def run(label, cmd, cwd):
    log.append("=" * 70)
    log.append("=== %s" % label)
    log.append("    cwd: %s" % cwd)
    log.append("=" * 70)
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=600)
    except Exception as e:
        log.append("GAGAL meluncurkan: %s: %s" % (type(e).__name__, e))
        log.append("")
        return None
    log.append("exit=%s" % p.returncode)
    log.append("--- stdout ---")
    log.append(p.stdout)
    log.append("--- stderr ---")
    log.append(p.stderr[:4000])
    log.append("")
    return p


run("dart analyze --format=machine",
    [DART, "analyze", "--format=machine", "lib"], APP)

run("dart analyze (biasa)",
    [DART, "analyze", "lib"], APP)

with open(os.path.join(HERE, "dartanalyze-result.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(log))
print("done")
