pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    signal osdPulse()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property bool isHeadphone: {
        if (!Pipewire.defaultAudioSink) return false
        const desc = (Pipewire.defaultAudioSink.description || "").toLowerCase()
        return desc.includes("headphone")
    }

    property bool sinkMuted: false
    property real sinkVolume: 0.0
    property string controlSinkName: ""
    property string targetSinkName: ""
    property string lastSnapshot: ""
    property int refreshSerial: 0
    property bool pendingOsdPulse: false

    function clamp(v, minV, maxV) {
        return Math.max(minV, Math.min(maxV, v))
    }

    function requestOsdAfterRefresh() {
        root.pendingOsdPulse = true
        root.refresh()
    }

    function parseSnapshot(text) {
        if (!text || text.trim() === "") return

        var sinkMatch = text.match(/SINK=(.+)/)
        var volumeMatch = text.match(/VOL=(\d+)/)
        var muteMatch = text.match(/MUTE=(yes|no)/)

        if (sinkMatch && sinkMatch.length > 1) {
            const sinkName = sinkMatch[1].trim()
            root.controlSinkName = sinkName
            root.targetSinkName = sinkName
        }
        if (volumeMatch && volumeMatch.length > 1) {
            root.sinkVolume = root.clamp(parseInt(volumeMatch[1]) / 100.0, 0.0, 1.5)
        }
        if (muteMatch && muteMatch.length > 1) {
            root.sinkMuted = (muteMatch[1] === "yes")
        }

        if (text !== root.lastSnapshot) {
            root.lastSnapshot = text
            root.refreshSerial = root.refreshSerial + 1
        }

        if (root.pendingOsdPulse) {
            root.pendingOsdPulse = false
            root.osdPulse()
        }
    }

    Process {
        id: snapshotProc
        command: ["/bin/bash", "-lc", "STATE_FILE=\"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/eq_filter_chain.state\"; DEFAULT_SINK=$(/usr/bin/pactl info | /usr/bin/sed -n \"s/^Default Sink: //p\" | /usr/bin/head -n1); RUNNING_SINK=$(/usr/bin/pactl list short sinks | /usr/bin/awk '$5 == \"RUNNING\" {print $2}' | /usr/bin/grep -v '^effect_input\\.eq$' | /usr/bin/head -n1); STATE_SINK=''; if [ -f \"$STATE_FILE\" ]; then STATE_SINK=$(/usr/bin/awk -F'=' '/^BASE_SINK=/{print $2; exit}' \"$STATE_FILE\"); fi; CONTROL=\"$DEFAULT_SINK\"; TARGET=\"$DEFAULT_SINK\"; if [ -z \"$DEFAULT_SINK\" ]; then CONTROL='@DEFAULT_SINK@'; fi; if [ -z \"$TARGET\" ] || [ \"$TARGET\" = \"effect_input.eq\" ]; then if [ -n \"$RUNNING_SINK\" ]; then TARGET=\"$RUNNING_SINK\"; elif [ -n \"$STATE_SINK\" ]; then TARGET=\"$STATE_SINK\"; else TARGET='@DEFAULT_SINK@'; fi; fi; if [ -z \"$CONTROL\" ]; then CONTROL=\"$TARGET\"; fi; VOL=$(/usr/bin/pactl get-sink-volume \"$CONTROL\" 2>/dev/null | /usr/bin/sed -n \"s/.* \\([0-9]\\+\\)%.*/\\1/p\" | /usr/bin/head -n1); MUTE=$(/usr/bin/pactl get-sink-mute \"$CONTROL\" 2>/dev/null | /usr/bin/awk '{print $2}'); [ -z \"$VOL\" ] && VOL=0; [ -z \"$MUTE\" ] && MUTE=no; echo \"SINK=$CONTROL\"; echo \"VOL=$VOL\"; echo \"MUTE=$MUTE\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { snapshotProc.out += data + "\n" } }
        onExited: {
            root.parseSnapshot(snapshotProc.out.trim())
            snapshotProc.out = ""
        }
    }

    Process {
        id: subscribeProc
        command: ["/usr/bin/pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("sink") !== -1 || data.indexOf("server") !== -1) {
                    Qt.callLater(root.refresh)
                }
            }
        }
        onExited: {
            subscribeRestartTimer.restart()
        }
    }

    Timer {
        id: subscribeRestartTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!subscribeProc.running) {
                subscribeProc.running = true
            }
            root.refresh()
        }
    }

    function refresh() {
        if (snapshotProc.running) return
        snapshotProc.out = ""
        snapshotProc.running = true
    }

    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    function toggleSinkMute() {
        const sinkArg = root.controlSinkName.length > 0 ? root.controlSinkName : "@DEFAULT_SINK@"
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", sinkArg, "toggle"])
        root.requestOsdAfterRefresh()
    }

    function setSinkVolume(volume: real) {
        const safeVol = root.clamp(volume, 0.0, 1.5)
        const sinkArg = root.controlSinkName.length > 0 ? root.controlSinkName : "@DEFAULT_SINK@"
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", sinkArg, String(Math.round(safeVol * 100)) + "%"])
        root.requestOsdAfterRefresh()
    }

    function pulseOsd() {
        root.requestOsdAfterRefresh()
    }
}
