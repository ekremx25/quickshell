pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core

// Audio spectrum from cava, shared by every visualizer. cava only runs while
// at least one consumer has called acquire() (e.g. while music is playing),
// and is skipped entirely when it is not installed.
Singleton {
    id: root

    readonly property int bars: 24
    property var values: []          // 0..1 per bar, auto-gained
    property real peak: 0.04
    property bool available: false
    property bool checked: false     // true once the first `command -v cava` finished
    property int consumers: 0
    readonly property bool active: available && consumers > 0

    function acquire() {
        consumers += 1;
        // Re-check so installing cava works without restarting the shell.
        if (!available && !checkProc.running) checkProc.running = true;
    }
    function release() {
        consumers = Math.max(0, consumers - 1);
        if (consumers === 0) values = [];
    }

    Process {
        id: checkProc
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null"]
        onExited: code => {
            root.available = code === 0;
            root.checked = true;
        }
    }

    // Someone wants a spectrum but cava is missing: look again now and then,
    // so installing it mid-song starts the visualizer without a restart.
    Timer {
        interval: 5000
        repeat: true
        running: root.consumers > 0 && !root.available
        onTriggered: if (!checkProc.running) checkProc.running = true
    }

    Process {
        running: root.active
        command: ["cava", "-p", Core.PathService.configPath("Services/core/cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                var parts = String(line).split(";");
                var raw = [];
                var frameMax = 0;
                for (var i = 0; i < parts.length && raw.length < root.bars; i++) {
                    if (parts[i] === "") continue;
                    var v = parseInt(parts[i], 10);
                    v = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
                    raw.push(v);
                    frameMax = Math.max(frameMax, v);
                }
                if (raw.length === 0) return;
                // Auto-gain: scale against a slowly decaying recent peak so quiet
                // passages still move the bars and loud ones do not clip.
                root.peak = Math.max(frameMax, root.peak * 0.985, 0.04);
                var next = [];
                for (var j = 0; j < raw.length; j++) next.push(Math.sqrt(raw[j] / root.peak));
                root.values = next;
            }
        }
    }
}
