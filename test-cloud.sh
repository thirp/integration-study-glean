#!/bin/sh
set +x
set -eu

# Only publish study messages and checked evidence. CLI and container diagnostics
# stay off the transcript, including when they report a credential failure.
exec 3>&1
exec </dev/null >/dev/null 2>&1
report() { printf '%s\n' "$1" >&3; }
fail() { report "FAIL: $1"; exit 1; }

cd "$(dirname "$0")" || fail "Could not enter the study checkout"
command -v thirp >/dev/null || fail "Install the thirp owner CLI on PATH"
[ -n "${STUDY_AGENT_CONF:-}" ] && [ -f "$STUDY_AGENT_CONF" ] && [ -r "$STUDY_AGENT_CONF" ] ||
    fail "Set STUDY_AGENT_CONF to the readable enrolled agent.conf"
[ -n "${STUDY_SERVICE_ID:-}" ] || fail "Set STUDY_SERVICE_ID to the Platforms Service ID"
command -v python3 >/dev/null || fail "Install Python 3"

clean_tree() {
    tree_status=$(git status --porcelain=v1 --untracked-files=all) || return 1
    [ -z "$tree_status" ]
}
head=$(git rev-parse HEAD) || fail "Could not read Git HEAD"
clean_tree || fail "The proof requires a clean Git checkout"
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] ||
    fail "Run the study on Linux x86-64"

services=$(thirp services list) ||
    fail "Could not list Services. Check the owner login, account and network."
catalog_id=$(printf '%s\n' "$services" | python3 cloud/owner.py service "$STUDY_SERVICE_ID") ||
    fail "Expected the enabled account Service in thirp services list"

CLOUD_SYSTEM_CA=
for bundle in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt; do
    if [ -r "$bundle" ]; then CLOUD_SYSTEM_CA=$(realpath "$bundle"); break; fi
done
[ -n "${CLOUD_SYSTEM_CA:-}" ] || fail "Missing system CA bundle"
docker info >/dev/null && docker compose version >/dev/null || fail "Docker Engine and Compose v2 are required"

