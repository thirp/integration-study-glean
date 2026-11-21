#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${STUDY_AGENT_CONF:?Set the enrolled agent.conf path}" "${STUDY_CALLER_CONF:?Set the disposable caller.conf path}"
test -r "$STUDY_AGENT_CONF" && test -r "$STUDY_CALLER_CONF" || exit 1
for bundle in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt; do
    if [ -r "$bundle" ]; then CLOUD_SYSTEM_CA=$(realpath "$bundle"); export CLOUD_SYSTEM_CA; break; fi
done
: "${CLOUD_SYSTEM_CA:?Missing system CA bundle}"
docker info >/dev/null
umask 077
CLOUD_TMP=$(mktemp -d)
export CLOUD_TMP
dc() { docker compose -p "glean-cloud-$$" -f compose.cloud.yaml "$@"; }
cleanup() { status=$?; trap - EXIT; dc down --remove-orphans >/dev/null 2>&1 || status=1; rm -rf "$CLOUD_TMP"; exit "$status"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
python3 cloud/stage.py
dc build wiki reader agent
dc up -d wiki reader agent
# Keep the reader namespace up across caller restarts.
cp "$CLOUD_TMP/caller/caller.token" "$CLOUD_TMP/valid.token"
openssl rand -hex 32 > "$CLOUD_TMP/caller/caller.token"
dc up -d caller
echo "Checking invalid caller credential"
sleep 5
dc exec -T reader python cloud_check.py
dc stop caller
mv "$CLOUD_TMP/valid.token" "$CLOUD_TMP/caller/caller.token"
dc start caller
read_docs() {
    dc exec -T reader sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python connector.py http://127.0.0.1:18080' > "$CLOUD_TMP/documents"
}
await_docs() {
    i=0
    until read_docs 2>/dev/null; do
        i=$((i+1)); [ "$i" -lt 20 ] || { echo "Hosted read unavailable" >&2; return 1; }; sleep 1
    done
    cmp expected/documents.json "$CLOUD_TMP/documents"
}
await_docs
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(dc ps -q wiki)")
test -n "$ip"
dc exec -T reader python probe.py "$ip"
read_docs
cmp expected/documents.json "$CLOUD_TMP/documents"
dc exec -T reader sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python evidence.py http://127.0.0.1:18080'
echo "Checking stopped Agent"
dc stop agent
dc exec -T reader python cloud_check.py
dc start agent
await_docs
dc exec -T reader python watch.py &
watch_pid=$!
i=0
until dc exec -T reader test -f /tmp/stream-ready; do
    i=$((i+1)); [ "$i" -lt 15 ] || exit 1; sleep 1
done
echo "Active wiki response confirmed at $(date -u +%FT%TZ)"
echo "Revoke this disposable study caller now using thirp caller revoke ID in the owner terminal. Press Enter after success."
read -r reply
echo "Owner confirmed revocation at $(date -u +%FT%TZ)"
i=0
until dc exec -T reader test -f /tmp/stream-ended; do
    i=$((i+1)); [ "$i" -lt 30 ] || { echo "Active stream did not close within observation window" >&2; exit 1; }; sleep 1
done
wait "$watch_pid"
i=0
until dc exec -T reader python cloud_check.py; do
    i=$((i+1)); [ "$i" -lt 20 ] || exit 1; sleep 1
done
dc exec -T reader python cloud_check.py
dc exec -T wiki sh -ec 'export WIKI_TOKEN="$(cat /run/wiki.token)"; exec python connector.py http://127.0.0.1:8080' > "$CLOUD_TMP/local"
cmp expected/documents.json "$CLOUD_TMP/local"
sha256sum expected/documents.json "$CLOUD_TMP/documents"
echo "PASS: hosted wiki documents, isolation, application authentication, credential controls and agent recovery"
