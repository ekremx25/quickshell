import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    property string currentClip: ""
    property int maxHistory: 20
    readonly property bool hasActive: clipboardModel.count > 0
    property alias historyModel: clipboardModel

    Process {
        id: clipProc
        command: ["wl-paste", "--type", "text/plain", "--no-newline"]
        property string output: ""
        stdout: SplitParser { onRead: data => { clipProc.output += data; } }
        onExited: {
            var text = clipProc.output.trim();
            clipProc.output = "";
            if (text !== "" && text !== backend.currentClip) {
                backend.currentClip = text;
                backend.addToHistory(text);
            }
        }
    }

    Process {
        id: copyProc
        command: []
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: backend.pollClipboard()
    }

    ListModel { id: clipboardModel }

    function pollClipboard() {
        clipProc.running = false;
        clipProc.running = true;
    }

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
        var safeText = text.replace(/'/g, "'\\''");
        copyProc.command = ["sh", "-c", "printf '%s' '" + safeText + "' | wl-copy"];
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
