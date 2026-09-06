import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("detect_wallpaper", ROOT / "scripts/detect_wallpaper.py")
detector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(detector)

class WallpaperDetectionTests(unittest.TestCase):
    def test_multiple_outputs_and_spaces(self):
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "green forest.jpg", Path(directory) / "ocean.jpg"
            a.touch(); b.touch()
            query = f"DP-1: 1920x1080, currently displaying: image: {a}\nHDMI-A-1: image: {b}\n"
            self.assertEqual(detector.query_images(query), [str(a), str(b)])

    def test_xdg_waypaper_and_percent_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "100% green.jpg"
            image.touch()
            config = Path(directory) / "waypaper"
            config.mkdir()
            (config / "config.ini").write_text(f"[Settings]\nwallpaper = {image}\n")
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                self.assertEqual(detector.waypaper_image(), str(image))

    def test_awww_live_image_precedes_stale_waypaper(self):
        with tempfile.TemporaryDirectory() as directory:
            live = Path(directory) / "live.jpg"; live.touch()
            result = type("Result", (), {"returncode": 0, "stdout": f"DP-1: image: {live}"})()
            with patch.object(detector, "waypaper_image", return_value="/stale.jpg"), \
                 patch.object(detector.shutil, "which", return_value="/usr/bin/awww"), \
                 patch.object(detector.subprocess, "run", return_value=result) as run:
                self.assertEqual(detector.detect(), ("awww", str(live)))
                self.assertEqual(run.call_args.args[0], ["awww", "query"])
