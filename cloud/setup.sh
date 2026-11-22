#!/bin/sh
set +x
set -eu
umask 077

fail() { printf '%s\n' "$1" >&2; exit 1; }

[ "$#" -eq 2 ] || fail "Usage: cloud/setup.sh ENROLLMENT_TOKEN_FILE AGENT_DIRECTORY"
: "${STUDY_SERVICE_ID:?Set the Platforms Service ID shown as service_id}"
command -v thirp >/dev/null 2>&1 || fail "Install the thirp owner CLI on PATH"
command -v python3 >/dev/null 2>&1 || fail "Install Python 3"
script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
token_file=$(realpath -- "$1")
[ -f "$token_file" ] && [ -r "$token_file" ] &&
    [ "$(stat -c '%a' -- "$token_file")" = 600 ] ||
    fail "Use a readable agent enrollment token file with mode 0600"

services=$(thirp services list </dev/null 2>/dev/null) ||
    fail "Could not list Services. Check the owner login, account and network."
printf '%s\n' "$services" | python3 "$script_dir/owner.py" service "$STUDY_SERVICE_ID" >/dev/null ||
    fail "Expected the enabled account Service in thirp services list"

agent_dir=$(realpath -m -- "$2")
mkdir -m 700 -- "$agent_dir" || fail "Choose a new agent enrollment directory"
complete=no
cleanup() {
    if [ "$complete" = no ]; then rm -rf -- "$agent_dir"; fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# The owner CLI takes the one-use token as a positional argument.
token=$(cat -- "$token_file")
case "$token" in
    ''|-*|*[!a-zA-Z0-9_]*) fail "Invalid agent enrollment token file" ;;
esac
thirp agent enroll "$token" --dir "$agent_dir" </dev/null >/dev/null 2>&1 ||
    fail "Agent enrollment failed. Check the one-use token and network."
unset token

# CLI 0.1.5 accepts only numeric endpoints in --map. Runtime resolves wiki.
[ -s "$agent_dir/agent.conf" ] && [ -s "$agent_dir/agent.token" ] ||
    fail "Agent enrollment did not write the expected files"
printf 'map = %s=wiki:8080\n' "$STUDY_SERVICE_ID" >> "$agent_dir/agent.conf"
complete=yes
printf '%s\n' "Agent enrollment ready. Set STUDY_AGENT_CONF to agent.conf in the enrollment directory."
