import time
from pathlib import Path
from urllib.request import ProxyHandler, Request, build_opener

token = Path("/run/wiki.token").read_text().strip()
req = Request("http://127.0.0.1:18080/study-stream", headers={"Authorization": "Bearer " + token})
with build_opener(ProxyHandler({})).open(req, timeout=5) as stream:
    if stream.read(1) != b"x":
        raise SystemExit("Missing initial wiki byte")
    Path("/tmp/stream-ready").touch()
    started = time.monotonic()
    count = 1
    try:
        while stream.read(1):
            count += 1
    except ConnectionResetError:
        pass
    if not Path("/tmp/revocation-started").exists():
        raise SystemExit("Active stream closed before revocation started")
    print(f"Established stream closed after {count} wiki bytes and {time.monotonic()-started:.2f}s from first byte")
    Path("/tmp/stream-ended").touch()