umask 077
CLOUD_TMP=$(mktemp -d /tmp/glean-study-XXXXXXXXXX) || fail "Could not create private staging directory"
export CLOUD_TMP CLOUD_SYSTEM_CA
caller_name=${CLOUD_TMP##*/}
caller_id=
enroll_attempted=no
enrolled=no
containers_started=no
watch_pid=

dc() { docker compose -p "glean-cloud-$$" -f compose.cloud.yaml "$@"; }

find_caller() {
    callers=$(thirp caller list) || return 1
    printf '%s\n' "$callers" | python3 cloud/owner.py caller "$caller_name"
}

revoke_caller() {
    thirp caller revoke "$caller_id" || return 1
    enroll_attempted=no
}

cleanup_caller() {
    [ "$enroll_attempted" = yes ] || return 0
    # The POST can succeed before local file writes or before the CLI returns.
    # Recover by name even when enroll failed or the first lookup failed.
    for attempt in 1 2 3; do
        if [ -n "$caller_id" ] || caller_id=$(find_caller); then
            if [ -n "$caller_id" ]; then
                if revoke_caller; then return 0; fi
            elif [ "$enrolled" = no ] && [ "$attempt" -eq 3 ]; then
                return 0
            fi
        fi
        if [ "$attempt" -lt 3 ]; then sleep 1; fi
    done
    return 1
}

teardown() {
    [ "$containers_started" = yes ] || return 0
    dc down --remove-orphans || return 1
    containers_started=no
}

cleanup() {
    status=$?
    trap - EXIT
    trap '' HUP INT TERM
    if [ "$status" -ne 0 ]; then report "FAIL: $step"; fi
    if ! cleanup_caller; then
        report "FAIL: Could not confirm revocation for $caller_name"
        status=1
    fi
    if [ -n "$watch_pid" ]; then kill "$watch_pid" 2>/dev/null || :; fi
    if ! teardown; then report "FAIL: Could not tear down study containers"; status=1; fi
    if ! rm -rf -- "$CLOUD_TMP"; then report "FAIL: Could not delete temporary enrollment files"; status=1; fi
    exit "$status"
}

step="Could not stage the enrolled Agent for the study Service"
trap cleanup EXIT
trap 'step="Interrupted"; exit 1' HUP INT TERM
python3 cloud/stage.py agent "$STUDY_SERVICE_ID"

step="Could not enroll the disposable caller"
enroll_attempted=yes
thirp caller enroll --name "$caller_name" --dir "$CLOUD_TMP/caller-enrollment" \
    --map "$catalog_id=127.0.0.1:18080"
enrolled=yes
step="Could not identify or stage the disposable caller"
caller_id=$(find_caller)
[ -n "$caller_id" ]
python3 cloud/stage.py caller "$catalog_id" "$caller_id"

step="Could not build or start the study containers"
report "Building and starting the hosted study containers"
dc build wiki reader agent
containers_started=yes
dc up -d wiki reader
dc up -d agent

# Keep the same reader namespace and caller configuration for both credentials.
step="Invalid caller credential did not produce a clear zero-byte failure"
mv "$CLOUD_TMP/caller/caller.token" "$CLOUD_TMP/valid.token"
cp "$CLOUD_TMP/invalid.token" "$CLOUD_TMP/caller/caller.token"
dc up -d caller
sleep 5
[ -n "$(dc ps -q --status running caller)" ]
dc exec -T reader python cloud_check.py
dc stop caller
mv "$CLOUD_TMP/valid.token" "$CLOUD_TMP/caller/caller.token"
dc start caller

read_docs() {
    dc exec -T reader sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python connector.py http://127.0.0.1:18080' > "$CLOUD_TMP/documents"
}

await_docs() {
    for attempt in $(seq 1 20); do
        if read_docs; then
            cmp expected/documents.json "$CLOUD_TMP/documents"
            return $?
        fi
        sleep 1
    done
    return 1
}

step="The first hosted read did not match the baseline"
await_docs
step="Direct DNS or IPv4 isolation check failed"
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(dc ps -q wiki)")
[ -n "$ip" ]
dc exec -T reader python probe.py "$ip" > "$CLOUD_TMP/isolation"
grep -q '^wiki: DNS lookup blocked ' "$CLOUD_TMP/isolation"
step="The second hosted read did not match the baseline"
read_docs
cmp expected/documents.json "$CLOUD_TMP/documents"
step="Hosted record or wiki authentication evidence failed"
dc exec -T reader sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python evidence.py http://127.0.0.1:18080' > "$CLOUD_TMP/evidence.json"

step="Stopped Agent did not produce a clear zero-byte failure"
dc stop agent
dc exec -T reader python cloud_check.py
step="The hosted read did not recover after the Agent restarted"
dc start agent
await_docs

step="Could not establish an active wiki stream for revocation"
dc exec -T reader python watch.py > "$CLOUD_TMP/stream" &
watch_pid=$!
for attempt in $(seq 1 15); do
    if dc exec -T reader test -f /tmp/stream-ready; then break; fi
    kill -0 "$watch_pid" || exit 1
    sleep 1
done
dc exec -T reader test -f /tmp/stream-ready
report "Active wiki response confirmed. Revoking the disposable caller."
dc exec -T reader touch /tmp/revocation-started
step="Owner CLI could not revoke the disposable caller"
revoke_caller

step="Active wiki stream did not close within the revocation observation window"
for attempt in $(seq 1 30); do
    if dc exec -T reader test -f /tmp/stream-ended; then break; fi
    kill -0 "$watch_pid" || exit 1
    sleep 1
done
dc exec -T reader test -f /tmp/stream-ended
wait "$watch_pid"
watch_pid=
step="New reads after revocation did not consistently fail with zero wiki bytes"
await_zero() {
    for attempt in $(seq 1 20); do
        if dc exec -T reader python cloud_check.py; then return 0; fi
        sleep 1
    done
    return 1
}
await_zero
dc exec -T reader python cloud_check.py
step="The local wiki did not match the baseline after revocation"
dc exec -T wiki sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python connector.py http://127.0.0.1:8080' > "$CLOUD_TMP/local"
cmp expected/documents.json "$CLOUD_TMP/local"

step="Could not tear down study containers"
teardown
step="Git HEAD or the checkout changed during the study"
[ "$(git rev-parse HEAD)" = "$head" ] && clean_tree || exit 1
step="Could not validate or publish the proof"
proof=$(python3 cloud/proof.py prepare "$CLOUD_TMP" "$head")
step="Could not delete temporary enrollment files"
rm -rf -- "$CLOUD_TMP"
step="Could not publish the proof"
printf '%s\n' "$proof" | python3 cloud/proof.py publish >&3
