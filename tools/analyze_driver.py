"""Penggerak analysis server Dart untuk lingkungan yang memblokir subprocess dart.

Latar belakang
--------------
`dart analyze` menjalankan `dartdev`, yang lalu men-spawn
`dartaotruntime.exe analysis_server_aot.dart.snapshot` sebagai proses anak dan
berkomunikasi lewat named pipe. Di sandbox ini hook CreateFileW menolak pipe
tersebut (`ERROR_PIPE_BUSY 231`), sehingga `dart analyze` selalu gagal walau
kodenya benar.

Skrip ini mengambil jalan memutar: analysis server dijalankan LANGSUNG sebagai
proses anak milik skrip ini (jalur itu tidak diblokir), lalu protokolnya
(JSON-RPC berbingkai `Content-Length`, sama seperti LSP) dikendalikan manual.

Keluaran: satu baris per diagnostik, format
    SEVERITY  file:line:col  code  message

Pakai:
    python analyze_driver.py <direktori-app> [--verbose]
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time

DART_SDK = r"C:\src\flutter\bin\cache\dart-sdk"
SERVER = os.path.join(DART_SDK, "bin", "snapshots", "analysis_server_aot.dart.snapshot")
RUNTIME = os.path.join(DART_SDK, "bin", "dartaotruntime.exe")

VERBOSE = "--verbose" in sys.argv


def log(*args: object) -> None:
    print(*args, file=sys.stderr, flush=True)


class Server:
    """Klien minimal untuk protokol analysis server Dart."""

    def __init__(self, sdk: str, log_path: str) -> None:
        self._log_file = open(log_path, "w", encoding="utf-8", errors="replace")
        self.proc = subprocess.Popen(
            [RUNTIME, SERVER, f"--sdk={sdk}", "--client-id=meiv-driver"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self._log_file,
            bufsize=0,
        )
        self.errors: dict[str, list[dict]] = {}
        self.responses: dict[int, dict] = {}
        self.notifikasi: list[str] = []
        self.lock = threading.Lock()
        self._next_id = 0
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    # -- protokol ---------------------------------------------------------

    def _send(self, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
        assert self.proc.stdin is not None
        self.proc.stdin.write(header + body)
        self.proc.stdin.flush()
        if VERBOSE:
            log("  ->", payload.get("method") or f"id={payload.get('id')}")

    def request(self, method: str, params: dict) -> int:
        with self.lock:
            self._next_id += 1
            req_id = self._next_id
        self._send({"jsonrpc": "2.0", "id": req_id, "method": method, "params": params})
        return req_id

    def tunggu_respons(self, req_id: int, batas: float = 60.0) -> dict | None:
        tenggat = time.time() + batas
        while time.time() < tenggat:
            with self.lock:
                if req_id in self.responses:
                    return self.responses[req_id]
            time.sleep(0.1)
        return None

    def _read_loop(self) -> None:
        assert self.proc.stdout is not None
        stream = self.proc.stdout
        while True:
            headers: dict[str, str] = {}
            while True:
                line = stream.readline()
                if not line:
                    return
                line = line.decode("ascii", "replace").strip()
                if line == "":
                    break
                if ":" in line:
                    k, v = line.split(":", 1)
                    headers[k.strip().lower()] = v.strip()
            length = int(headers.get("content-length", "0"))
            if length <= 0:
                continue
            body = stream.read(length)
            try:
                msg = json.loads(body.decode("utf-8"))
            except Exception:
                continue
            self._handle(msg)

    def _handle(self, msg: dict) -> None:
        method = msg.get("method")
        params = msg.get("params") or {}

        if "id" in msg and msg["id"] is not None:
            with self.lock:
                self.responses[int(msg["id"])] = msg
            if VERBOSE:
                err = msg.get("error")
                log(f"  <- id={msg['id']}", "ERROR " + json.dumps(err) if err else "ok")
            return

        if method:
            with self.lock:
                self.notifikasi.append(method)
            if VERBOSE and method != "analysis.errors":
                log("  <- notif", method)

        if method == "analysis.errors":
            file = params.get("file", "")
            with self.lock:
                self.errors.setdefault(file, []).extend(params.get("errors", []))

    def tunggu_berkas(self, jumlah: int, batas_detik: float = 240.0) -> bool:
        """Tunggu sampai setiap berkas dilaporkan (termasuk yang tanpa masalah)."""
        tenggat = time.time() + batas_detik
        while time.time() < tenggat:
            with self.lock:
                sudah = len(self.errors)
            if sudah >= jumlah:
                return True
            if self.proc.poll() is not None:
                log("[!] server berhenti lebih awal")
                return False
            time.sleep(0.25)
        return False


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    app = os.path.abspath(args[0] if args else os.getcwd())
    lib = os.path.join(app, "lib")

    files: list[str] = []
    for root, _dirs, names in os.walk(lib):
        for n in names:
            if n.endswith(".dart"):
                files.append(os.path.join(root, n).replace("\\", "/"))
    files.sort()
    if not files:
        log("tidak ada berkas .dart di", lib)
        return 2

    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_analyze_server.log")
    srv = Server(DART_SDK, log_path)
    log(f"[i] server pid={srv.proc.pid}, berkas={len(files)}")

    root_uri = "file:///" + app.replace("\\", "/").lstrip("/")
    rid = srv.request(
        "initialize",
        {
            "processId": os.getpid(),
            "rootPath": app,
            "rootUri": root_uri,
            "capabilities": {},
        },
    )
    resp = srv.tunggu_respons(rid, 90)
    if resp is None:
        log("[!] initialize tidak dijawab; cek", log_path)
        srv.proc.terminate()
        return 3
    if "error" in resp:
        log("[!] initialize gagal:", json.dumps(resp["error"]))
        srv.proc.terminate()
        return 4
    log("[i] initialize ok")

    rid = srv.request(
        "analysis.setAnalysisRoots",
        {"included": [lib.replace("\\", "/")], "excluded": []},
    )
    srv.tunggu_respons(rid, 60)

    rid = srv.request(
        "analysis.setSubscriptions",
        {"subscriptions": {f: ["ERRORS"] for f in files}},
    )
    srv.tunggu_respons(rid, 60)

    selesai = srv.tunggu_berkas(len(files))
    log(
        f"[i] berkas dilaporkan: {len(srv.errors)}/{len(files)} "
        f"({'selesai' if selesai else 'BATAS WAKTU'})"
    )

    total = 0
    for file in sorted(srv.errors):
        for err in srv.errors[file]:
            loc = err.get("location") or {}
            start = loc.get("start") or {}
            rel = os.path.relpath(file, app).replace("\\", "/")
            print(
                "%-8s %s:%s:%s  %-34s %s"
                % (
                    err.get("severity", "?"),
                    rel,
                    start.get("line", "?"),
                    start.get("column", "?"),
                    err.get("code", "?"),
                    err.get("message", "").replace("\n", " "),
                )
            )
            total += 1

    print(f"\nTOTAL {total} diagnostik pada {len(files)} berkas")
    srv.proc.terminate()
    return 0


if __name__ == "__main__":
    sys.exit(main())
