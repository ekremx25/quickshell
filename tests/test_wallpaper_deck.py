import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "wallpaper_deck.py"
SPEC = importlib.util.spec_from_file_location("wallpaper_deck", MODULE_PATH)
wallpaper_deck = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(wallpaper_deck)


class FakeResponse(io.BytesIO):
    def __init__(self, payload, content_type="application/json", content_length=None):
        body = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        super().__init__(body)
        self.headers = FakeHeaders(content_type, len(body) if content_length is None else content_length)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class FakeHeaders:
    def __init__(self, content_type, content_length):
        self.content_type = content_type
        self.values = {"Content-Length": str(content_length)}

    def get_content_type(self):
        return self.content_type

    def get(self, key, default=None):
        return self.values.get(key, default)


class WallpaperDeckTests(unittest.TestCase):
    def capture(self, callback, *args):
        output = io.StringIO()
        with redirect_stdout(output):
            callback(*args)
        return json.loads(output.getvalue())

    def test_local_lists_only_supported_images(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lake.jpg").write_bytes(b"jpg")
            (root / ".partial.jpg").write_bytes(b"partial")
            (root / "notes.txt").write_text("ignore")
            result = self.capture(wallpaper_deck.local_wallpapers, directory)
        self.assertTrue(result["ok"])
        self.assertEqual([item["name"] for item in result["items"]], ["lake"])
        self.assertEqual(result["items"][0]["source"], "local")

    def test_search_normalizes_wallhaven_contract(self):
        payload = {
            "data": [{
                "id": "abc123",
                "path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
                "thumbs": {"large": "https://th.wallhaven.cc/lg/ab/abc123.jpg"},
                "colors": ["#000000"],
                "resolution": "1920x1080",
                "file_size": 42,
                "category": "general",
            }],
            "meta": {"current_page": 1, "last_page": 2, "total": 25},
        }
        with patch.object(wallpaper_deck.urllib.request, "urlopen", return_value=FakeResponse(payload)):
            result = self.capture(wallpaper_deck.wallhaven_search, "nature", 1, "relevance", "1920x1080")
        self.assertEqual(result["items"][0]["id"], "abc123")
        self.assertEqual(result["meta"], {"currentPage": 1, "lastPage": 2, "total": 25})

    def test_download_rejects_non_wallhaven_hosts(self):
        output = io.StringIO()
        with redirect_stdout(output), self.assertRaises(SystemExit):
            wallpaper_deck.validated_wallhaven_url("https://example.com/image.jpg")
        self.assertIn("trusted Wallhaven host", json.loads(output.getvalue())["error"])

    def test_download_is_atomic_and_reuses_cached_file(self):
        body = b"fake-image"
        with tempfile.TemporaryDirectory() as directory:
            response = FakeResponse(body, "image/jpeg")
            with patch.object(wallpaper_deck.urllib.request, "urlopen", return_value=response):
                first = self.capture(
                    wallpaper_deck.download_wallpaper,
                    "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
                    "abc123",
                    directory,
                )
            target = Path(first["path"])
            self.assertEqual(target.read_bytes(), body)
            self.assertFalse(first["cached"])
            second = self.capture(
                wallpaper_deck.download_wallpaper,
                "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
                "abc123",
                directory,
            )
            self.assertTrue(second["cached"])
            self.assertEqual(list(Path(directory).glob(".wallhaven-*")), [])

    def test_download_accepts_missing_or_malformed_content_length(self):
        response = FakeResponse(b"image", "image/jpeg", "unknown")
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(wallpaper_deck.urllib.request, "urlopen", return_value=response):
                result = self.capture(
                    wallpaper_deck.download_wallpaper,
                    "https://w.wallhaven.cc/full/ab/wallhaven-no-length.jpg",
                    "no-length",
                    directory,
                )
            self.assertEqual(Path(result["path"]).read_bytes(), b"image")

    def test_download_rejects_content_length_over_limit(self):
        response = FakeResponse(b"x", "image/jpeg", wallpaper_deck.MAX_DOWNLOAD_BYTES + 1)
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(wallpaper_deck.urllib.request, "urlopen", return_value=response):
                with redirect_stdout(output), self.assertRaises(SystemExit):
                    wallpaper_deck.download_wallpaper(
                        "https://w.wallhaven.cc/full/ab/wallhaven-too-big.jpg",
                        "too-big",
                        directory,
                    )
        self.assertIn("50 MB", json.loads(output.getvalue())["error"])

    def test_apply_prefers_awww_without_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "wall.jpg"
            image.write_bytes(b"jpg")
            completed = type("Completed", (), {"returncode": 0, "stdout": "", "stderr": ""})()
            with patch.object(wallpaper_deck.shutil, "which", side_effect=lambda name: "/usr/bin/awww" if name == "awww" else None):
                with patch.object(wallpaper_deck.subprocess, "run", return_value=completed) as run:
                    result = self.capture(wallpaper_deck.apply_wallpaper, str(image))
            self.assertEqual(result["backend"], "awww")
            command = run.call_args.args[0]
            self.assertEqual(command[0:2], ["awww", "img"])
            self.assertEqual(command[-1], str(image))
            self.assertNotIsInstance(command, str)


if __name__ == "__main__":
    unittest.main()
