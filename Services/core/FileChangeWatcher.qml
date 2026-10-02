import QtQuick
import Quickshell
import Quickshell.Io

// Watches a file for changes.
//
// ── SHARED INOTIFY MODE (default when inotify-tools is installed) ───────────
//   Delegates to InotifyDispatcher singleton which runs ONE inotifywait process
//   per watched directory, shared across all FileChangeWatcher instances.
//   Fixes "Too many open files" that occurred when each watcher had its own
//   long-lived inotifywait process.
//
// ── POLLING MODE (fallback when inotify-tools is not installed) ─────────────
//   Compares the (mtime, size, inode) triple via stat every `interval` ms.
//   On the first tick a baseline is recorded to avoid a spurious "changed".
//
// To install inotify-tools (Arch): sudo pacman -S inotify-tools
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property bool active: true
    property int interval: 1000  // only used in polling fallback mode

    signal changed()

    // ── Internal ──────────────────────────────────────────────────────────────
    property int _token: -1
    property bool _pollingMode: false
    property string _lastStatToken: ""
    property bool _initialized: false
    readonly property string _coreDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/Services/core"

    function _dir() {
        var idx = path.lastIndexOf("/");
        return idx > 0 ? path.substring(0, idx) : ".";
    }

    function _file() {
        var idx = path.lastIndexOf("/");
        return idx >= 0 ? path.substring(idx + 1) : path;
    }

    function _subscribe() {
        if (!active || path.length === 0 || _pollingMode || _token !== -1) return;
        _token = InotifyDispatcher.subscribe(_dir(), _file(), function() {
            root.changed();
        });
    }

    function _unsubscribe() {
        if (_token === -1) return;
        InotifyDispatcher.unsubscribe(_token);
        _token = -1;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        // Listen for dispatcher-level fallback notifications
        InotifyDispatcher.pollingFallbackRequired.connect(function(dir) {
            if (root.path.length > 0 && root._dir() === dir) {
                root._token = -1; // token is now invalid
                root._pollingMode = true;
            }
        });

        if (active && path.length > 0)
            _subscribe();
    }

    Component.onDestruction: {
        _unsubscribe();
    }

    onPathChanged: {
        _unsubscribe();
        _lastStatToken = "";
        _initialized = false;
        if (active && path.length > 0) {
            if (_pollingMode) {
                // already in polling mode, timer will pick it up automatically
            } else {
                _subscribe();
            }
        }
    }

    onActiveChanged: {
        if (active) {
            if (path.length > 0 && !_pollingMode)
                _subscribe();
        } else {
            _unsubscribe();
        }
    }

    // ── Polling fallback ──────────────────────────────────────────────────────

    Timer {
        id: pollTimer
        interval: root.interval
        running: root.active && root._pollingMode && root.path.length > 0
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
            if (!root._initialized) {
                root._lastStatToken = token;
                root._initialized = true;
                return;
            }
            if (token !== root._lastStatToken) {
                root._lastStatToken = token;
                root.changed();
            }
        }
    }
}
