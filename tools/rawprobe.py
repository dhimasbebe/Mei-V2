"""Dump mentah apa yang ditulis analysis server ke stdout."""
import json, os, subprocess, sys, time, threading

DART_SDK = r"C:\src\flutter\bin\cache\dart-sdk"
RUNTIME = os.path.join(DART_SDK, "bin", "dartaotruntime.exe")
SERVER = os.path.join(DART_SDK, "bin", "snapshots", "analysis_server_aot.dart.snapshot")
APP = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app")
HERE = os.path.dirname(os.path.abspath(__file__))

args_variants = [
    [RUNTIME, SERVER],
    [RUNTIME, SERVER, "--client-id", "meiv", "--client-version", "1.0"],
    [RUNTIME, SERVER, "--no-error-notification", "--client-id", "meiv", "--client-version", "1.0"],
]

log = []
for i, cmd in enumerate(args_variants):
    log.append("=== VARIAN %d: %s ===" % (i, " ".join(os.path.basename(c) for c in cmd)))
    try:
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True, encoding="utf-8",
                             errors="replace", bufsize=1)
    except Exception as e:
        log.append("  spawn gagal: %s" % e)
        continue

    got = []

    def rd(stream, tag):
        for line in stream:
            got.append("%s| %s" % (tag, line.rstrip()))

    t1 = threading.Thread(target=rd, args=(p.stdout, "OUT"), daemon=True)
    t2 = threading.Thread(target=rd, args=(p.stderr, "ERR"), daemon=True)
    t1.start(); t2.start()

    init = {"jsonrpc": "2.0", "id": 0, "method": "initialize",
            "params": {"processId": os.getpid(),
                       "clientInfo": {"name": "meiv", "version": "1.0"},
                       "rootPath": APP,
                       "rootUri": "file:///" + APP.replace("\\", "/"),
                       "capabilities": {}}}
    try:
        p.stdin.write(json.dumps(init) + "\n")
        p.stdin.flush()
    except Exception as e:
        log.append("  tulis initialize gagal: %s" % e)

    time.sleep(12)
    try:
        p.kill()
    except Exception:
        pass
    time.sleep(0.5)
    log.append("  pesan diterima: %d" % len(got))
    log.extend(["  " + g for g in got[:40]])
    log.append("")

with open(os.path.join(HERE, "rawprobe-result.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(log))
print("done")
