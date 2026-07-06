import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var command: []
    property string value: ""
    property string fallback: "Unknown"

    signal loaded(string value)

    Process {
        id: proc
        command: root.command
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                proc.buffer += data;
            }
        }
        onExited: {
            var nextValue = proc.buffer.trim() || root.fallback;
            proc.buffer = "";
            root.value = nextValue;
            root.loaded(nextValue);
        }
    }

    function refresh() {
        if (proc.running || !root.command || root.command.length === 0) return;
        proc.buffer = "";
        proc.running = true;
    }
}
