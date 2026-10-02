pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ── InotifyDispatcher ─────────────────────────────────────────────────────────
//
// Global singleton that keeps ONE inotifywait process per watched directory.
// Multiple FileChangeWatcher instances sharing the same directory are served
// by a single process, reducing open file descriptors from N×3 to 1×3 per dir.
//
// API:
//   subscribe(dir, file, callback) → token (int)
//   unsubscribe(token)
//   signal pollingFallbackRequired(string dir)
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: root

    property var _watchers: ({})
    property int _nextId: 1

    signal pollingFallbackRequired(string dir)

    function subscribe(dir, file, callback) {
        var token = root._nextId++;
        _ensureWatcher(dir);
        root._watchers[dir].subscribers.push({ id: token, file: file, cb: callback });
        return token;
    }

    function unsubscribe(token) {
        var keys = Object.keys(root._watchers);
        for (var i = 0; i < keys.length; i++) {
            var dir = keys[i];
            var entry = root._watchers[dir];
            var subs = entry.subscribers;
            for (var j = 0; j < subs.length; j++) {
                if (subs[j].id === token) {
                    subs.splice(j, 1);
                    if (subs.length === 0 && !entry.dead) {
                        entry.proc.stop();
                        delete root._watchers[dir];
                    }
                    return;
                }
            }
        }
    }

    function _ensureWatcher(dir) {
        if (root._watchers[dir]) return;
        var proc = _procComponent.createObject(root, { watchDir: dir });
        root._watchers[dir] = { proc: proc, subscribers: [], dead: false };
    }

    function _dispatch(dir, filename) {
        var entry = root._watchers[dir];
        if (!entry) return;
        var subs = entry.subscribers;
        for (var i = 0; i < subs.length; i++) {
            if (subs[i].file === filename)
                subs[i].cb();
        }
    }

    function _onInotifyUnavailable(dir) {
        var entry = root._watchers[dir];
        if (entry) entry.dead = true;
        root.pollingFallbackRequired(dir);
    }

    // QtObject yerine Item kullanmak "not placed in graphics scene" uyarısına
    // neden olur. Process ve Timer görsel parent gerektirmez, QtObject yeterli.
    property Component _procComponent: Component {
        QtObject {
            id: self

            property string watchDir: ""

            function stop() {
                inotifyProc.running = false;
                retryTimer.stop();
            }

            property var inotifyProc: Process {
                id: inotifyProc
                running: self.watchDir.length > 0
                command: self.watchDir.length > 0
                    ? ["inotifywait", "-m", "-q", "-e", "close_write,moved_to", "--format", "%f", self.watchDir]
                    : []

                stdout: SplitParser {
                    onRead: data => {
                        var filename = data.trim();
                        if (filename.length > 0)
                            root._dispatch(self.watchDir, filename);
                    }
                }

                onExited: exitCode => {
                    if (!self.watchDir.length) return;
                    if (exitCode === 127) {
                        root._onInotifyUnavailable(self.watchDir);
                        return;
                    }
                    retryTimer.restart();
                }
            }

            property var retryTimer: Timer {
                id: retryTimer
                interval: 1000
                repeat: false
                onTriggered: {
                    if (self.watchDir.length > 0)
                        inotifyProc.running = true;
                }
            }
        }
    }
}
