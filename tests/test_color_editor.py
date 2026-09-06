"""Exercise the editor commands against the real palette service in isolation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ColorEditorTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_presets_save_undo_and_reset(self):
        with tempfile.TemporaryDirectory(prefix="qs-editor-") as directory:
            temp = Path(directory)
            config = temp / "config/quickshell"
            config.mkdir(parents=True)
            (config / "Services").symlink_to(ROOT / "Services")
            (config / "theme_config.json").write_text(json.dumps({"materialYou": False, "_schemaVersion": 1}))
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = '''import QtQuick
import Quickshell
import "SETTINGS"
import "SERVICES"
import "BARDEFAULTS" as BarDefaults
ShellRoot {
    Window {
        visible: true; width: 900; height: 1200
        ModuleColorEditor { id: editor; width: 850 }
        WorkspacesPage {
            id: workspaces
            visible: false
            settingsPopup: QtObject { property var barConfig: ({workspaces:{style:"dot", workspaceCount:9, maxIcons:7}}) }
        }
    }
    function check(condition, message) { if (!condition) throw new Error(message); }
    Timer {
        interval: 600; running: true
        onTriggered: {
            try {
                workspaces.resetWorkspaceSettings();
                check(workspaces.selectedStyle === "circle" && workspaces.workspaceCount === 4 && workspaces.maxIcons === 3, "reset uses current defaults");
                check(workspaces.showSpecial && workspaces.showApps && workspaces.isTransparent === BarDefaults.createWorkspacesConfig().transparent, "default workspace toggles");
                check(editor.readyColors.length === 72, "preset count");
                const colors = {};
                for (const sample of editor.readyColors) {
                    check(/^#[0-9a-f]{6}$/.test(sample.color), "valid preset");
                    colors[sample.color] = true;
                }
                check(Object.keys(colors).length === 72, "unique presets");
                editor.choose("ram", "Memory", "");
                editor.draft = "#12ABEF";
                editor.saveSelection();
                check(ColorPaletteService.moduleAccentColors.ram === "#12abef", "save");
                editor.undo();
                check(!ColorPaletteService.moduleAccentColors.ram, "undo");
                editor.draft = "invalid";
                editor.saveSelection();
                check(!ColorPaletteService.moduleAccentColors.ram, "invalid draft ignored");
                editor.draft = "#34cc88";
                editor.saveSelection();
                editor.resetSelection();
                check(!ColorPaletteService.moduleAccentColors.ram, "individual reset");
                editor.undo();
                check(ColorPaletteService.moduleAccentColors.ram === "#34cc88", "undo reset");
                editor.resetAll();
                check(Object.keys(ColorPaletteService.moduleAccentColors).length === 0, "reset all");
                console.log("COLOR_EDITOR_PASS");
            } catch(error) { console.error("COLOR_EDITOR_FAIL " + error); }
            Qt.quit();
        }
    }
}'''
            source = source.replace("SETTINGS", (ROOT / "Modules/bar/Settings").as_uri())
            source = source.replace("SERVICES", (ROOT / "Services").as_uri())
            source = source.replace("BARDEFAULTS", (ROOT / "Modules/bar/BarDefaults.js").as_uri())
            (temp / "shell.qml").write_text(source)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_RUNTIME_DIR=str(runtime),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_STATE_HOME=str(temp / "state"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(temp / "shell.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("COLOR_EDITOR_PASS", output)
            self.assertNotIn("COLOR_EDITOR_FAIL", output)
