"""Private wiki connector adapted from Glean's MIT-licensed wiki example."""
import json
import os
import sys
from urllib.request import ProxyHandler, Request, build_opener

from glean.indexing.connectors import BaseDataClient, BaseDatasourceConnector
from glean.indexing.models import ContentDefinition, CustomDatasourceConfig, DocumentDefinition


class WikiDataClient(BaseDataClient[dict]):
    def __init__(self, base_url):
        self.base_url = base_url.rstrip("/")

    def get_source_data(self, **kwargs):
        # Every source read must use the connector's own network route.
        request = Request(self.base_url + "/pages")
        token = os.environ.get("WIKI_TOKEN")
        if token:
            request.add_header("Authorization", f"Bearer {token}")
        with build_opener(ProxyHandler({})).open(request, timeout=4) as response:
            return json.load(response)


class WikiConnector(BaseDatasourceConnector[dict]):
    configuration = CustomDatasourceConfig(name="studywiki", display_name="Study Wiki")

    def transform(self, data):
        return [
            DocumentDefinition(
                datasource=self.name,
                id=page["slug"],
                title=page["heading"],
                view_url=f"https://wiki.example.invalid/pages/{page['slug']}",
                body=ContentDefinition(mime_type="text/plain", text_content=page["content"]),
            )
            for page in sorted(data, key=lambda p: p["slug"])
        ]


def render_documents(documents):
    records = [doc.model_dump(by_alias=True, exclude_none=True, mode="json") for doc in documents]
    return json.dumps(records, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    connector = WikiConnector(name="studywiki", data_client=WikiDataClient(sys.argv[1]))
    documents = connector.transform(connector.get_data())
    sys.stdout.buffer.write(render_documents(documents).encode("utf-8"))
