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
    property int _subscribeRetryCount: 0

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
        // Resolves the script path via bash env var expansion so there's no
        // dependency on PathService and no singleton-load-order pitfall.
        command: ["/bin/bash", "-lc",
            "exec \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/volume_snapshot.sh\""]
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
                root._subscribeRetryCount = 0
                if (data.indexOf("sink") !== -1 || data.indexOf("server") !== -1) {
                    refreshDebounce.restart()
                }
            }
        }
        onExited: {
            root._subscribeRetryCount++
            if (root._subscribeRetryCount < 10) {
                subscribeRestartTimer.restart()
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 120
        repeat: false
        onTriggered: root.refresh()
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
