"""Run inside the isolated connector container."""
import errno
import socket
import sys
from urllib.error import HTTPError, URLError

from connector import WikiDataClient

for host in ("wiki", sys.argv[1]):
    try:
        WikiDataClient(f"http://{host}:8080").get_source_data()
    except HTTPError:
        raise  # Any HTTP response proves reachability.
    except URLError as exc:
        reason = exc.reason
        if host == "wiki" and isinstance(reason, socket.gaierror):
            print(f"{host}: DNS lookup blocked ({reason})")
        elif isinstance(reason, (OSError, TimeoutError)) and (
            isinstance(reason, TimeoutError) or reason.errno in {errno.EHOSTUNREACH, errno.ENETUNREACH}
        ):
            print(f"{host}: route blocked ({reason})")
        else:
            raise
    else:
        raise SystemExit(f"Isolation failure: reached {host}")
