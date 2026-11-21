"""Hosted-only fixture for observing one response across caller revocation."""
import os
import time
from http.server import ThreadingHTTPServer

from wiki import WikiHandler


class StreamingWiki(WikiHandler):
    def do_GET(self):
        if self.path != "/study-stream":
            return super().do_GET()
        if self.headers.get("Authorization") != "Bearer " + os.environ["WIKI_TOKEN"]:
            self.send_error(401)
            return
        self.send_response(200)
        self.end_headers()
        try:
            while True:
                self.wfile.write(b"x")
                self.wfile.flush()
                time.sleep(0.25)
        except (BrokenPipeError, ConnectionResetError):
            return


ThreadingHTTPServer(("0.0.0.0", 8080), StreamingWiki).serve_forever()
