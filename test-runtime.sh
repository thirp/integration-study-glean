#!/bin/sh
set -eu
cd "$(dirname "$0")"
export STUDY_KEYS
STUDY_KEYS=$(mktemp -d)
project="glean-runtime-$$"
dc() { docker compose -p "$project" -f compose.yaml -f compose.runtime.yaml "$@"; }
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then dc logs broker agent caller >&2 || true; fi
    dc down --remove-orphans
    rm -rf "$STUDY_KEYS"
}
trap cleanup EXIT
umask 077
export WIKI_TOKEN=$(openssl rand -hex 32)
mkdir "$STUDY_KEYS/broker" "$STUDY_KEYS/agent" "$STUDY_KEYS/caller"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=broker \
    -addext subjectAltName=DNS:broker -keyout "$STUDY_KEYS/broker/broker.key" \
    -out "$STUDY_KEYS/broker/broker.crt" 2>/dev/null
for role in agent caller; do
    openssl rand -hex 32 > "$STUDY_KEYS/$role/token"
    cp "$STUDY_KEYS/broker/broker.crt" "$STUDY_KEYS/$role/"
done
{
    printf '%s=wiki-agent:study;capabilities=register\n' "$(cat "$STUDY_KEYS/agent/token")"
    printf '%s=glean-reader:study;capabilities=connect\n' "$(cat "$STUDY_KEYS/caller/token")"
} > "$STUDY_KEYS/broker/broker.tokens"
dc build broker wiki reader
dc up -d --wait wiki
dc up -d broker
dc up -d agent caller
attempt=0
until dc run --rm -T --no-deps reader > "$STUDY_KEYS/docs"; do
    attempt=$((attempt+1))
    [ "$attempt" -lt 15 ] || exit 1
    sleep 1
done
cmp expected/documents.json "$STUDY_KEYS/docs"
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(dc ps -q wiki)")
test -n "$ip"
dc run --rm -T --no-deps reader python probe.py "$ip"
dc run --rm -T --no-deps reader > "$STUDY_KEYS/docs"
cmp expected/documents.json "$STUDY_KEYS/docs"
dc run --rm -T --no-deps reader python evidence.py http://127.0.0.1:18080
sha256sum "$STUDY_KEYS/docs" expected/documents.json
echo 'PASS: Runtime returned the baseline documents with direct wiki access blocked.'
