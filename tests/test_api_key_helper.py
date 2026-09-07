import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / "scripts/api_key_helper.py"
spec = importlib.util.spec_from_file_location("api_helper", HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ApiKeyTests(unittest.TestCase):
    def test_secret_saved_from_stdin_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = "TEST_ONLY_NOT_A_REAL_KEY"
            data = {"api_key": secret, "provider": "test"}
            result = subprocess.run(["python3", str(HELPER), "save"], input=json.dumps(data) + "\n",
                text=True, capture_output=True, env=dict(os.environ, XDG_CONFIG_HOME=directory))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertNotIn(secret, result.stdout + result.stderr + " ".join(result.args))
            target = Path(directory) / "linuxcomplete/api_keys.json"
            self.assertEqual(json.loads(target.read_text()), data)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_remote_plain_http_is_rejected_without_request(self):
        with patch.object(helper.urllib.request, "build_opener") as opener:
            with self.assertRaises(ValueError):
                helper.test_connection({"endpoint": "http://example.com/v1/chat/completions"})
            opener.assert_not_called()

    def test_redirect_does_not_forward_authorization(self):
        self.assertIsNone(helper.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.example"))
