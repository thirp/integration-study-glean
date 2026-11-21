# Hosted Platforms study

The Glean customer owns the Platforms account, Service, Agent and caller. The customer runs the caller alongside the developer-controlled Glean SDK connector. Docker supplies a customer-only network and separate outbound networks for the Agent and caller. The reader shares the caller's loopback interface. Thirp supplies the hosted rendezvous.

## Enroll once on the machine that will use the credentials

Use a dedicated Platforms account and the [published CLI 0.1.5](https://github.com/thirp/cloud/releases/tag/cli-0.1.5). The commands below use the same arguments on Windows, macOS and Linux. Replace the uppercase placeholders with actual values and quote paths containing spaces. Keep enrollment directories outside the repository. For this container experiment enroll on the Linux runner. Use a fresh disposable caller for each full test because the last step revokes it.

1. In the Platforms console create one named Service, for example **study-wiki**, and an Agent for that Service. Save the one-use Agent enrollment token privately.
2. Run the following with the study owner's account. Device login is available as `thirp login --device` on a headless host. Use the catalog Service ID shown for the study by the console or CLI. Copy the caller enrollment ID from the list and check its name before the revocation step.

```text
thirp login
thirp services list
thirp agent enroll ENROLLMENT_TOKEN --dir AGENT_DIRECTORY --map SERVICE_ID=wiki:8080
thirp caller enroll --name glean-study-disposable --dir CALLER_DIRECTORY --map SERVICE_ID=127.0.0.1:18080
thirp caller list
```

The enrolled files supply the API, regional broker, TLS settings and machine credentials. Preserve file permissions and the token and CA files alongside each configuration. Use the same machine for enrollment and Runtime. The published caller has a 90-day credential and checks for renewal within 30 days of expiry. This short test mounts staged files read-only and requires a fresh caller outside that rotation window. A continuing deployment must permit atomic token renewal.

## Run locally on Linux x86-64

Requires Docker Engine with Compose v2, Python 3, OpenSSL, a system CA bundle, and two terminals. The script builds the same digest-verified Runtime 0.16.11 archive as the self-hosted experiment. In Bash, from the repository root:

```bash
export STUDY_AGENT_CONF=/absolute/path/to/agent.conf
export STUDY_CALLER_CONF=/absolute/path/to/caller.conf
set -o pipefail
./test-cloud.sh 2>&1 | tee cloud-run.log
```

These are study script variables. Their values are file paths. For an input configuration with relative credential or CA paths, keep its referenced files in the enrolled layout. The script stages copies in a temporary private directory and uses container paths in the copies. The wiki receives a fresh synthetic application credential.

The sequence checks an invalid caller token, reads the baseline through the valid enrollment twice around a direct DNS/IP probe, runs the record and wiki-authentication checks, then stops and restarts the Agent. It opens a slow authenticated wiki response before prompting for revocation. In the second terminal run `thirp caller revoke CALLER_ENROLLMENT_ID` for the **disposable study caller**. After CLI success, press Enter in the first terminal. The script checks stream closure, fresh connection failures and local wiki health. The observation timestamps include operator response time. Runtime documentation describes separate enrollment and broker credentials.

A successful run ends with two matching hashes and a PASS result. Teardown removes the study containers, networks and staged files. Keep the owner originals under your own credential management. Review the local log before linking it as measured evidence. A second operator should repeat from signup and enrollment on their own host before publication.

[Platforms workflow](https://thirp.net/how-it-works/platforms/) · [Agent enrollment](https://github.com/thirp/cloud/blob/main/docs/enroll.md) · [Owner CLI](https://github.com/thirp/cloud/blob/main/docs/cli.md) · [Runtime caller enrollment](https://github.com/thirp/runtime/blob/v0.16.11/caller_cli/README.md#caller-enrollment)
