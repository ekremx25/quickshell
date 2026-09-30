"""Workspace Overview model, actions, and offscreen interaction tests."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
OVERVIEW = ROOT / "Modules/overview"


@unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
class WorkspaceOverviewTests(unittest.TestCase):
    def run_qml(self, body: str, extra_imports: str = "") -> str:
        scratch = ROOT / ".temp_files"
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix="overview-test-") as directory:
            temp = Path(directory)
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            entry = temp / "shell.qml"
            entry.write_text(
                "import QtQuick\nimport Quickshell\n"
                + extra_imports
                + "ShellRoot {\n"
                + "function check(value, message) { if (!value) throw new Error(message); }\n"
                + body
                + "\n}\n"
            )
            env = dict(
                os.environ,
                QT_QPA_PLATFORM="offscreen",
                QT_QUICK_BACKEND="software",
                XDG_RUNTIME_DIR=str(runtime),
                XDG_CONFIG_HOME=str(temp / "config"),
                XDG_CACHE_HOME=str(temp / "cache"),
                XDG_STATE_HOME=str(temp / "state"),
            )
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["quickshell", "-p", str(entry), "--no-color"],
                env=env,
                text=True,
                capture_output=True,
                timeout=10,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("OVERVIEW_PASS", output)
            self.assertNotIn("OVERVIEW_FAIL", output)
            return output

    def test_overview_model_partition_validation_and_drop_geometry(self):
        logic_uri = (OVERVIEW / "OverviewLogic.js").as_uri()
        self.run_qml(
            r'''
    Component.onCompleted: {
        try {
            var input = [
                {id:1, targetName:"1", displayName:"I", monitor:"DP-1", is_active:true,
                 is_special:false, windows:[
                    {id:"0xaaa", app_id:"firefox", appName:"Firefox", title:"Documentation", urgent:false},
                    {id:"0xbbb", app_id:"kitty", title:"Terminal", urgent:true}
                 ]},
                {id:2, targetName:"2", displayName:"II", monitor:"DP-1", is_active:false,
                 is_special:false, windows:[]},
                {id:-99, targetName:"special:magic", displayName:"magic", monitor:"DP-1",
                 is_active:false, is_special:true, windows:[
                    {id:"0xccc", app_id:"code", title:"Editor", urgent:false},
                    {id:"0xbbb", app_id:"kitty", title:"Duplicate", urgent:false}
                 ]}
            ];
            var model = OverviewLogic.buildOverviewModel(input, function(appId) {
                return {appName: appId.toUpperCase(), iconSource: "image://icon/" + appId};
            });
            check(model.regular.length === 2, "regular workspace count");
            check(model.special.length === 1, "special workspace count");
            check(model.windowCount === 3, "windows deduplicated globally");
            check(model.regular[0].windows[0].appName === "Firefox", "resolved service app name retained");
            check(model.regular[0].windows[1].appName === "KITTY", "metadata resolver fallback");
            check(model.regular[1].empty === true, "empty target retained");
            check(model.special[0].windows.length === 1, "duplicate removed from special");

            var primary = [];
            var secondary = [];
            for (var wi = 1; wi <= 5; ++wi) primary.push({id:wi, targetName:String(wi), monitor:"DP-1", windows:[]});
            for (var wj = 6; wj <= 10; ++wj) secondary.push({id:wj, targetName:String(wj), monitor:"DP-3", windows:[]});
            secondary.push({id:1, targetName:"1", monitor:"DP-3", windows:[]});
            secondary.push({id:4, targetName:"4", monitor:"DP-3", winCount:2, windows:[
                {id:"0xd1", app_id:"discord", title:"Discord"},
                {id:"0xd2", app_id:"org.telegram.desktop", title:"Telegram"}
            ]});
            var merged = OverviewLogic.mergeWorkspaceGroups([primary, secondary]);
            check(merged.length === 10, "all monitor workspace ranges merged");
            check(merged[0].targetName === "1" && merged[9].targetName === "10", "workspace order retained");
            check(merged[3].windows.length === 2, "occupied duplicate workspace windows retained");
            check(merged[3].monitor === "DP-3", "occupied duplicate workspace metadata preferred");

            var groupedModel = OverviewLogic.buildOverviewModel(merged.concat([{
                id:-100, targetName:"special:magic", displayName:"magic", monitor:"DP-3",
                is_special:true, windows:[{id:"0xe1", app_id:"kitty", title:"Magic"}]
            }]), function(appId) { return {appName:appId, iconSource:""}; });
            var sections = OverviewLogic.groupByMonitor(groupedModel, ["DP-1", "DP-3", "HDMI-A-1"], "DP-3");
            check(sections.length === 3, "connected monitors retained as sections");
            check(sections[0].name === "DP-1" && sections[1].name === "DP-3", "monitor order retained");
            check(sections[1].focused === true, "focused monitor marked");
            check(sections[1].regular.length === 6 && sections[1].windowCount === 3, "apps grouped under their monitor");
            check(sections[1].special.length === 1, "special workspace grouped under monitor");
            check(sections[2].regular.length === 0 && sections[2].windowCount === 0, "empty connected monitor retained");

            check(OverviewLogic.isValidWindowId("0x12ab"), "valid address");
            check(!OverviewLogic.isValidWindowId("address:0x12ab;rm"), "unsafe address rejected");
            check(OverviewLogic.isValidWorkspaceTarget("10"), "numeric workspace");
            check(OverviewLogic.isValidWorkspaceTarget("special:magic"), "special workspace");
            check(!OverviewLogic.isValidWorkspaceTarget("special:a;bad"), "unsafe special target rejected");
            check(OverviewLogic.canDrop("0xaaa", "1", "2"), "different target allowed");
            check(!OverviewLogic.canDrop("0xaaa", "1", "1"), "same target is no-op");
            check(!OverviewLogic.canDrop("bad", "1", "2"), "invalid address cannot drop");

            var rects = [
                {target:"1", x:0, y:0, width:100, height:80},
                {target:"2", x:110, y:0, width:100, height:80}
            ];
            check(OverviewLogic.dropTargetAt(rects, 130, 20) === "2", "target geometry");
            check(OverviewLogic.dropTargetAt(rects, 105, 20) === "", "gap is not target");
            check(OverviewLogic.truncateTitle("123456789", 6) === "12345…", "title truncation");
            var state = WorkspaceLogic.buildHyprlandState([
                {name:"DP-1", focused:false, activeWorkspace:{id:1}},
                {name:"DP-2", focused:true, activeWorkspace:{id:2}}
            ], [], []);
            check(state.focusedMonitor === "DP-2", "focused monitor retained");
            console.log("OVERVIEW_PASS");
        } catch (error) {
            console.error("OVERVIEW_FAIL " + error);
        }
        Qt.callLater(Qt.quit);
    }
''',
            f'import "{logic_uri}" as OverviewLogic\nimport "{(ROOT / "Services/core/WorkspaceLogic.js").as_uri()}" as WorkspaceLogic\n',
        )


    def test_hyprland_action_helper_validates_and_uses_lua_window_selector(self):
        helper = ROOT / "scripts/hypr_overview_action.sh"
        with tempfile.TemporaryDirectory(prefix="overview-actions-") as directory:
            temp = Path(directory)
            log = temp / "hyprctl.log"
            fake = temp / "hyprctl"
            fake.write_text("""#!/usr/bin/env bash
