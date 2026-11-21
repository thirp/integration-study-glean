"""A negative control must receive zero bytes, including HTTP error headers."""
import socket
import time
from pathlib import Path

token = Path("/run/wiki.token").read_text().strip()
started = time.monotonic()
try:
    with socket.create_connection(("127.0.0.1", 18080), timeout=4) as conn:
        conn.settimeout(4)
        conn.sendall(f"GET /pages HTTP/1.0\r\nAuthorization: Bearer {token}\r\n\r\n".encode())
        if conn.recv(1):
            raise SystemExit("Unexpected response bytes from the source")
        outcome = "EOF"
except (ConnectionRefusedError, ConnectionResetError, BrokenPipeError) as exc:
    outcome = type(exc).__name__
print(f"Zero response bytes: {outcome} after {time.monotonic() - started:.2f}s")
