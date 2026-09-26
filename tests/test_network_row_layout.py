"""Render the actual Wi-Fi delegate offscreen without starting network services."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NetworkRowLayoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_text_bounds_and_signal_baseline(self):
        self.check_layout(False)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_expanded_password_and_error_fit(self):
        self.check_layout(True)

    def check_layout(self, expanded):
        source = (ROOT / "Modules/bar/System/NetworkPage.qml").read_text()
        start = source.index("                Rectangle {\n                    id: wifiDelegate")
        end = source.index("\n            }\n\n            Item { height: 20 }", start)
        delegate = source[start:end]
        delegate = delegate.replace("required property var modelData", 'property var modelData: ({ssid:"Test network", security:"WPA2", signal:72, barLevel:3, active:false})')
        delegate = delegate.replace("required property int index", "property int index: 0", 1)
        delegate = delegate.replace("Theme.", "testTheme.").replace("SettingsPalette.", "testPalette.")
        delegate = re.sub(r"(?<![\w.])modelData\.", "wifiDelegate.modelData.", delegate)
        qml = '''import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
ShellRoot {
    QtObject {
        id: testTheme
        property color cpRed: "#ff0000"
        property color primary: "#aaaaaa"
        property color text: "#eeeeee"
        property string fontFamily: "DejaVu Sans"
        function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
        function foregroundFor(c) { return "#000000"; }
    }
    QtObject {
        id: testPalette
        property color text: "#eeeeee"
        property color subtext: "#aaaaaa"
        property color surface: "#222222"
    }
    QtObject { id: networkService; property string wifiStatusSsid: "Test network"; property string wifiStatus: "Connection failed. Check the password and network availability."; property bool wifiError: true }
    QtObject { id: networkPage; property string connectingSsid: "" }
    Window {
        visible: true; width: 640; height: 300
        property bool checked: false
        ColumnLayout {
            width: parent.width
            __DELEGATE__
            Rectangle { id: nextNetwork; Layout.fillWidth: true; implicitHeight: 48 }
        }
        function descendants(item, result) {
            for (var i = 0; i < item.children.length; i++) {
                var child = item.children[i];
                result.push(child);
                descendants(child, result);
            }
        }
        function verify() {
            var failures = [];
            var items = [];
            descendants(wifiDelegate, items);
            var labels = 0;
            var bars = [];
            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.text !== undefined && (item.text === "Test network" || String(item.text).indexOf("72%") !== -1)) {
                    labels++;
                    var pos = item.mapToItem(wifiDelegate, 0, 0);
                    if (pos.y < 0 || pos.y + item.height > wifiDelegate.height + 0.5)
                        failures.push("text clipped: " + item.text + " bottom=" + (pos.y + item.height) + " row=" + wifiDelegate.height);
                }
                if (item.width === 4 && item.radius === 1) bars.push(item);
            }
            if (nextNetwork.y < wifiDelegate.y + wifiDelegate.height - 0.5) failures.push("next network overlaps expanded card");
            if (wifiDelegate.wifiExpanded) {
                if (wifiPassword.echoMode !== TextInput.Password) failures.push("password not masked");
                var pos = wifiActions.mapToItem(wifiDelegate, 0, wifiActions.height);
                if (pos.y > wifiDelegate.height + 0.5) failures.push("expanded controls clipped");
                wifiPassword.text = "test-only-secret";
                wifiDelegate.wifiExpanded = false;
                if (wifiPassword.text !== "") failures.push("password not cleared on collapse");
            }
            if (labels !== 2) failures.push("expected SSID and percentage labels");
            if (bars.length !== 4) failures.push("expected four bars");
            else {
                var baseline = bars[0].mapToItem(wifiDelegate, 0, bars[0].height).y;
                for (var j = 1; j < bars.length; j++) {
                    if (Math.abs(bars[j].mapToItem(wifiDelegate, 0, bars[j].height).y - baseline) > 0.5)
                        failures.push("signal bars not bottom-aligned");
                }
            }
            if (failures.length) console.error("LAYOUT_FAIL " + failures.join("; "));
            else console.log("LAYOUT_PASS");
            Qt.quit();
        }
        property bool expansionRequested: false
        onAfterAnimating: {
            if (!checked && wifiDelegate.width > 0) {
                if (__EXPANDED__ && !expansionRequested) {
                    expansionRequested = true;
                    wifiDelegate.wifiExpanded = true;
                    return;
                }
                if (__EXPANDED__ && Math.abs(wifiDelegate.height - (wifiActions.y + wifiActions.implicitHeight + 12)) > 0.5) return;
                checked = true;
                Qt.callLater(verify);
            }
        }
    }
    Timer { interval: 3000; running: true; onTriggered: { console.error("LAYOUT_TIMEOUT"); Qt.quit(); } }
}'''.replace("__DELEGATE__", delegate).replace("__EXPANDED__", str(expanded).lower())
        with tempfile.TemporaryDirectory(prefix="qs-network-layout-") as directory:
            temp = Path(directory)
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            entry = temp / "shell.qml"
            entry.write_text(qml)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(temp / "config"),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_STATE_HOME=str(temp / "state"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("LAYOUT_PASS", output)
            self.assertNotIn("LAYOUT_FAIL", output)
            self.assertNotIn("ReferenceError", output)


if __name__ == "__main__":
    unittest.main()
