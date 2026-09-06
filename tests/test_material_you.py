"""Regression: wallpaper palettes must reach legacy modules and settings live."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class MaterialYouTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required for QML binding tests")
    def test_wallpaper_mode_and_settings_bindings(self):
        palette = json.loads((ROOT / "tests/fixtures/material_you_palette.json").read_text())
        with tempfile.TemporaryDirectory(prefix="qs-theme-test-") as directory:
            temp = Path(directory)
            config = temp / "config/quickshell"
            config.mkdir(parents=True)
            (config / "Services").symlink_to(ROOT / "Services", target_is_directory=True)
            (config / "theme_config.json").write_text(json.dumps({"materialYou": False, "_schemaVersion": 1}))
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = (ROOT / "tests/material_you_smoke.qml.in").read_text()
            source = source.replace("WIDGETS", (ROOT / "Widgets").as_uri())
            source = source.replace("SERVICES", (ROOT / "Services").as_uri())
            source = source.replace("PALETTE", json.dumps(palette))
            (temp / "shell.qml").write_text(source)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_CACHE_HOME=str(temp / "cache"),
                       XDG_STATE_HOME=str(temp / "state"), XDG_RUNTIME_DIR=str(runtime))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(temp / "shell.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("MATERIAL_YOU_SMOKE_PASS", output)
            self.assertNotIn("MATERIAL_YOU_SMOKE_FAIL", output)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required for QML queue tests")
    def test_latest_wallpaper_wins_and_manual_source_is_preserved(self):
        palette = json.loads((ROOT / "tests/fixtures/material_you_palette.json").read_text())
        with tempfile.TemporaryDirectory(prefix="qs-wallpaper-queue-") as directory:
            temp = Path(directory)
            config = temp / "config/quickshell"
            (config / "scripts").mkdir(parents=True)
            (config / "Services").symlink_to(ROOT / "Services", target_is_directory=True)
            (config / "theme_config.json").write_text(json.dumps({"materialYou": False, "_schemaVersion": 1}))
            first, latest = temp / "first.json", temp / "latest.json"
            first.write_text(json.dumps(palette))
            palette["quickshell_spectrum"] = ["#2e6a32", "#71a8ca", "#f6b14e"]
            latest.write_text(json.dumps(palette))
            (config / "scripts/matugen-worker.sh").write_text('sleep 0.15\ncat -- "$1"\n')
            (config / "scripts/get-active-wallpaper.sh").write_text(
                "sleep 0.15\nprintf 'waypaper\\t%s\\n' '" + str(first) + "'\n")
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = (ROOT / "tests/wallpaper_queue_smoke.qml.in").read_text()
            for key, value in {"WIDGETS": (ROOT / "Widgets").as_uri(), "SERVICES": (ROOT / "Services").as_uri(),
                               "FIRST": json.dumps(str(first)), "LATEST": json.dumps(str(latest))}.items():
                source = source.replace(key, value)
            (temp / "shell.qml").write_text(source)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_CACHE_HOME=str(temp / "cache"),
                       XDG_STATE_HOME=str(temp / "state"), XDG_RUNTIME_DIR=str(runtime))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(temp / "shell.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("WALLPAPER_QUEUE_PASS", output)
            self.assertNotIn("WALLPAPER_QUEUE_FAIL", output)

if __name__ == "__main__":
    unittest.main()
