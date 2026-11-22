# Glean integration study • private wiki baseline

This milestone measures the source side of a custom Glean indexing connector. Two synthetic wiki pages travel over HTTP and become Glean SDK DocumentDefinition objects. The reference output in `expected/documents.json` uses the SDK's wire aliases and stable ID order. A later transport can be tested against those exact bytes. The example page links are synthetic canonical identifiers independent of the fetch address.

## Run the network experiment

From the repository root on a Linux Docker Engine host with Docker Compose v2.20+ and internet access for the initial image build, run:

```sh
./test-compose.sh
```

The base Compose file puts the wiki and connector on disjoint internal bridge networks and publishes no ports. The direct override also attaches the connector to the customer network. The script starts a healthy wiki, runs the direct connector twice, and compares both outputs byte for byte with the reference. It then launches the same image without the override and attempts HTTP reads by service name and container IPv4 address. Testing the address separately catches a reachable source hidden only by DNS. Any HTTP response, malformed source data, unexpected socket error or successful read fails the isolation test. A final direct read checks that the wiki is still serving the expected content. The script removes its project containers and networks on exit.

To print the direct reference run manually:

```sh
docker compose -f compose.yaml -f compose.direct.yaml build
docker compose up -d --wait wiki
docker compose -f compose.yaml -f compose.direct.yaml run --rm -T connector
docker compose down
```

## Run the document test without containers

From the repository root, using Python 3.12:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest -v
```

The test starts the actual wiki on an ephemeral loopback port and invokes the connector CLI in two fresh processes. The reference exercises reversed source order, UTF-8, multiline content and canonical document URLs. The source fixture is in `fixtures/pages.json`. Dependencies are pinned for Python 3.12.

## Scope and attribution

The connector adapts Glean's [non-streaming wiki example](https://github.com/gleanwork/glean-indexing-sdk/blob/ee846524264723549ef24dd32ef4324844268f9e/snippets/non_streaming/complete.py). It uses BaseDataClient, BaseDatasourceConnector.get_data(), transform(), ContentDefinition and DocumentDefinition from glean-indexing-sdk 1.2.2. The upstream MIT license and copyright appear in [licenses/Glean-MIT.txt](licenses/Glean-MIT.txt).

The experiment ends at document serialization. Tenant uploads, identity and ACL synchronization, Thirp Runtime and Thirp Cloud for Platforms are outside this milestone. No tenant credentials are required.

GitHub Actions runs `./test-compose.sh` on a Linux runner for pushes to `dev/private-wiki-baseline`. Open the **Private wiki baseline** run for the tested commit to inspect the observed DNS and IPv4 outcomes.

## Milestone 2 • self-hosted Thirp Runtime

On Linux x86-64 with Docker Compose v2.20+, OpenSSL and internet access for the image build, run:

```sh
./test-compose.sh
./test-runtime.sh
```

The second test starts the private wiki and a self-hosted TLS broker. A customer-side Agent registers `study/wiki` with the broker and forwards authorized streams to `wiki:8080`. The caller exposes the service at `127.0.0.1:18080` in the reader's network namespace. The original Glean connector receives that URL as its only application-level configuration change. Its canonical document URLs remain stable.

Compose creates the networks and starts the processes. The broker enforces its local production-mode policy from `runtime/broker.conf`, with separate per-run registration and connection credentials restricted to the named wiki. The reader has no customer-network attachment. The test reads through Runtime, probes direct DNS and IPv4 access from the same namespace, reads through Runtime again, and compares both results against the baseline. Generated credentials are removed during teardown.

The Runtime image verifies the pinned Linux operator archive against its SHA-256 digest. See the [v0.16.11 release](https://github.com/thirp/runtime/releases/tag/v0.16.11) and [operator configuration](https://github.com/thirp/runtime/blob/v0.16.11/docs/OPERATIONS.md).

## Source records and wiki authentication

Run `./test-compose.sh` and `./test-runtime.sh` with OpenSSL installed. Each script generates a disposable wiki bearer token. Manual Compose runs use a synthetic fixture token by default. Only the wiki and its readers receive that application credential.

Each path emits a JSON evidence line containing the fetched records in source order, transformed document IDs, document SHA-256, and wiki authentication results. Both paths compare every fetched field with the same fixture and the serialized documents with the same reference. The successful read and the two rejected reads use the same URL. The rejected reads must return HTTP 401 and the wiki's bearer challenge, for both an absent token and an incorrect token. The source fixture defines no document ACL fields. The existing network isolation probes run separately.

## Milestone 3 • hosted Platforms

[Hosted Platforms runbook](cloud/README.md).

Complete. On 2026-11-22, `./test-cloud.sh` passed twice in a row, each time from a fresh clean clone, against hosted Thirp Cloud for Platforms. The runs used the commit that `3e3f3989` replaced when this repository's history was rewritten to remove internal names. Its code and test files are byte-identical to that commit. The only difference is one status line in `STATE.md`. Both runs printed `PASS: hosted wiki documents, isolation, application authentication, credential controls and agent recovery`. The hosted documents matched `expected/documents.json` (SHA-256 `35474f96…8d56`). The wiki returned 401 for missing and invalid credentials. Direct wiki DNS and IPv4 access failed. An invalid caller, a stopped Agent and a revoked caller each received zero wiki bytes, and hosted reads resumed after the Agent restart. Both runs were made by the study operator on one host. A reproduction by a separate party has not been done.
