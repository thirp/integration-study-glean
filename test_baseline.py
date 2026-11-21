import subprocess
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

from wiki import WikiHandler


class BaselineTest(unittest.TestCase):
    @patch.dict("os.environ", {"WIKI_TOKEN": "unit-test-wiki-token"})
    def test_http_to_golden_documents_twice(self):
        expected = Path("expected/documents.json").read_bytes()
        with ThreadingHTTPServer(("127.0.0.1", 0), WikiHandler) as server:
            worker = threading.Thread(target=server.serve_forever)
            worker.start()
            try:
                for _ in range(2):
                    actual = subprocess.check_output([
                        sys.executable, "connector.py", f"http://127.0.0.1:{server.server_port}"
                    ])
                    self.assertEqual(actual, expected)
            finally:
                server.shutdown()
                worker.join()
