"""Read the JSON printed by the owner CLI and return only a catalog or enrollment ID."""

import json
import re
import sys


def main(kind, name):
    items = json.load(sys.stdin)["items"]
    if not isinstance(items, list):
        raise ValueError
    field = "service_id" if kind == "service" else "name"
    matches = [item for item in items if item[field] == name]
    if kind == "caller" and not matches:
        return  # An unsuccessful enroll may not have created a caller.
    if len(matches) != 1:
        raise ValueError
    entry = matches[0]
    if kind == "service" and (entry["environment_id"] is not None or entry["state"] != "enabled"):
        raise ValueError
    identity = entry["id"]
    if not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", identity):
        raise ValueError
    print(identity)


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except (KeyError, TypeError, ValueError):
        sys.exit("Expected one matching Service or caller in the owner CLI response")
