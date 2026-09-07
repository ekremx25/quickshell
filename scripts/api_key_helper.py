"""Receive secrets over stdin only; never include them in process arguments."""
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.request
import urllib.parse


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def save(config):
    directory = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "linuxcomplete"
    directory.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".api-", dir=directory)
    try:
        with os.fdopen(fd, "w") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump(config, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, directory / "api_keys.json")
    finally:
        if os.path.exists(name):
            os.unlink(name)


def test_connection(data):
    endpoint = data["endpoint"]
    url = urllib.parse.urlsplit(endpoint)
    if url.username or url.password or not (url.scheme == "https" or
            (url.scheme == "http" and url.hostname in ("localhost", "127.0.0.1", "::1"))):
        raise ValueError("HTTPS required for remote providers")
    request = urllib.request.Request(endpoint, data=json.dumps(data["payload"]).encode(),
        headers={"Authorization": "Bearer " + data["key"], "Content-Type": "application/json"})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=10) as response:
        return json.loads(response.read(1024 * 1024))


def main():
    try:
        data = json.loads(sys.stdin.readline())
        if sys.argv[1] == "save":
            save(data)
        elif sys.argv[1] == "test":
            print(json.dumps(test_connection(data)))
        else:
            raise ValueError("Unknown action")
        return 0
    except Exception:
        # Provider responses and exception strings can contain credentials.
        print(json.dumps({"error": {"message": "Operation failed. Check connection, credentials and file permissions."}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
