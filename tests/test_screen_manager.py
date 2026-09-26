"""Connected outputs remain selectable when saved role connectors are stale."""
import shutil
import unittest
from pathlib import Path
import test_dock_phase3 as qml_test

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class ScreenManagerTests(unittest.TestCase):
    run_qml = qml_test.DockPhase3Tests.run_qml

    def test_partial_roles_and_hotplug_keep_all_outputs_selectable(self):
        source = (ROOT / 'Services/ScreenManager.qml').read_text()
        functions = '\n'.join(qml_test.block(source, 'function ' + name).replace('Quickshell.screens', 'root.screens')
                              for name in ['getAvailableScreenNames()', 'getFilteredScreens(componentId)'])
        self.run_qml('''Item {
            id: root
            property var screens: [{name:"DP-3"}, {name:"DP-1"}]
            property var runtimeRoleMap: ({primary:"DP-3",secondary:"HDMI-A-1"})
            property var screenPreferences: ({})
            property var choices: getAvailableScreenNames()
            ''' + functions + '''
            Component.onCompleted: Qt.callLater(verify)
            function expect(values, message) {
                check(JSON.stringify(choices) === JSON.stringify(values), message + ": " + JSON.stringify(choices));
            }
            function verify() {
                try {
                    expect(["primary","DP-1"], "stale secondary must not hide connected output");
                    screenPreferences = {dock:["DP-1"]};
                    check(getFilteredScreens("dock").length === 1 && getFilteredScreens("dock")[0].name === "DP-1", "fallback is selectable");
                    check(runtimeRoleMap.secondary === "HDMI-A-1", "saved roles untouched");
                    runtimeRoleMap = {primary:"DP-3",secondary:"DP-1"};
                    expect(["primary","secondary"], "complete role map");
                    screens = [{name:"DP-3"},{name:"DP-1"},{name:"DP-2"},{name:"HDMI-A-2"}];
                    expect(["primary","secondary","DP-2","HDMI-A-2"], "hotplug and extra screens");
                    runtimeRoleMap = {};
                    expect(["DP-3","DP-1","DP-2","HDMI-A-2"], "no roles");
                    runtimeRoleMap = {primary:"DP-3",secondary:"DP-3"};
                    expect(["primary","DP-1","DP-2","HDMI-A-2"], "duplicate role connectors");
                    screens = [{name:"DP-5"},{name:"HDMI-A-2"}];
                    expect(["DP-5","HDMI-A-2"], "both displays moved to different ports");
                    screenPreferences = {dock:["HDMI-A-2"]};
                    check(getFilteredScreens("dock").length === 1 && getFilteredScreens("dock")[0].name === "HDMI-A-2", "new port is selectable");
                    screens = [];
                    expect([], "all disconnected");
                    console.log("DOCK_PASS");
                } catch(e) { console.error("DOCK_FAIL " + e); }
                Qt.quit();
            }
        }''')

if __name__ == '__main__':
    unittest.main()
