"""Stage only the files referenced by the two dedicated enrollments."""
import os
import secrets
import shutil
from pathlib import Path

root = Path(os.environ["CLOUD_TMP"])
services = []
for role in ("agent", "caller"):
    src = Path(os.environ[f"STUDY_{role.upper()}_CONF"]).resolve(strict=True)
    dest = root / role
    dest.mkdir(mode=0o700)
    lines = []
    mappings = []
    for line in src.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, sep, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not sep:
            raise SystemExit(f"Malformed {role} config")
        if key in ("token_file", "tls_ca") and value:
            name = role + ".token" if key == "token_file" else "ca.crt"
            shutil.copyfile(src.parent / value, dest / name)
            (dest / name).chmod(0o600)
            value = "/run/thirp/" + name
        if key in ("map", "service"):
            mappings.append(value)
        lines.append(f"{key} = {value}")
    if len(mappings) != 1 or not (dest / (role + ".token")).stat().st_size:
        raise SystemExit(f"Expected one dedicated {role} service and a token")
    if role == "agent":
        service, _, target = mappings[0].rpartition("=")
        if target.strip() != "wiki:8080":
            raise SystemExit("Agent mapping must target wiki:8080")
    else:
        service, _, target = mappings[0].partition(" listen")
        if target.partition("=")[2].strip() != "127.0.0.1:18080":
            raise SystemExit("Caller mapping must listen on 127.0.0.1:18080")
    services.append(service.strip())
    (dest / (role + ".conf")).write_text("\n".join(lines) + "\n")
if services[0] != services[1]:
    raise SystemExit("Agent and caller must use the same catalog Service ID")
(root / "wiki.token").write_text(secrets.token_hex(32))
