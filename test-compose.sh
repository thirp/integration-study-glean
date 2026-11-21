#!/bin/sh
set -eu
cd "$(dirname "$0")"
project="glean-study-$$"
tmp=$(mktemp -d)
dc() { docker compose -p "$project" -f compose.yaml "$@"; }
direct() { dc -f compose.direct.yaml "$@"; }
cleanup() { dc down --remove-orphans; rm -rf "$tmp"; }
trap cleanup EXIT
export WIKI_TOKEN=$(openssl rand -hex 32)
dc build
dc up -d --wait wiki
for run in 1 2; do
    direct run --rm -T --no-deps connector > "$tmp/docs"
    cmp expected/documents.json "$tmp/docs"
done
direct run --rm -T --no-deps connector python evidence.py http://wiki:8080
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(dc ps -q wiki)")
test -n "$ip"
dc run --rm -T --no-deps connector python probe.py "$ip"
direct run --rm -T --no-deps connector > "$tmp/after"
cmp expected/documents.json "$tmp/after"
echo "PASS: direct documents match before and after isolation; isolated source reads blocked."
