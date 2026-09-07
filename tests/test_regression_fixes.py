import http.server
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RegressionTests(unittest.TestCase):
    def run_qml(self, source, temp):
        config = temp / "config/quickshell"
        config.mkdir(parents=True)
        (config / "Services").symlink_to(ROOT / "Services")
        (config / "scripts").symlink_to(ROOT / "scripts")
        runtime = temp / "runtime"
        runtime.mkdir(mode=0o700)
        binaries = temp / "bin"
        binaries.mkdir()
        for name in ("killall", "fcitx5"):
            file = binaries / name
            file.write_text("#!/bin/sh\nexit 0\n")
            file.chmod(0o755)
        entry = temp / "shell.qml"
        source = source.replace("CORE", (ROOT / "Services/core").as_uri()).replace("SETTINGS", (ROOT / "Modules/bar/Settings").as_uri())
        entry.write_text(source)
        env = dict(os.environ, HOME=str(temp), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_CONFIG_HOME=str(temp / "config"), XDG_CACHE_HOME=str(temp / "cache"),
                   XDG_STATE_HOME=str(temp / "state"), XDG_RUNTIME_DIR=str(runtime),
                   PATH=str(binaries) + ":" + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["quickshell", "-p", str(entry)], env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        self.assertIn("REGRESSION_OK", output)
        self.assertNotIn("ReferenceError", output)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_save_acknowledges_completed_snapshot_and_multiline_read(self):
        with tempfile.TemporaryDirectory() as folder:
            temp = Path(folder)
            source = '''import QtQuick
import Quickshell
import "CORE" as Core
ShellRoot {
    property var acknowledgements: []
    Core.JsonDataStore {
        id: store; path: "TARGET"
        onSavedValue: function(value) {
            acknowledgements.push(value.name);
            if (acknowledgements.length === 1 && value.name !== "A") throw new Error("Acknowledged queued B before completion");
            if (acknowledgements.length === 2) {
                if (value.name !== "B") throw new Error("Lost queued B");
                reader.read();
            }
        }
    }
    Core.TextDataStore {
        id: reader; path: "TARGET"
        onLoaded: function(text) {
            if (text.indexOf("\\n") < 0 || JSON.parse(text).name !== "B") throw new Error("Multiline round trip failed");
            console.log("REGRESSION_OK"); Qt.quit();
        }
    }
    Component.onCompleted: { store.save({name:"A"}); store.save({name:"B"}); }
}'''.replace("TARGET", str(temp / "state.json"))
            self.run_qml(source, temp)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_api_page_stdin_transport_and_epoch_latency(self):
        received = []
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                received.append(self.headers.get("Authorization"))
                self.rfile.read(int(self.headers.get("Content-Length", 0)))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"choices":[{"message":{"content":"pong"}}]}')
            def log_message(self, *args):
                pass
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as folder:
                temp = Path(folder)
                source = '''import QtQuick
import Quickshell
import "SETTINGS"
ShellRoot {
    ApiKeysPage { id: page }
    Timer {
        interval: 300; running: true
        onTriggered: {
            page.apiKey = "FAKE_REGRESSION_SECRET";
            page.apiBase = "http://127.0.0.1:PORT/v1";
            page.model = "test";
            page.testConnection();
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (page.testStatus === "success") {
                if (page.testLatencyMs < 0 || page.testLatencyMs > 10000) throw new Error("Epoch overflow");
                console.log("REGRESSION_OK"); Qt.quit();
            }
        }
    }
}'''.replace("PORT", str(server.server_port))
                self.run_qml(source, temp)
                self.assertEqual(received, ["Bearer FAKE_REGRESSION_SECRET"])
        finally:
            server.shutdown()
            server.server_close()
