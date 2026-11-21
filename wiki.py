import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PAGES = Path(__file__).parent / "fixtures/pages.json"


class WikiHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/pages":
            self.send_error(404)
            return
        if self.headers.get("Authorization") != "Bearer " + os.environ["WIKI_TOKEN"]:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Bearer realm="study-wiki"')
            self.end_headers()
            return
        payload = PAGES.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), WikiHandler).serve_forever()
