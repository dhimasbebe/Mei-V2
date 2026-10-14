"""Jalankan analysis server Dart langsung (tanpa `flutter analyze`).

`flutter analyze` gagal di lingkungan ini karena proses pembungkusnya
(dartdev/flutter_tools) memakai named pipe yang di-hook sandbox. Tetapi
snapshot `analysis_server_aot.dart.snapshot` bisa dijalankan langsung dan
berbicara JSON-RPC lewat stdin/stdout biasa - dan pipe biasa JALAN di sini.

Skrip ini mengumpulkan seluruh diagnostik (error + lint) untuk app/lib.
"""
import json
import os
import subprocess
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
APP = os.path.join(REPO, "app")
TARGET = os.path.join(APP, "lib")

DART_SDK = r"C:\src\flutter\bin\cache\dart-sdk"
RUNTIME = os.path.join(DART_SDK, "bin", "dartaotruntime.exe")
SERVER = os.path.join(DART_SDK, "bin", "snapshots", "analysis_server_aot.dart.snapshot")

LOCK = threading.Lock()
STATE = {
    "errors": {},       # file -> list of diagnostics
    "responses": {},    # id -> result/error
    "methods": [],      # trace of notifications
    "last_msg": 0.0,
    "stdout_done": False,
    "stderr": [],
}


def uri(path):
    return "file:///" + path.replace("\\", "/")


def main():
    proc = subprocess.Popen(
        [RUNTIME, SERVER],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )

    def send(obj):
        with LOCK:
            try:
                proc.stdin.write(json.dumps(obj) + "\n")
                proc.stdin.flush()
            except Exception:
                pass

    def reader():
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except Exception:
                continue
            with LOCK:
                STATE["last_msg"] = time.time()
                method = msg.get("method")
                if method:
                    STATE["methods"].append(method)
                if method == "analysis.errors":
                    p = msg.get("params", {})
                    STATE["errors"][p.get("file")] = p.get("errors", [])
                elif "id" in msg and method:
                    # Permintaan server -> klien; balas agar tidak menggantung.
                    result = None
                    if method == "workspace/configuration":
                        result = [{} for _ in msg.get("params", {}).get("items", [])]
                    elif method == "workspace/workspaceFolders":
                        result = []
                    out = {"jsonrpc": "2.0", "id": msg["id"], "result": result}
                else:
                    out = None
                if "id" in msg and not method:
                    STATE["responses"][msg["id"]] = msg
            if out:
                send(out)
        with LOCK:
            STATE["stdout_done"] = True

    def err_reader():
        for line in proc.stderr:
            with LOCK:
                if len(STATE["stderr"]) < 40:
                    STATE["stderr"].append(line.rstrip())

    threading.Thread(target=reader, daemon=True).start()
    threading.Thread(target=err_reader, daemon=True).start()

    def wait_for(pred, timeout, label):
        end = time.time() + timeout
        while time.time() < end:
            with LOCK:
                if pred():
                    return True
            time.sleep(0.25)
        print("TIMEOUT menunggu: %s" % label)
        return False

    send({
        "jsonrpc": "2.0", "id": 0, "method": "initialize",
        "params": {
            "processId": os.getpid(),
            "clientInfo": {"name": "meiv-driver", "version": "1.0"},
            "rootPath": APP,
            "rootUri": uri(APP),
            "capabilities": {},
        },
    })

    if not wait_for(lambda: 0 in STATE["responses"], 90, "initialize"):
        print("stderr:", "\n".join(STATE["stderr"]))
        return

    send({
        "jsonrpc": "2.0", "id": 1, "method": "analysis.setAnalysisRoots",
        "params": {"included": [TARGET], "excluded": []},
    })

    # Tunggu sampai tidak ada pesan baru selama 8 detik DAN sudah ada hasil.
    end = time.time() + 240
    while time.time() < end:
        time.sleep(0.5)
        with LOCK:
            idle = time.time() - STATE["last_msg"]
            n = len(STATE["errors"])
        if n > 0 and idle >= 8.0:
            break

    send({"jsonrpc": "2.0", "id": 99, "method": "analysis.shutdown"})
    time.sleep(1.0)
    try:
        proc.kill()
    except Exception:
        pass

    with LOCK:
        errors = dict(STATE["errors"])
        methods = list(STATE["methods"])
        stderr = list(STATE["stderr"])

    # --- Susun laporan -------------------------------------------------------
    sev_order = {"ERROR": 0, "WARNING": 1, "INFO": 2}
    lines = []
    total = 0
    by_code = {}
    for f in sorted(errors):
        ds = [d for d in errors[f] if d]
        if not ds:
            continue
        rel = os.path.relpath(f, APP).replace("\\", "/")
        ds = sorted(ds, key=lambda d: (
            sev_order.get(d.get("severity"), 3),
            d.get("location", {}).get("start", {}).get("line", 0),
        ))
        for d in ds:
            loc = d.get("location", {})
            line = loc.get("start", {}).get("line", 0) + 1
            col = loc.get("start", {}).get("column", 0) + 1
            code = d.get("code", "?")
            by_code[code] = by_code.get(code, 0) + 1
            lines.append("%s:%d:%d  %-7s %-42s %s" % (
                rel, line, col, d.get("severity"), code, d.get("message")))
            total += 1

    report = ["TOTAL: %d" % total, "", "== RINGKASAN KODE =="]
    for code, n in sorted(by_code.items(), key=lambda kv: -kv[1]):
        report.append("  %4d  %s" % (n, code))
    report += ["", "== RINCIAN =="] + lines
    report += ["", "== NOTIFIKASI DITERIMA ==", ", ".join(sorted(set(methods)))]
    if stderr:
        report += ["", "== STDERR =="] + stderr[:20]

    with open(os.path.join(HERE, "analyze-result.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(report))
    print("done total=%d files=%d" % (total, len(errors)))


if __name__ == "__main__":
    main()
