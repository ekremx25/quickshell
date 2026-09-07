"""Routing tests use fake commands and temporary configs, never real displays."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
KEYS = ("XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "NIRI_SOCKET",
        "MANGO_INSTANCE_SIGNATURE", "HYPRLAND_INSTANCE_SIGNATURE")


class CompositorRoutingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="qs-routing-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        self.log = self.path / "commands"
        self.env = dict(os.environ)
        for key in KEYS:
            self.env.pop(key, None)
        self.env.update(PATH=str(self.bin) + ":" + os.environ["PATH"],
                        XDG_CONFIG_HOME=str(self.path / "config"),
                        ROUTING_LOG=str(self.log))
        self.command("mmsg", 'exit 1')
        self.command("hyprctl", 'echo hyprctl >> "$ROUTING_LOG"; exit 0')
        self.command("hyprmoncfg", 'echo hyprmoncfg >> "$ROUTING_LOG"; exit 0')
        self.command("systemctl", 'echo systemctl >> "$ROUTING_LOG"; exit 0')

    def command(self, name, body):
        target = self.bin / name
        target.write_text("#!/bin/bash\n" + body + "\n")
        target.chmod(0o755)

    def run_script(self, name, *args, env=None):
        return subprocess.run(["bash", str(ROOT / "scripts" / name), *args],
                              env=env or self.env, capture_output=True, text=True, timeout=10)

    def test_environment_routing_and_qml_agree(self):
        cases = [
            ({"XDG_CURRENT_DESKTOP": "niri", "HYPRLAND_INSTANCE_SIGNATURE": "old"}, "niri"),
            ({"XDG_CURRENT_DESKTOP": "Mango", "NIRI_SOCKET": "old"}, "mango"),
            ({"XDG_CURRENT_DESKTOP": "Hyprland", "NIRI_SOCKET": "old"}, "hyprland"),
            ({"XDG_CURRENT_DESKTOP": "Hyprland", "XDG_SESSION_DESKTOP": "niri"}, "hyprland"),
            ({"XDG_CURRENT_DESKTOP": "KDE", "HYPRLAND_INSTANCE_SIGNATURE": "old"}, "unknown"),
            ({"XDG_SESSION_DESKTOP": "niri"}, "niri"),
            ({"NIRI_SOCKET": "socket"}, "niri"),
            ({"MANGO_INSTANCE_SIGNATURE": "socket"}, "mango"),
            ({"HYPRLAND_INSTANCE_SIGNATURE": "socket"}, "hyprland"),
            ({"NIRI_SOCKET": "old", "HYPRLAND_INSTANCE_SIGNATURE": "old"}, "unknown"),
            ({}, "unknown"),
        ]
        for values, expected in cases:
            with self.subTest(values=values):
                env = dict(self.env, **values)
                result = self.run_script("detect_compositor.sh", env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)
                if shutil.which("node"):
                    source = (ROOT / "Services/core/CompositorDetection.js").read_text()
                    args = [values.get(key, "") for key in KEYS]
                    js = source + "\nconsole.log(fromEnvironment(..." + json.dumps(args) + "));"
                    actual = subprocess.check_output(["node", "-e", js], text=True).strip()
                    self.assertEqual(actual, expected)

    def test_mango_live_fallback_not_installed_binary(self):
        self.assertEqual(self.run_script("detect_compositor.sh").stdout.strip(), "unknown")
        self.command("mmsg", "printf '%s\\n' '{\"version\":\"0.16\"}'")
        self.assertEqual(self.run_script("detect_compositor.sh").stdout.strip(), "mango")
        self.command("mmsg", "printf '%s\\n' '{\"version\":\"0.16\"}'; exit 1")
        self.assertEqual(self.run_script("detect_compositor.sh").stdout.strip(), "unknown")

    def test_foreign_sessions_never_touch_hyprland_daemon(self):
        config = Path(self.env["XDG_CONFIG_HOME"]) / "quickshell"
        config.mkdir(parents=True)
        (config / "monitor_config.json").write_text("{}")
        for desktop in ("niri", "mango", "KDE"):
            with self.subTest(desktop=desktop):
                env = dict(self.env, XDG_CURRENT_DESKTOP=desktop, HYPRLAND_INSTANCE_SIGNATURE="stale")
                result = self.run_script("apply_monitors.sh", env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                for action in ("save", "apply", "enable", "disable", "delete"):
                    result = self.run_script("hyprmoncfg_action.sh", action, "test", env=env)
                    self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.log.exists(), self.log.read_text() if self.log.exists() else "")

    def test_hyprland_defers_to_active_profile_daemon(self):
        result = self.run_script("apply_monitors.sh", env=dict(self.env, XDG_CURRENT_DESKTOP="Hyprland"))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text().splitlines(), ["systemctl"])

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_profile_backend_is_inactive_in_niri(self):
        config = Path(self.env["XDG_CONFIG_HOME"]) / "quickshell"
        config.mkdir(parents=True)
        (config / "scripts").symlink_to(ROOT / "scripts", target_is_directory=True)
        self.command("niri", "printf '%s\\n' '{\"DP-1\":{\"make\":\"Test\",\"model\":\"Screen\",\"current_mode\":0,\"modes\":[{\"width\":2560,\"height\":1440,\"refresh_rate\":144000}],\"logical\":{\"x\":0,\"y\":0,\"scale\":1.25}}}'")
        runtime = self.path / "runtime"
        runtime.mkdir(mode=0o700)
        source = '''import QtQuick
import Quickshell
import "HYPRBACKEND"
import "MONITORS" as Monitors
import "SERVICES"
ShellRoot {
    HyprmoncfgBackend { id: backend }
    Monitors.MonitorsBackend { }
    Timer {
        interval: 500; running: true
        onTriggered: {
            if (CompositorService.compositor !== "niri" || backend.supported || backend.busy)
                throw new Error("Incorrect compositor routing");
            backend.refresh(); backend.syncCurrentProfile(); backend.openEditor();
            backend.applyProfile("test"); backend.saveProfile("test");
            backend.enableManagement(); backend.disableManagement();
            var output = CompositorService.monitors[0];
            if (!output || output.width !== 2560 || output.height !== 1440 || output.scale !== 1.25 || Number(output.refreshRate) !== 144)
                throw new Error("Niri output schema regression");
            console.log("ROUTING_OK");
            Qt.quit();
        }
    }
}'''
        source = source.replace("HYPRBACKEND", (ROOT / "Modules/bar/Hyprmoncfg").as_uri())
        source = source.replace("MONITORS", (ROOT / "Modules/bar/System").as_uri())
        source = source.replace("SERVICES", (ROOT / "Services").as_uri())
        entry = self.path / "shell.qml"
        entry.write_text(source)
        env = dict(self.env, XDG_CURRENT_DESKTOP="niri", NIRI_SOCKET="test",
                   XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["quickshell", "-p", str(entry)], env=env,
                                capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        self.assertIn("ROUTING_OK", output)
        self.assertNotIn("failed to load", output.lower())
        self.assertFalse(self.log.exists(), self.log.read_text() if self.log.exists() else "")
