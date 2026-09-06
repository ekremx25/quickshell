"""Live must keep following desktop changes even after a manual image choice."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class LiveWallpaperTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_live_startup_and_next_desktop_change(self):
        with tempfile.TemporaryDirectory(prefix="qs-live-") as directory:
            temp = Path(directory)
            cfg = temp / "config/quickshell"
            (cfg / "scripts").mkdir(parents=True)
            (cfg / "Services").symlink_to(ROOT / "Services", target_is_directory=True)
            palette = json.loads((ROOT / "tests/fixtures/material_you_palette.json").read_text())
            first, latest, state = temp / "first.json", temp / "latest.json", temp / "desktop-path"
            first.write_text(json.dumps(palette))
            palette["quickshell_spectrum"] = ["#2e6a32", "#71a8ca"]
            latest.write_text(json.dumps(palette))
            state.write_text(str(first))
            (cfg / "theme_config.json").write_text(json.dumps({
                "materialYou": True, "liveUpdate": True, "wallpaperSource": "selected",
                "wallpaperPath": str(latest), "matugenType": "scheme-wallpaper-spectrum", "_schemaVersion": 1
            }))
            (cfg / "scripts/matugen-worker.sh").write_text('cat -- "$1"\n')
            (cfg / "scripts/get-active-wallpaper.sh").write_text("printf 'waypaper\\t'; cat '" + str(state) + "'; printf '\\n'\n")
            qml = '''import QtQuick
import Quickshell
import Quickshell.Io
import "SERVICES"
ShellRoot {
 id: test
 property int phase: 0
 Process {
  id: changeDesktop
  command: ["bash", "-c", "printf '%s' \\\"$1\\\" > \\\"$2\\\"", "--", LATEST, STATE]
 }
 Timer { interval: 30; running: true; repeat: true; onTriggered: {
  if (ColorPaletteService.isBusy) return;
  if (test.phase === 0 && ColorPaletteService.appliedWallpaperPath.length > 0) {
   if (ColorPaletteService.appliedWallpaperPath !== FIRST) {
    console.error("LIVE_FAIL startup kept stale selected image"); Qt.quit(); return;
   }
   test.phase = 1;
   ColorPaletteService.selectWallpaper(FIRST);
   changeDesktop.running = true;
  } else if (test.phase === 1 && ColorPaletteService.appliedWallpaperPath === LATEST) {
   console.log("LIVE_PASS"); Qt.quit();
  }
 }}
 Timer { interval: 7000; running: true; onTriggered: { console.error("LIVE_FAIL no automatic change"); Qt.quit(); } }
}
'''
            for key, value in {"SERVICES": (ROOT / "Services").as_uri(), "FIRST": json.dumps(str(first)),
                               "LATEST": json.dumps(str(latest)), "STATE": json.dumps(str(state))}.items():
                qml = qml.replace(key, value)
            (temp / "shell.qml").write_text(qml)
            (temp / "runtime").mkdir(mode=0o700)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_CACHE_HOME=str(temp / "cache"),
                       XDG_STATE_HOME=str(temp / "state"), XDG_RUNTIME_DIR=str(temp / "runtime"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(temp / "shell.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("LIVE_PASS", output)
            self.assertNotIn("LIVE_FAIL", output)
