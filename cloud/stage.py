"""Stage the files needed by the Runtime containers in a private directory."""

import os
import secrets
import shutil
import sys
from pathlib import Path


def enrollment_file(src, value):
    path = Path(value)
    candidate = src.parent / path
    # With a relative --dir, the CLI prefixes agent.token and broker.crt with
    # that directory. They still sit alongside the generated agent.conf.
    if not candidate.is_file() and not path.is_absolute() and len(path.parts) > 1:
        if src.parent.parts[-len(path.parent.parts):] == path.parent.parts:
            return src.parent / path.name
    return candidate


def stage(role, destination, source, service, caller_id=None):
    source = source.resolve(strict=True)
    destination.mkdir(mode=0o700)
    entries = {}
    for line in source.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, sep, value = line.partition("=")
        key = key.strip()
        if not sep or key in entries or key == "token":
            raise ValueError
        entries[key] = value.strip()

    if role == "agent":
        if entries.get("map") != f"{service}=wiki:8080" or "service" in entries:
            raise ValueError
    else:
        if entries["service"].split() != [service, "listen", "=", "127.0.0.1:18080"]:
            raise ValueError
        if entries["enrollment"] != caller_id or entries["environment"]:
            raise ValueError

    if not entries["token_file"]:
        raise ValueError
    for field, name in (("token_file", f"{role}.token"), ("tls_ca", "ca.crt")):
        value = entries.get(field)
        if value:
            original = enrollment_file(source, value)
            if not original.is_file() or not original.stat().st_size:
                raise ValueError
            shutil.copyfile(original, destination / name)
            entries[field] = f"/run/thirp/{name}"
    (destination / f"{role}.conf").write_text(
        "".join(f"{key} = {value}\n" for key, value in entries.items()),
        encoding="utf-8",
    )


def main(role, service, caller_id=None):
    os.umask(0o077)
    root = Path(os.environ["CLOUD_TMP"])
    if role == "agent":
        stage(role, root / role, Path(os.environ["STUDY_AGENT_CONF"]), service)
        (root / "wiki.token").write_text(secrets.token_hex(32), encoding="ascii")
        (root / "invalid.token").write_text("thirp_cen_" + secrets.token_hex(32) + "\n", encoding="ascii")
    elif role == "caller":
        stage(role, root / role, root / "caller-enrollment/caller.conf", service, caller_id)
    else:
        raise ValueError


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except (KeyError, OSError, ValueError):
        sys.exit("Could not stage the dedicated enrollment files")
