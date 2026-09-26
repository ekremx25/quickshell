"""Run the Connect button handler against a fake nmcli, never the live network."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WifiConnectTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_button_starts_one_connection_and_clears_busy(self):
        self.run_connection("", 0)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_password_over_stdin(self):
        self.run_connection("test-Only!$(literal)", 0)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_wrong_password_is_reported_without_secret(self):
        self.run_connection("test-Only!$(literal)", 4)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_timeout_is_reported(self):
        self.run_connection("test-Only!$(literal)", 3)

    def run_connection(self, password, exit_code):
        page = (ROOT / "Modules/bar/System/NetworkPage.qml").read_text()
        button = page[page.index("id: wifiConnMA;"):]
        handler = re.search(r"onClicked:\s*\{([^}]+)\}", button).group(1)
        with tempfile.TemporaryDirectory(prefix="qs-wifi-connect-") as directory:
            temp = Path(directory)
            binaries = temp / "bin"
            binaries.mkdir()
            log = temp / "calls.jsonl"
            fake = binaries / "nmcli"
            fake.write_text("#!" + shutil.which("python3") + "\n" + '''import json, os, sys
with open(os.environ['NMCLI_CALLS'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
if 'connect' in sys.argv:
    value = sys.stdin.readline().rstrip('\\n') if '--ask' in sys.argv else ''
    expected = os.environ.get('TEST_PASSWORD', '')
    if value != expected:
        sys.exit(99)
    # Simulate an untrusted diagnostic containing a secret. It must not reach QML.
    if expected:
        print(expected, file=sys.stderr)
    sys.exit(int(os.environ['TEST_EXIT']))
sys.exit(0)
''')
            fake.chmod(0o755)
            # Read-only follow-up refresh commands also stay inside the fixture.
            for name in ("ip", "cat"):
                stub = binaries / name
                stub.write_text("#!/bin/sh\nexit 0\n")
                stub.chmod(0o755)
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = '''import QtQuick
import Quickshell
import "__SYSTEM__"
ShellRoot {
    id: test
    property bool started: false
    property bool clicked: false
    property var modelData: ({ssid: "Office: Guest $(literal)"})
    NetworkService {
        id: networkService
        active: false
        onConnectingSsidChanged: {
            if (connectingSsid !== "") test.started = true;
            else if (test.started && test.clicked) Qt.callLater(test.finish);
        }
    }
    QtObject {
        id: networkPage
        property alias connectingSsid: networkService.connectingSsid
    }
    QtObject { id: wifiPassword; property string text: __PASSWORD__; function clear() { text = ""; } }
    function click() { __HANDLER__ }
    Component.onCompleted: Qt.callLater(function() {
        click();
        // Repeated dispatch while busy must not start another command.
        click();
        clicked = true;
    })
    function finish() {
        if (networkPage.connectingSsid !== "") console.error("CONNECT_FAIL busy state");
        else if (wifiPassword.text !== "") console.error("CONNECT_FAIL password not cleared");
        else if (networkService.wifiError !== __ERROR__) console.error("CONNECT_FAIL error flag");
        else if (networkService.wifiStatus !== __MESSAGE__) console.error("CONNECT_FAIL message: " + networkService.wifiStatus);
        else console.log("CONNECT_PASS");
        Qt.quit();
    }
    Timer {
        interval: 3000; running: true
        onTriggered: { console.error("CONNECT_TIMEOUT"); Qt.quit(); }
    }
}'''.replace("__SYSTEM__", (ROOT / "Modules/bar/System").as_uri()).replace("__HANDLER__", handler)
            message = {0: "Connected.", 4: "Connection failed. Check the password and network availability.",
                       3: "Connection timed out. Try again."}[exit_code]
            source = source.replace("__PASSWORD__", json.dumps(password)).replace("__ERROR__", str(exit_code != 0).lower()).replace("__MESSAGE__", json.dumps(message))
            entry = temp / "shell.qml"
            entry.write_text(source)
            env = dict(os.environ, PATH=str(binaries) + ":/usr/bin:/bin", NMCLI_CALLS=str(log),
                       TEST_PASSWORD=password, TEST_EXIT=str(exit_code),
                       HOME=str(temp), XDG_CONFIG_HOME=str(temp / "config"),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_STATE_HOME=str(temp / "state"),
                       XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("CONNECT_PASS", output)
            self.assertNotIn("CONNECT_FAIL", output)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            connects = [call for call in calls if "connect" in call]
            self.assertEqual(connects, [["--wait", "30"] + (["--ask"] if password else []) + ["device", "wifi", "connect", "Office: Guest $(literal)"]])
            if password:
                self.assertNotIn(password, output)
                self.assertNotIn(password, log.read_text())


if __name__ == "__main__":
    unittest.main()
