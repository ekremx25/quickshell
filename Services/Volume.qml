pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    // Keep tracking objects when available.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Headphone hint from current default sink description.
    property bool isHeadphone: {
        if (!Pipewire.defaultAudioSink) return false
        const desc = (Pipewire.defaultAudioSink.description || "").toLowerCase()
        return desc.includes("headphone")
    }

    // Stable values consumed by OSD/UI.
    property bool sinkMuted: false
    property real sinkVolume: 0.0
    property string lastRaw: ""

    function clamp(v, minV, maxV) {
        return Math.max(minV, Math.min(maxV, v))
    }

    function applyPipewireSnapshot() {
        if (!Pipewire.defaultAudioSink) return
        var m = Pipewire.defaultAudioSink.audio.isMuted
        var v = Pipewire.defaultAudioSink.audio.volume
        root.sinkMuted = (m === true)
        if (v !== undefined && v !== null) {
            root.sinkVolume = root.clamp(v, 0.0, 1.5)
        }
    }

    function parsePactl(text) {
        if (!text || text.trim() === "") return
        if (text === root.lastRaw) return
        root.lastRaw = text

        // Expected lines:
        // VOL=NN
        // MUTE=yes|no
        var vm = text.match(/VOL=(\d+)/)
        if (vm && vm.length > 1) {
            root.sinkVolume = root.clamp(parseInt(vm[1]) / 100.0, 0.0, 1.5)
        }
        var mm = text.match(/MUTE=(yes|no)/)
        if (mm && mm.length > 1) {
            root.sinkMuted = (mm[1] === "yes")
        }
    }

    Process {
        id: readPactlProc
        command: ["/bin/bash", "-lc", "S=$(/usr/bin/pactl info | /usr/bin/sed -n \"s/^Default Sink: //p\" | /usr/bin/head -n1); [ -z \"$S\" ] && S='@DEFAULT_SINK@'; V=$(/usr/bin/pactl get-sink-volume \"$S\" 2>/dev/null | /usr/bin/sed -n \"s/.* \\([0-9]\\+\\)%.*/\\1/p\" | /usr/bin/head -n1); M=$(/usr/bin/pactl get-sink-mute \"$S\" 2>/dev/null | /usr/bin/awk '{print $2}'); [ -z \"$V\" ] && V=0; [ -z \"$M\" ] && M=no; echo \"VOL=$V\"; echo \"MUTE=$M\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { readPactlProc.out += data + "\n" } }
        onExited: {
            root.parsePactl(readPactlProc.out.trim())
            readPactlProc.out = ""
        }
    }

    function refresh() {
        // Prefer live PipeWire object when available.
        root.applyPipewireSnapshot()
        // Also poll pactl default sink so state survives node restarts/default sink switches.
        if (!readPactlProc.running) {
            readPactlProc.out = ""
            readPactlProc.running = true
        }
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    function toggleSinkMute() {
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        refresh()
    }

    function setSinkVolume(volume: real) {
        let safeVol = clamp(volume, 0.0, 1.5)
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", "@DEFAULT_SINK@", String(Math.round(safeVol * 100)) + "%"])
        sinkVolume = safeVol
        refresh()
    }
}