set -u
if [[ \"${1:-}\" == systeminfo ]]; then echo 'configProvider: lua'; exit 0; fi
printf '%s\\n' \"$*\" >> \"$OVERVIEW_LOG\"
""")
            fake.chmod(0o755)
            env = dict(os.environ, PATH=str(temp) + os.pathsep + os.environ["PATH"], OVERVIEW_LOG=str(log))
            good = subprocess.run([str(helper), "move", "0x12ab", "4"], env=env, text=True, capture_output=True)
            self.assertEqual(good.returncode, 0, good.stderr)
            line = log.read_text()
            self.assertIn('workspace = "4"', line)
            self.assertIn('window = "address:0x12ab"', line)
            self.assertIn('follow = false', line)
            before = log.read_text()
            bad = subprocess.run([str(helper), "move", "0x12ab;touch", "4"], env=env, text=True, capture_output=True)
            self.assertEqual(bad.returncode, 2)
            self.assertEqual(log.read_text(), before)
            bad_monitor = subprocess.run([str(helper), "move", "0x12ab", "4", "DP-3;touch"], env=env, text=True, capture_output=True)
            self.assertEqual(bad_monitor.returncode, 2)
            self.assertEqual(log.read_text(), before)
            workspace = subprocess.run([str(helper), "workspace", "", "special:magic"], env=env, text=True, capture_output=True)
            self.assertEqual(workspace.returncode, 0, workspace.stderr)
            self.assertIn('workspace = "special:magic"', log.read_text())

            overview_source = (OVERVIEW / "WorkspaceOverview.qml").read_text()
            service_source = (ROOT / "Services/WorkspaceService.qml").read_text()
            self.assertIn("workspaceCard.modelData.targetName, workspaceCard.modelData.monitor", overview_source)
            self.assertIn("specialCard.modelData.targetName, specialCard.modelData.monitor", overview_source)
            self.assertIn('if (kind === "move") command.push(String(monitorName || ""))', service_source)


if __name__ == "__main__":
    unittest.main()
