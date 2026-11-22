# Hosted Platforms study

The Glean customer owns the Platforms account, Service, Agent and caller. The customer runs the caller beside the Glean SDK connector. Docker separates the private wiki from the reader and gives the Agent and caller separate outbound networks. The reader uses the caller's loopback listener and both endpoints reach the hosted Thirp rendezvous.

## Set up once

1. Create a fresh, dedicated Platforms account. Use a $0 signup if the console offers one for the study, or complete paid Checkout. [Platforms signup](https://thirp.net/cloud-for-platforms/)
2. In the Platforms console, create a named Service such as `study-wiki`. In **Agents**, select that Service and enroll a new Linux x86-64 Agent to get its one-use token. If the form asks for a numeric target, enter `127.0.0.1:8080`. The study uses the token from the receipt and configures the real Docker target in the next step. Creating the Service and issuing the Agent enrollment token are console steps for owner CLI 0.1.5.
3. Install the owner CLI 0.1.5 on the runner and sign in as the study account owner. The CLI commands below use the same arguments on Windows, macOS and Linux. Run `thirp login` for browser login or `thirp login --device` for headless login. Find the Service in the list and use its `service_id` value, for example `study-wiki`. [CLI 0.1.5 release](https://github.com/thirp/cloud/releases/tag/cli-0.1.5)

   ```text
   thirp login
   thirp services list
   ```

4. On the Linux runner, save the one-use token in a private mode-0600 file outside the checkout. From the repository root, run setup with that file and a new private enrollment directory. Delete the spent one-use token file after setup succeeds.

   ```bash
   export STUDY_SERVICE_ID=study-wiki
   ./cloud/setup.sh /absolute/path/to/enrollment.token /absolute/path/to/agent-enrollment
   ```

Setup confirms the Service with `thirp services list`, exchanges the token with `thirp agent enroll ENROLLMENT_TOKEN --dir AGENT_DIRECTORY`, and adds the `STUDY_SERVICE_ID=wiki:8080` map to `agent.conf`. CLI 0.1.5 accepts a numeric target in its enrollment `--map` flag. Runtime resolves the Docker hostname in the config. The setup script reads the token file privately and passes the token in the positional argument required by the CLI. Preserve the Agent config, token and CA together in the private directory.

## Run unattended on Linux x86-64

Use a clean Git checkout, Docker Engine with Compose v2, Python 3.9 or later, a system CA bundle, and internet access for the image build and hosted services. Use the same Linux account and owner CLI session that ran setup. The build verifies the pinned Runtime 0.16.11 archive by SHA-256.

From the repository root in Bash, with `STUDY_SERVICE_ID` set as above, run:

```bash
export STUDY_AGENT_CONF=/absolute/path/to/agent-enrollment/agent.conf
set -o pipefail
study_status=0
./test-cloud.sh 2>&1 | tee cloud-run.log || study_status=$?
python3 cloud/proof.py scan cloud-run.log && test "$study_status" -eq 0
```

The runner checks the existing owner session and enrolls a fresh disposable caller. It stages the Agent and caller files in a private temporary directory, mounts them read-only and generates a synthetic wiki bearer token. It tests the invalid credential, two hosted reads around the direct DNS and IPv4 isolation probe, wiki authentication and recovery from stopping the Agent. It opens a slow wiki response, revokes the caller through the owner CLI and checks that the active stream closes, fresh connections get zero wiki bytes and the local wiki still returns the baseline.

On failure or interruption, teardown tries to revoke any disposable caller created by the run, removes the study containers and deletes the staged files. If it reports that revocation could not be confirmed, use the reported caller name to locate the enrollment in the Platforms console once connectivity returns.

A successful run writes `cloud/proof/<head-sha>.txt` with the commit, clean-tree result, UTC date, both document hashes, JSON evidence, and PASS result. The log scan runs after `tee` finishes, including for failed runs. Keep the proof for review and publication. Move any previous untracked proof out of the checkout before repeating the run from the same commit.

Independent reproduction starts with a fresh Platforms account and follows the same steps on a separate Linux x86-64 Docker host.

[Platforms workflow](https://thirp.net/how-it-works/platforms/) · [Owner CLI](https://github.com/thirp/cloud/blob/main/docs/cli.md) · [Runtime caller enrollment](https://github.com/thirp/runtime/blob/v0.16.11/caller_cli/README.md#caller-enrollment)
