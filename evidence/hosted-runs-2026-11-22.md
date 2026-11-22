# Hosted Platforms runs, 2026-11-22

These are the complete console outputs of two consecutive `./test-cloud.sh` runs against hosted Thirp Cloud for Platforms. Each run started from a fresh clean clone.

- Tested commit: `73dc83ac093533fc2133f40fe7c7a8fc9c4c2e12`, from before this repository's history was rewritten to remove internal working files. Its code and test files are byte-identical to `0ea3f810` in this repository.
- Redactions: none were needed. The script prints no tokens, enrollment or caller credentials, hostnames, IP addresses, usernames or home paths, so both logs are reproduced unchanged.
- Raw logs: [run 1](hosted-run1-2026-11-22.log) and [run 2](hosted-run2-2026-11-22.log).

The two runs differ only in their printed timestamp and in the established-stream line. That line reports how much the live stream carried before revocation closed it, which varies from run to run.

| | Run 1 | Run 2 |
| --- | --- | --- |
| Timestamp (UTC) | 2026-11-22T19:41:43Z | 2026-11-22T19:43:23Z |
| `documents.json` SHA-256 | `35474f96…8d56` | `35474f96…8d56` |
| Wiki auth (missing / invalid) | 401 / 401 | 401 / 401 |
| Direct wiki DNS and IPv4 | failed | failed |
| Invalid caller, stopped Agent, revoked caller | zero wiki bytes | zero wiki bytes |
| Established stream closed after | 54 bytes, 13.29 s | 44 bytes, 10.99 s |
| Result | PASS | PASS |

## Run 1

```text
Building and starting the hosted study containers
Active wiki response confirmed. Revoking the disposable caller.
git rev-parse HEAD 73dc83ac093533fc2133f40fe7c7a8fc9c4c2e12
git status --porcelain=v1 --untracked-files=all clean
UTC 2026-11-22T19:41:43Z
35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56  expected/documents.json
35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56  hosted/documents.json
{"document_ids": ["cafe", "rotation"], "documents_sha256": "35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56", "records": [{"content": "Week A: platform.\nWeek B: operations.", "heading": "On-call rotation", "slug": "rotation"}, {"content": "Kitchen hours: 08:00–16:00.", "heading": "Café handbook", "slug": "cafe"}], "wiki_auth": {"invalid": 401, "missing": 401, "valid": "accepted"}}
Direct wiki DNS lookup and IPv4 access failed
Invalid caller credential returned zero wiki bytes
Stopped Agent returned zero wiki bytes. Hosted reads recovered after restart.
Revoked caller returned zero wiki bytes on fresh reads. Local wiki still matched the baseline.
Established stream closed after 54 wiki bytes and 13.29s from first byte
PASS: hosted wiki documents, isolation, application authentication, credential controls and agent recovery
```

## Run 2

```text
Building and starting the hosted study containers
Active wiki response confirmed. Revoking the disposable caller.
git rev-parse HEAD 73dc83ac093533fc2133f40fe7c7a8fc9c4c2e12
git status --porcelain=v1 --untracked-files=all clean
UTC 2026-11-22T19:43:23Z
35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56  expected/documents.json
35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56  hosted/documents.json
{"document_ids": ["cafe", "rotation"], "documents_sha256": "35474f96f50f1797c16105fd90cad6e1fac4e67805e629666558a41b64ab8d56", "records": [{"content": "Week A: platform.\nWeek B: operations.", "heading": "On-call rotation", "slug": "rotation"}, {"content": "Kitchen hours: 08:00–16:00.", "heading": "Café handbook", "slug": "cafe"}], "wiki_auth": {"invalid": 401, "missing": 401, "valid": "accepted"}}
Direct wiki DNS lookup and IPv4 access failed
Invalid caller credential returned zero wiki bytes
Stopped Agent returned zero wiki bytes. Hosted reads recovered after restart.
Revoked caller returned zero wiki bytes on fresh reads. Local wiki still matched the baseline.
Established stream closed after 44 wiki bytes and 10.99s from first byte
PASS: hosted wiki documents, isolation, application authentication, credential controls and agent recovery
```
