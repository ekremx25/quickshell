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
    property string targetSinkName: ""

    function clamp(v, minV, maxV) {
        return Math.max(minV, Math.min(maxV, v))
    }

    function applyPipewireSnapshot() {
        if (!Pipewire.defaultAudioSink) return
        const sinkName = Pipewire.defaultAudioSink.name || ""
        if (sinkName === "effect_input.eq") return
        var m = Pipewire.defaultAudioSink.audio.isMuted
        var v = Pipewire.defaultAudioSink.audio.volume
        root.sinkMuted = (m === true)
        root.targetSinkName = sinkName
        if (v !== undefined && v !== null) {
            root.sinkVolume = root.clamp(v, 0.0, 1.5)
        }
    }

    function parsePactl(text) {
        if (!text || text.trim() === "") return
        if (text === root.lastRaw) return
        root.lastRaw = text

        // Expected lines:
        // SINK=name
        // VOL=NN
        // MUTE=yes|no
        var sm = text.match(/SINK=(.+)/)
        if (sm && sm.length > 1) {
            root.targetSinkName = sm[1].trim()
        }
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
        command: ["/bin/bash", "-lc", "STATE_FILE=\"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/eq_filter_chain.state\"; DEFAULT_SINK=$(/usr/bin/pactl info | /usr/bin/sed -n \"s/^Default Sink: //p\" | /usr/bin/head -n1); RUNNING_SINK=$(/usr/bin/pactl list short sinks | /usr/bin/awk '$5 == \"RUNNING\" {print $2}' | /usr/bin/grep -v '^effect_input\\.eq$' | /usr/bin/head -n1); STATE_SINK=''; if [ -f \"$STATE_FILE\" ]; then STATE_SINK=$(/usr/bin/awk -F'=' '/^BASE_SINK=/{print $2; exit}' \"$STATE_FILE\"); fi; S=\"$DEFAULT_SINK\"; if [ -z \"$S\" ] || [ \"$S\" = \"effect_input.eq\" ]; then if [ -n \"$RUNNING_SINK\" ]; then S=\"$RUNNING_SINK\"; elif [ -n \"$STATE_SINK\" ]; then S=\"$STATE_SINK\"; else S='@DEFAULT_SINK@'; fi; fi; V=$(/usr/bin/pactl get-sink-volume \"$S\" 2>/dev/null | /usr/bin/sed -n \"s/.* \\([0-9]\\+\\)%.*/\\1/p\" | /usr/bin/head -n1); M=$(/usr/bin/pactl get-sink-mute \"$S\" 2>/dev/null | /usr/bin/awk '{print $2}'); [ -z \"$V\" ] && V=0; [ -z \"$M\" ] && M=no; echo \"SINK=$S\"; echo \"VOL=$V\"; echo \"MUTE=$M\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { readPactlProc.out += data + "\n" } }
        onExited: {
            root.parsePactl(readPactlProc.out.trim())
            readPactlProc.out = ""
        }
    }

    function refresh() {
        // Prefer live PipeWire object only when it already points to a physical sink.
        root.applyPipewireSnapshot()
        // Poll the resolved physical sink so EQ restarts and device switches stay in sync.
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
        const sinkArg = root.targetSinkName.length > 0 ? root.targetSinkName : "@DEFAULT_SINK@"
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", sinkArg, "toggle"])
        refresh()
    }

    function setSinkVolume(volume: real) {
        let safeVol = clamp(volume, 0.0, 1.5)
        const sinkArg = root.targetSinkName.length > 0 ? root.targetSinkName : "@DEFAULT_SINK@"
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", sinkArg, String(Math.round(safeVol * 100)) + "%"])
        sinkVolume = safeVol
        refresh()
    }
}
