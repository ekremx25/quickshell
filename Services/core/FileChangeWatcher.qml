import QtQuick
import Quickshell
import Quickshell.Io

// Watches a file for changes.
//
// ── INOTIFY MODE (when inotify-tools is installed) ─────────────────
//   Uses inotifywait to watch the directory; emits on close_write or
//   moved_to events. Zero CPU cost — no timer, no polling. Atomic mv
//   writes (from TextDataStore) are caught correctly.
//
// ── POLLING MODE (falls back automatically if inotify-tools missing) ─
//   Compares the (mtime, size, inode) triple via stat. On the first
//   tick a baseline is recorded so no spurious "changed" is emitted.
//
// To install inotify-tools (Arch): sudo pacman -S inotify-tools
// After install any config reload picks it up automatically.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property bool active: true
    // interval is only used in the polling fallback mode
    property int interval: 1000

    signal changed()

    // Set to true if inotifywait is not available (exit 127) — polling takes over
    property bool _pollingMode: false
    property string _lastToken: ""
    property bool _initialized: false
    readonly property string _coreDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/Services/core"

    // Returns the directory portion of `path`
    function _dir() {
        var idx = path.lastIndexOf("/");
        return idx > 0 ? path.substring(0, idx) : ".";
    }

    // Returns the filename portion of `path`
    function _file() {
        var idx = path.lastIndexOf("/");
        return idx >= 0 ? path.substring(idx + 1) : path;
    }

    // ----------------------------------------------------------------
    // inotifywait-based watcher (event-driven)
    // ----------------------------------------------------------------
    Process {
        id: watchProc
        running: root.active && root.path.length > 0 && !root._pollingMode
        // Watch the directory; moved_to also catches atomic mv writes.
        command: root.path.length > 0
            ? ["inotifywait", "-m", "-q", "-e", "close_write,moved_to", "--format", "%f", root._dir()]
            : []

        stdout: SplitParser {
            onRead: data => {
                // Only signal if the file we actually care about changed.
                if (data.trim() === root._file()) {
                    root.changed();
                }
            }
        }

        onExited: exitCode => {
            if (!root.active) return;
            if (exitCode === 127) {
                // inotifywait is not installed → switch to polling mode
                root._pollingMode = true;
                return;
            }
            // Transient failure (directory recreated, compositor restart, etc.)
            // Retry after 1 second.
            inotifyRestartTimer.restart();
        }
    }

    Timer {
        id: inotifyRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.active && root.path.length > 0 && !root._pollingMode) {
                watchProc.running = true;
            }
        }
    }

    // ----------------------------------------------------------------
    // Polling fallback (used when inotify-tools is not installed)
    // ----------------------------------------------------------------
    Timer {
        id: pollTimer
        interval: root.interval
        running: root.active && root._pollingMode
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statProc.running && root.path.length > 0) {
                statProc.output = "";
                statProc.running = true;
            }
        }
    }

    Process {
        id: statProc
        command: root.path.length > 0 ? [root._coreDir + "/file_stat.sh", root.path] : []
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => { statProc.output += data; } }
        onExited: {
            var token = statProc.output.trim();
            statProc.output = "";
            if (token.length === 0) return;
            // Seed the baseline on the first tick; don't emit a spurious "changed".
            if (!root._initialized) {
                root._lastToken = token;
                root._initialized = true;
                return;
            }
            if (token !== root._lastToken) {
                root._lastToken = token;
                root.changed();
            }
        }
    }
}
