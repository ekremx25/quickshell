import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../Services/core" as Core

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string sinkDisplayName: "No Device"
    property string sourceDisplayName: "No Microphone"
    property string currentSinkName: ""
    property string currentSourceName: ""
    property int sinkVolumePercent: 0
    property int sourceVolumePercent: 0
    property bool sinkMuted: false
    property bool sourceMuted: false

    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    signal refreshed()

    function formatNodeName(name, prefix) {
        if (!name || name.length === 0) {
            return prefix === "sink" ? "No Device" : "No Microphone";
        }

        return name
            .replace(prefix === "sink" ? /^alsa_output\./ : /^alsa_input\./, "")
            .replace(/\.analog-stereo$/, "")
            .replace(/_/g, " ");
    }

    function refresh() {
        if (audioInfoProc.running) return;
        audioInfoProc.out = "";
        audioInfoProc.running = true;
    }

    function setSinkVolumePercent(percent) {
        var value = Math.max(0, Math.min(150, Math.round(percent)));
        var sinkArg = currentSinkName.length > 0 ? currentSinkName : "@DEFAULT_SINK@";
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", sinkArg, String(value) + "%"]);
        sinkVolumePercent = value;
        refreshDebounce.restart();
    }

    function setSourceVolumePercent(percent) {
        var value = Math.max(0, Math.min(100, Math.round(percent)));
        var sourceArg = currentSourceName.length > 0 ? currentSourceName : "@DEFAULT_SOURCE@";
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-volume", sourceArg, String(value) + "%"]);
        sourceVolumePercent = value;
        refreshDebounce.restart();
    }

    function toggleSinkMute() {
        var sinkArg = currentSinkName.length > 0 ? currentSinkName : "@DEFAULT_SINK@";
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", sinkArg, "toggle"]);
        refreshDebounce.restart();
    }

    function toggleSourceMute() {
        var sourceArg = currentSourceName.length > 0 ? currentSourceName : "@DEFAULT_SOURCE@";
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-mute", sourceArg, "toggle"]);
        refreshDebounce.restart();
    }

    PwObjectTracker {
        objects: [service.defaultSink, service.defaultSource]
    }

    Process {
        id: audioInfoProc
        command: [Core.PathService.configPath("Modules/bar/System/audio_info.sh")]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => audioInfoProc.out += data + "\n" }
        onExited: {
            var lines = audioInfoProc.out.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.length === 0) continue;

                if (line.indexOf("SINK=") === 0) {
                    currentSinkName = line.substring(5);
                    sinkDisplayName = formatNodeName(currentSinkName, "sink");
                } else if (line.indexOf("SOURCE=") === 0) {
                    currentSourceName = line.substring(7);
                    sourceDisplayName = formatNodeName(currentSourceName, "source");
                } else if (line.indexOf("SINKVOL=") === 0) {
                    sinkVolumePercent = parseInt(line.substring(8)) || 0;
                } else if (line.indexOf("SINKMUTE=") === 0) {
                    sinkMuted = line.substring(9).trim() === "yes";
                } else if (line.indexOf("SOURCEVOL=") === 0) {
                    sourceVolumePercent = parseInt(line.substring(10)) || 0;
                } else if (line.indexOf("SOURCEMUTE=") === 0) {
                    sourceMuted = line.substring(11).trim() === "yes";
                }
            }

            audioInfoProc.out = "";
            refreshed();
        }
    }

    Connections {
        target: service.defaultSink
        ignoreUnknownSignals: true
        function onAudioChanged() { refreshDebounce.restart(); }
    }

    Connections {
        target: service.defaultSource
        ignoreUnknownSignals: true
        function onAudioChanged() { refreshDebounce.restart(); }
    }

    Timer {
        id: refreshDebounce
        interval: 180
        repeat: false
        onTriggered: service.refresh()
    }

    Component.onCompleted: refresh()
}
