"""Probe: can we capture a Dart child process stdout via pipes in this sandbox?"""
import subprocess, sys, os

DART_SDK = r"C:\src\flutter\bin\cache\dart-sdk"
RUNTIME = os.path.join(DART_SDK, "bin", "dartaotruntime.exe")
SERVER = os.path.join(DART_SDK, "bin", "snapshots", "analysis_server_aot.dart.snapshot")

out = []
out.append("runtime exists: %s" % os.path.exists(RUNTIME))
out.append("analysis_server exists: %s" % os.path.exists(SERVER))
if os.path.isdir(os.path.join(DART_SDK, "bin", "snapshots")):
    for f in sorted(os.listdir(os.path.join(DART_SDK, "bin", "snapshots"))):
        out.append("  snapshot: %s" % f)

# Test 1: simple pipe capture
try:
    p = subprocess.run([RUNTIME, "--version"], capture_output=True, text=True, timeout=30)
    out.append("TEST1 rc=%s out=%r err=%r" % (p.returncode, p.stdout.strip()[:200], p.stderr.strip()[:300]))
except Exception as e:
    out.append("TEST1 EXC: %s: %s" % (type(e).__name__, e))

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "pipeprobe-result.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))
print("done")
