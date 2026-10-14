"""Cari bentuk `initialize` yang diterima analysis server 1.40.1."""
import json, os, subprocess, time, threading

DART_SDK = r"C:\src\flutter\bin\cache\dart-sdk"
RUNTIME = os.path.join(DART_SDK, "bin", "dartaotruntime.exe")
SERVER = os.path.join(DART_SDK, "bin", "snapshots", "analysis_server_aot.dart.snapshot")
APP = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_URI = "file:///" + APP.replace("\\", "/")

variants = {
    "A_processId_null": {"processId": None},
    "B_processId_only": {"processId": 1234},
    "C_clientId_clientVersion": {"processId": 1234, "clientId": "meiv",
                                 "clientVersion": "1.0", "rootPath": APP,
                                 "capabilities": {}},
    "D_clientInfo_only": {"processId": 1234,
                          "clientInfo": {"name": "meiv", "version": "1.0"}},
    "E_rootUri_only": {"processId": 1234, "rootUri": ROOT_URI,
                       "capabilities": {}},
    "F_caps_empty_only": {"capabilities": {}},
    "G_processId_caps": {"processId": 1234, "capabilities": {}},
    "H_clientInfo_caps": {"processId": 1234,
                          "clientInfo": {"name": "meiv", "version": "1.0"},
                          "capabilities": {}},
}

log = []
for name, params in variants.items():
    p = subprocess.Popen([RUNTIME, SERVER], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, encoding="utf-8", errors="replace", bufsize=1)
    got = []

    def rd(stream, tag):
        for line in stream:
            got.append("%s| %s" % (tag, line.rstrip()))

    threading.Thread(target=rd, args=(p.stdout, "OUT"), daemon=True).start()
    threading.Thread(target=rd, args=(p.stderr, "ERR"), daemon=True).start()

    try:
        p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 1,
                                  "method": "initialize", "params": params}) + "\n")
        p.stdin.flush()
    except Exception as e:
        got.append("WRITE-FAIL %s" % e)

    time.sleep(6)
    try:
        p.kill()
    except Exception:
        pass

    verdict = "?"
    for g in got:
        if "server.connected" in g:
            continue
        verdict = g
        break
    ok = "result" in verdict and "error" not in verdict
    log.append("%-28s -> %s" % (name, "OK" if ok else "GAGAL"))
    log.append("      %s" % verdict[:300])
    for g in got:
        if g.startswith("ERR|"):
            log.append("      %s" % g[:200])
    log.append("")

with open(os.path.join(HERE, "initprobe-result.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(log))
print("done")
