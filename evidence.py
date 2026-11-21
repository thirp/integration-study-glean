"""Verify the application-level evidence from the connector's own namespace."""
import hashlib
import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError

from connector import WikiConnector, WikiDataClient, render_documents


def verify(base_url):
    client = WikiDataClient(base_url)
    connector = WikiConnector(name="studywiki", data_client=client)
    records = connector.get_data()
    if records != json.loads(Path("fixtures/pages.json").read_bytes()):
        raise ValueError("Fetched wiki records differ from the ordered source fixture")
    documents = connector.transform(records)
    payload = render_documents(documents).encode("utf-8")
    if payload != Path("expected/documents.json").read_bytes():
        raise ValueError("SDK documents differ from the baseline")

    for label, token in (("missing", ""), ("invalid", os.environ["WIKI_TOKEN"] + "-invalid")):
        os.environ["WIKI_TOKEN"] = token
        try:
            client.get_source_data()
        except HTTPError as error:
            if error.code != 401 or error.headers.get("WWW-Authenticate") != 'Bearer realm="study-wiki"':
                raise
        else:
            raise ValueError(f"Wiki accepted {label} credential")

    print(json.dumps({
        "records": records,
        "document_ids": [doc.id for doc in documents],
        "documents_sha256": hashlib.sha256(payload).hexdigest(),
        "wiki_auth": {"valid": "accepted", "missing": 401, "invalid": 401},
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    verify(sys.argv[1])
