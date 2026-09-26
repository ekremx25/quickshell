"""Characterize NetworkManager's escaped terse-output format."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NmcliTerseParserTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_escaped_fields_and_lines(self):
        with tempfile.TemporaryDirectory(prefix="qs-nmcli-") as directory:
            temp = Path(directory)
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = '''import QtQuick
import Quickshell
import "__PARSER_URI__" as NmcliTerseParser
ShellRoot {
    function check(condition, message) { if (!condition) throw new Error(message); }
    Timer {
        interval: 50; running: true
        onTriggered: {
            try {
                var escaped = NmcliTerseParser.splitLine("Office\\\\: VPN:uuid:vpn:yes");
                check(escaped.length === 4, "escaped colon field count");
                check(escaped[0] === "Office: VPN", "escaped colon value");
                check(escaped[1] === "uuid" && escaped[2] === "vpn" && escaped[3] === "yes", "remaining fields");

                var slash = NmcliTerseParser.splitLine("Office\\\\\\\\Lab:ethernet");
                check(slash.length === 2 && slash[0] === "Office\\\\Lab", "escaped backslash value");

                var unknown = NmcliTerseParser.splitLine("name\\\\q:value");
                check(unknown[0] === "name\\\\q", "unknown escape preserved");

                var trailing = NmcliTerseParser.splitLine("name:value:");
                check(trailing.length === 3 && trailing[2] === "", "empty trailing field");

                var lines = NmcliTerseParser.parseLines("first:ethernet\\n\\nsecond\\\\:name:wifi\\n");
                check(lines.length === 2, "empty lines ignored");
                check(lines[1][0] === "second:name" && lines[1][1] === "wifi", "multi-line parse");
                console.log("NMCLI_PARSER_PASS");
            } catch (error) {
                console.error("NMCLI_PARSER_FAIL " + error);
            }
            Qt.quit();
        }
    }
}'''.replace("__PARSER_URI__", (ROOT / "Services/core/NmcliTerseParser.js").as_uri())
            entry = temp / "shell.qml"
            entry.write_text(source)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(temp / "cache"),
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_STATE_HOME=str(temp / "state"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertIn("NMCLI_PARSER_PASS", output)
            self.assertNotIn("NMCLI_PARSER_FAIL", output)


if __name__ == "__main__":
    unittest.main()
