pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: backend

    property string currentClip: ""
    property int maxHistory: 20
    readonly property bool hasActive: clipboardModel.count > 0
    property alias historyModel: clipboardModel

    // Event-driven: wl-paste runs the inner command once per selection change and
    // each record ends with \x1e, so multi-line clips keep their newlines.
    // Password-manager offers (x-kde-passwordManagerHint) are never recorded.
    Process {
        id: watchProc
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
            "wl-paste --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint && { printf '\\036'; exit 0; }; " +
            "cat; printf '\\036'"]
        running: true
        stdout: SplitParser {
            splitMarker: "\x1e"
            onRead: data => {
                var text = String(data).replace(/\n$/, "");
                if (text.trim() !== "" && text !== backend.currentClip) {
                    backend.currentClip = text;
                    backend.addToHistory(text);
                }
            }
        }
        // Restart the watcher if it exits (compositor restart, wl-paste crash).
        onExited: restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: watchProc.running = true
    }

    Process {
        id: copyProc
        command: []
    }

    ListModel { id: clipboardModel }

    function addToHistory(text) {
        for (var i = 0; i < clipboardModel.count; i++) {
            if (clipboardModel.get(i).text === text) {
                clipboardModel.remove(i);
                break;
            }
        }

        clipboardModel.insert(0, { text: text });
        if (clipboardModel.count > maxHistory) {
            clipboardModel.remove(maxHistory, clipboardModel.count - maxHistory);
        }
    }

    function copyToClipboard(text) {
        // wl-copy takes the text as an argument — no shell involved, no injection risk.
        copyProc.command = ["wl-copy", "--", text];
        copyProc.running = false;
        copyProc.running = true;
        currentClip = text;
        addToHistory(text);
    }

    function clearHistory() {
        clipboardModel.clear();
        currentClip = "";
        copyProc.command = ["wl-copy", "--clear"];
        copyProc.running = false;
        copyProc.running = true;
    }

    function removeAt(index) {
        if (index < 0 || index >= clipboardModel.count) return;
        clipboardModel.remove(index);
    }
}
