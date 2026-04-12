import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property string readBuffer: ""
    property string pendingText: ""
    property string inFlightText: ""
    property bool writeQueued: false

    signal loaded(string text)
    signal saved()
    signal failed(string phase, int exitCode)

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function startWrite() {
        if (root.path.length === 0 || writeProc.running) return;
        root.inFlightText = root.pendingText;
        root.writeQueued = false;
        writeProc.running = true;
    }

    Process {
        id: readProc
        command: root.path.length > 0 ? ["sh", "-c", "cat " + root.shellQuote(root.path) + " 2>/dev/null || true"] : []
        running: false
        stdout: SplitParser { onRead: data => { root.readBuffer += data; } }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.failed("read", exitCode);
            }
            root.loaded(root.readBuffer);
            root.readBuffer = "";
        }
    }

    Process {
        id: writeProc
        command: root.path.length > 0 ? [
            "sh",
            "-c",
            "mkdir -p \"$(dirname " + root.shellQuote(root.path) + ")\" && printf '%s' " + root.shellQuote(root.inFlightText) + " > " + root.shellQuote(root.path)
        ] : []
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.saved();
            } else {
                root.failed("write", exitCode);
            }

            if (root.writeQueued || root.pendingText !== root.inFlightText) {
                root.startWrite();
            }
        }
    }

    function read() {
        if (readProc.running || root.path.length === 0) return;
        root.readBuffer = "";
        readProc.running = true;
    }

    function write(text) {
        if (root.path.length === 0) return;
        root.pendingText = text;
        if (writeProc.running) {
            root.writeQueued = true;
            return;
        }
        root.startWrite();
    }
}
