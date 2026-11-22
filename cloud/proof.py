"""Build a proof from checked study output and scan the saved transcript."""

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from tempfile import NamedTemporaryFile

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "expected/documents.json"
PROOF_DIR = REPO / "cloud/proof"
PROGRESS = [
    "Building and starting the hosted study containers",
    "Active wiki response confirmed. Revoking the disposable caller.",
]
CHECKS = [
    "Direct wiki DNS lookup and IPv4 access failed",
    "Invalid caller credential returned zero wiki bytes",
    "Stopped Agent returned zero wiki bytes. Hosted reads recovered after restart.",
    "Revoked caller returned zero wiki bytes on fresh reads. Local wiki still matched the baseline.",
]
PASS = "PASS: hosted wiki documents, isolation, application authentication, credential controls and agent recovery"
STREAM = r"Established stream closed after [1-9][0-9]* wiki bytes and [0-9]+\.[0-9]{2}s from first byte"
CREDENTIAL = re.compile(
    r"thirp_(?:agt|brk|cal|cen|enr|int|ops)_[0-9a-z_-]+"
    r"|-----BEGIN [^-]+-----|\bAuthorization:\s*Bearer\s+\S+"
    r"|\b(?:api|broker|enrollment|environment|map|org|service|tls_ca|tls_server_name|token(?:_file)?|wiki_token)\s*=",
    re.IGNORECASE,
)


def evidence_line(baseline, digest):
    return json.dumps(
        {
            "records": json.loads((REPO / "fixtures/pages.json").read_bytes()),
            "document_ids": [doc["id"] for doc in json.loads(baseline)],
            "documents_sha256": digest,
            "wiki_auth": {"valid": "accepted", "missing": 401, "invalid": 401},
        },
        ensure_ascii=False,
        sort_keys=True,
    )


def proof_lines(head, timestamp, digest, evidence, stream):
    return [
        f"git rev-parse HEAD {head}",
        "git status --porcelain=v1 --untracked-files=all clean",
        f"UTC {timestamp}",
        f"{digest}  expected/documents.json",
        f"{digest}  hosted/documents.json",
        evidence,
        *CHECKS,
        stream,
        PASS,
    ]


def scan_credentials(data):
    if CREDENTIAL.search(data):
        raise ValueError


def validate_proof(data):
    scan_credentials(data)
    lines = data.splitlines()
    head = lines[0].removeprefix("git rev-parse HEAD ")
    timestamp = lines[2].removeprefix("UTC ")
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", head):
        raise ValueError
    datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ")
    stream = lines[-2]
    if not re.fullmatch(STREAM, stream):
        raise ValueError
    baseline = BASELINE.read_bytes()
    digest = hashlib.sha256(baseline).hexdigest()
    expected = proof_lines(head, timestamp, digest, evidence_line(baseline, digest), stream)
    if data != "\n".join(expected) + "\n":
        raise ValueError
    return head


def prepare(stage, head):
    baseline = BASELINE.read_bytes()
    hosted = (stage / "documents").read_bytes()
    if hosted != baseline:
        raise ValueError
    digest = hashlib.sha256(hosted).hexdigest()
    evidence = (stage / "evidence.json").read_text(encoding="utf-8").removesuffix("\n")
    stream = (stage / "stream").read_text(encoding="utf-8").removesuffix("\n")
    utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = "\n".join(proof_lines(head, utc, digest, evidence, stream)) + "\n"
    validate_proof(data)
    encoded = data.encode()
    for path in (*stage.rglob("*.token"), *stage.rglob("*.conf"), *stage.rglob("*.crt")):
        contents = path.read_bytes().strip()
        if contents and contents in encoded:
            raise ValueError
    sys.stdout.write(data)


def publish(data):
    head = validate_proof(data)
    PROOF_DIR.mkdir(exist_ok=True)
    with NamedTemporaryFile(dir=PROOF_DIR, mode="w", encoding="utf-8") as temporary:
        temporary.write(data)
        temporary.flush()
        os.link(temporary.name, PROOF_DIR / f"{head}.txt")
    sys.stdout.write(data)


def scan_log(path):
    data = path.read_bytes().decode("utf-8")
    scan_credentials(data)
    lines = data.splitlines(keepends=True)
    for message in PROGRESS:
        if lines and lines[0] == message + "\n":
            lines.pop(0)
        else:
            break
    if lines and lines[0].startswith("git rev-parse HEAD "):
        proof = "".join(lines)
        head = validate_proof(proof)
        if proof.encode() != (PROOF_DIR / f"{head}.txt").read_bytes():
            raise ValueError
    elif not lines or any(
        not re.fullmatch(r"FAIL: [A-Za-z0-9_., /-]{1,120}\n", line)
        or re.search(r"[0-9a-fA-F]{64}", line)
        for line in lines
    ):
        raise ValueError


if __name__ == "__main__":
    try:
        action, *args = sys.argv[1:]
        if action == "prepare":
            prepare(Path(args[0]), args[1])
        elif action == "publish":
            publish(sys.stdin.read())
        elif action == "scan":
            scan_log(Path(args[0]))
        else:
            raise ValueError
    except (IndexError, OSError, ValueError):
        sys.exit("Study proof or log failed validation")
