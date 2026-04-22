import QtQuick
import Quickshell
import Quickshell.Io

// File read/write service.
//
// Write safety (atomic write):
//   Rather than writing to the target directly, writes a temporary file in the
//   same directory and then atomically mv's it into place. This means:
//     - A shell or QML crash never leaves a half-written config behind.
//     - A concurrent read still sees consistent data.
//
// Write queue:
//   If a new write() is called while a previous write is still in progress,
//   the running process is NOT killed; it finishes, and then a new write
//   starts with the most recent pendingText. This means:
//     - Rapid successive saves do not lose data.
//     - An atomic mv is never interrupted mid-flight.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property string readBuffer: ""
    property string pendingText: ""
    // Set to true when a new write() arrives while another is still running.
    property bool _writeQueued: false
    readonly property string _coreDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/Services/core"

    signal loaded(string text)
    signal saved(string text)
    signal failed(string phase, int exitCode, string details)

    function read() {
        if (root.path.length === 0 || readProc.running) return;
        root.readBuffer = "";
        readProc.running = true;
    }

    function write(text) {
        if (root.path.length === 0) return;
        root.pendingText = text;
        if (writeProc.running) {
            // Don't spawn a new write mid-flight; the current one will pick up
            // the most recent pendingText once it finishes.
            root._writeQueued = true;
        } else {
            writeProc.running = true;
        }
    }

    // ------------------------------------------------------------------
    // Read process
    // ------------------------------------------------------------------
    Process {
        id: readProc
        command: root.path.length > 0 ? ["cat", "--", root.path] : []
        running: false
        stdout: SplitParser { onRead: data => { root.readBuffer += data; } }
        onExited: exitCode => {
            // Exit code != 0 is normal for non-existent files (first run).
            root.loaded(root.readBuffer);
            root.readBuffer = "";
        }
    }

    // ------------------------------------------------------------------
    // Write process — atomic temp file + mv
    // ------------------------------------------------------------------
    Process {
        id: writeProc
        // Atomic write via helper script: content passes as argv $2,
        // never through shell interpretation. Zero sh -c in this file.
        command: root.path.length > 0
            ? [root._coreDir + "/atomic_write.sh", root.path, root.pendingText]
            : []
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.saved(root.pendingText);
            } else {
                root.failed("write", exitCode, "");
            }
            // If another write is queued, restart with the latest content.
            if (root._writeQueued) {
                root._writeQueued = false;
                writeProc.running = true;
            }
        }
    }
}
