import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services"
import "../../../Services/core/Log.js" as Log

Item {
    id: backend

    property var eqFrequencies: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    property var eqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string selectedPreset: "Flat"
    property string applyStatus: "Not applied"
    property string sinkDisplayName: "Loading..."
    property string sourceDisplayName: "Loading..."
    property int sinkVolumePercent: 0
    property int sourceVolumePercent: 0
    property bool sinkMuted: false
    property bool sourceMuted: false
    property string currentSinkName: ""
    property string currentSourceName: ""
    property string lastAppliedTargetSink: ""
    property string pendingAutoTargetSink: ""
    property bool pendingEqApply: false
    property bool hydratingEqState: false
    property var pendingEqBandsSnapshot: null
    property var appliedEqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool hasPendingEqChanges: false
    property bool bandDragActive: false
    property var availableSinks: []
    readonly property bool isBusy: eqProc.running
    readonly property var presetNames: ["Flat", "Bass", "Movie", "Treble", "Voice", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (homeDir + "/.local/state")
    readonly property string eqScriptPath: configDir + "/quickshell/scripts/eq_filter_chain.sh"
    readonly property string eqPipewireConfPath: configDir + "/pipewire/pipewire.conf.d/90-quickshell-eq.conf"
    readonly property string eqStatePath: stateHome + "/quickshell/eq_filter_chain.state"

    readonly property var presetMap: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [5, 4, 3, 2, 1, 0, -2, -3, -4, -5],
        "Movie":   [4, 3, 2, 0, -1, 0, 2, 3, 4, 4],
        "Treble":  [-4, -3, -2, -1, 0, 1, 2, 3, 4, 5],
        "Voice":   [-4, -3, -1, 2, 4, 5, 4, 2, 0, -1],
        "Vocal":   [-2, -1, 1, 3, 4, 3, 1, -1, -2, -3],
        "Pop":     [-1, 1, 3, 4, 2, 0, -1, 1, 3, 4],
        "Rock":    [3, 2, 1, 0, -1, 1, 3, 4, 3, 2],
        "Jazz":    [2, 1, 0, 2, 3, 2, 1, 0, 1, 2],
        "Classic": [1, 2, 3, 1, -1, -1, 0, 1, 2, 3]
    })

    function resetProcessBuffer(proc) {
        if (proc.out !== undefined) proc.out = "";
    }

    function startManagedProcess(proc, nextCommand) {
        if (proc.running) return false;
        resetProcessBuffer(proc);
        if (nextCommand !== undefined) proc.command = nextCommand;
        proc.running = true;
        return true;
    }

    function scheduleRefresh(delayMs) {
        refreshDebounce.interval = delayMs !== undefined ? delayMs : 120;
        refreshDebounce.restart();
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function formatSourceLabel(name) {
        return name.replace(/^alsa_input\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
    }

    function parseAudioSnapshot(text) {
        var lines = text.trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim();
            if (l.length === 0) continue;
            if (l.indexOf("SINK=") === 0) {
                var s = l.substring(5);
                if (s.length > 0) {
                    backend.currentSinkName = s;
                    backend.sinkDisplayName = backend.formatSinkLabel(s);
                    if (backend.lastAppliedTargetSink.length === 0) backend.lastAppliedTargetSink = s;
                }
            } else if (l.indexOf("SOURCE=") === 0) {
                var src = l.substring(7);
                if (src.length > 0) {
                    backend.currentSourceName = src;
                    backend.sourceDisplayName = backend.formatSourceLabel(src);
                }
            } else if (l.indexOf("SOURCEVOL=") === 0) {
                backend.sourceVolumePercent = parseInt(l.substring(10)) || 0;
            } else if (l.indexOf("SOURCEMUTE=") === 0) {
                backend.sourceMuted = (l.substring(11).trim() === "yes");
            }
        }
        backend.syncSinkControlsFromVolume();
    }

    function parseSinkList(text) {
        var lines = text.trim().split("\n");
        var items = [];
        var remembered = "";
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0) continue;
            if (line.indexOf("CURRENT=") === 0) {
                remembered = line.substring(8).trim();
                continue;
            }
            var parts = line.split("|");
            if (parts.length < 2) continue;
            items.push({
                name: parts[0],
                state: parts[1],
                label: backend.formatSinkLabel(parts[0]),
                selected: false
            });
        }

        var target = backend.currentSinkName.length > 0 ? backend.currentSinkName : remembered;
        for (var j = 0; j < items.length; j++) {
            items[j].selected = (target.length > 0 && items[j].name === target);
        }
        backend.availableSinks = items;
    }

    function parseEqState(text) {
        var lines = text.split("\n");
        var gains = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var m = line.match(/Gain\s+(-?\d+(?:\.\d+)?)\s+dB/i);
            if (m && m.length > 1) gains.push(parseFloat(m[1]));
        }
        if (gains.length === 10) {
            backend.hydratingEqState = true;
            backend.eqBands = gains;
            backend.appliedEqBands = gains.slice();
            backend.selectedPreset = backend.detectPresetFromBands(gains);
            backend.hydratingEqState = false;
            backend.updatePendingEqState();
        }
    }

    function updatePendingEqState() {
        backend.hasPendingEqChanges = !backend.sameBands(backend.eqBands, backend.appliedEqBands);
    }

    Process {
        id: eqProc
        command: []
        running: false
        property string out: ""
        property string requestedTargetSink: "auto"
        property string requestedAction: ""
        property var requestedBandsSnapshot: null
        stdout: SplitParser { onRead: data => { eqProc.out += data + "\n"; } }
        stderr: SplitParser { onRead: data => { eqProc.out += data + "\n"; } }
        onExited: code => {
            if (code === 0) {
                if (eqProc.requestedAction === "switch") {
                    backend.applyStatus = "Output switched";
                } else if (eqProc.requestedAction === "disable") {
                    backend.applyStatus = "Disabled";
                } else {
                    backend.applyStatus = "Applied";
                }
                if (eqProc.requestedTargetSink.length > 0 && eqProc.requestedTargetSink !== "auto") {
                    backend.lastAppliedTargetSink = eqProc.requestedTargetSink;
                }
                if (eqProc.requestedAction === "apply" && eqProc.requestedBandsSnapshot && eqProc.requestedBandsSnapshot.length === 10) {
                    backend.appliedEqBands = eqProc.requestedBandsSnapshot.slice();
                    backend.updatePendingEqState();
                }
                if (eqProc.requestedAction === "switch") {
                    backend.pendingAutoTargetSink = "";
                }
            } else {
                var errText = eqProc.out.trim();
                if (errText.length > 80) errText = errText.substring(0, 80) + "...";
                backend.applyStatus = errText.length > 0 ? ("Error (" + code + "): " + errText) : ("Error (" + code + ")");
                Log.warn("EqualizerBackend", backend.applyStatus);
            }
            backend.scheduleRefresh(120);
            delayedRefreshTimer.restart();
            routeRecoveryTimer.restart();
            Volume.pulseOsd();
            eqProc.out = "";
            eqProc.requestedAction = "";
            eqProc.requestedBandsSnapshot = null;
            if (backend.pendingEqApply) {
                backend.pendingEqApply = false;
                if (backend.pendingEqBandsSnapshot && backend.pendingEqBandsSnapshot.length === 10) {
                    if (backend.bandDragActive) {
                        bandPreviewTimer.restart();
                    } else {
                        backend.applyToPipeWire(backend.pendingEqBandsSnapshot);
                    }
                }
            }
        }
    }

    Process {
        id: recoverProc
        command: ["/bin/bash", backend.eqScriptPath, "recover"]
        running: false
    }

    Process {
        id: startupEqCheckProc
        command: ["/usr/bin/test", "-f", backend.eqPipewireConfPath]
        running: false
        onExited: code => {
            if (code === 0) startupRecoverTimer.restart();
        }
    }

    Process {
        id: audioInfoProc
        command: ["/bin/bash", "-lc", "STATE_FILE=" + backend.shellQuote(backend.eqStatePath) + "; DEFAULT_SINK=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Sink:/{print $2; exit}'); RUNNING_SINK=$(/usr/bin/pactl list short sinks | /usr/bin/awk '$5 == \"RUNNING\" {print $2}' | /usr/bin/grep -v '^effect_input\\.eq$' | /usr/bin/head -n1); STATE_SINK=''; if [ -f \"$STATE_FILE\" ]; then STATE_SINK=$(/usr/bin/awk -F'=' '/^BASE_SINK=/{print $2; exit}' \"$STATE_FILE\"); fi; S=\"$DEFAULT_SINK\"; if [ \"$DEFAULT_SINK\" = \"effect_input.eq\" ]; then if [ -n \"$STATE_SINK\" ]; then S=\"$STATE_SINK\"; elif [ -n \"$RUNNING_SINK\" ]; then S=\"$RUNNING_SINK\"; fi; fi; SR=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Source:/{print $2; exit}'); SV=$(/usr/bin/pactl get-sink-volume \"$S\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SM=$(/usr/bin/pactl get-sink-mute \"$S\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); SRV=$(/usr/bin/pactl get-source-volume \"$SR\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SRM=$(/usr/bin/pactl get-source-mute \"$SR\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); echo \"SINK=$S\"; echo \"SOURCE=$SR\"; echo \"SINKVOL=$SV\"; echo \"SINKMUTE=$SM\"; echo \"SOURCEVOL=$SRV\"; echo \"SOURCEMUTE=$SRM\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { audioInfoProc.out += data + "\n"; } }
        onExited: {
            backend.parseAudioSnapshot(audioInfoProc.out);
            audioInfoProc.out = "";
        }
    }

    Process {
        id: sinkListProc
        command: ["/bin/bash", "-lc", "STATE_FILE=" + backend.shellQuote(backend.eqStatePath) + "; CURRENT=''; if [ -f \"$STATE_FILE\" ]; then CURRENT=$(/usr/bin/awk -F'=' '/^BASE_SINK=/{print $2; exit}' \"$STATE_FILE\"); fi; /usr/bin/pactl list short sinks | /usr/bin/awk '{print $2 \"|\" $5}' | /usr/bin/grep -v '^effect_input\\.eq|' || true; echo \"CURRENT=$CURRENT\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { sinkListProc.out += data + "\n"; } }
        onExited: {
            backend.parseSinkList(sinkListProc.out);
            sinkListProc.out = "";
        }
    }

    Process {
        id: readEqProc
        command: ["/bin/bash", "-lc", "if [ -f \"" + backend.configDir + "/quickshell/eq/parametric-eq.txt\" ]; then cat \"" + backend.configDir + "/quickshell/eq/parametric-eq.txt\"; fi"]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { readEqProc.out += data + "\n"; } }
        onExited: {
            backend.parseEqState(readEqProc.out);
            readEqProc.out = "";
        }
    }

    onCurrentSinkNameChanged: {
        if (currentSinkName.length === 0 || currentSinkName === "effect_input.eq") return;
        if (lastAppliedTargetSink.length === 0) {
            lastAppliedTargetSink = currentSinkName;
            return;
        }
        if (currentSinkName === lastAppliedTargetSink) return;
        pendingAutoTargetSink = currentSinkName;
        autoApplyTimer.restart();
    }

    Timer {
        id: autoApplyTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (backend.pendingAutoTargetSink.length === 0) return;
            if (backend.pendingAutoTargetSink !== backend.currentSinkName) return;
            backend.autoApplyForCurrentSink();
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 1200
        repeat: false
        onTriggered: backend.scheduleRefresh(50)
    }

    Timer {
        id: routeRecoveryTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (!recoverProc.running) recoverProc.running = true;
            backend.scheduleRefresh(100);
        }
    }

    Timer {
        id: startupRecoverTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!recoverProc.running) recoverProc.running = true;
            backend.scheduleRefresh(100);
            Volume.pulseOsd();
        }
    }

    Timer {
        id: refreshDebounce
        interval: 120
        repeat: false
        onTriggered: backend.refreshAudioInfo()
    }

    Timer {
        id: bandPreviewTimer
        interval: 240
        repeat: false
        onTriggered: {}
    }

    function sameBands(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++) {
            if (Math.round(Number(a[i])) !== Math.round(Number(b[i]))) return false;
        }
        return true;
    }

    function detectPresetFromBands(arr) {
        var keys = backend.presetNames;
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            if (backend.sameBands(arr, presetMap[key])) return key;
        }
        return "Custom";
    }

    function formatSinkLabel(name) {
        return name.replace(/^alsa_output\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
    }

    function queueEqApply(immediate) {
        if (hydratingEqState) return;
        pendingEqBandsSnapshot = eqBands.slice();
        pendingEqApply = true;
        if (eqProc.running) return;
        if (immediate === true) {
            pendingEqApply = false;
            applyToPipeWire(pendingEqBandsSnapshot);
            return;
        }
    }

    onEqBandsChanged: {
        updatePendingEqState();
        if (!hydratingEqState && hasPendingEqChanges) {
            applyStatus = "Unapplied changes";
        }
    }

    function applyPreset(name) {
        if (!presetMap[name]) return;
        selectedPreset = name;
        eqBands = presetMap[name].slice();
        queueEqApply(true);
    }

    function setBandFromY(idx, y, h) {
        var ratio = 1 - Math.min(Math.max(y / h, 0), 1);
        var arr = eqBands.slice();
        arr[idx] = Math.round((ratio * 24) - 12);
        eqBands = arr;
        selectedPreset = "Custom";
        pendingEqBandsSnapshot = arr.slice();
        applyStatus = "Unapplied changes";
    }

    function beginBandDrag() {
        bandDragActive = true;
    }

    function commitBandDrag() {
        bandDragActive = false;
        if (!hasPendingEqChanges) return;
        if (eqProc.running) {
            pendingEqApply = true;
            applyStatus = "Applying...";
            return;
        }
        queueEqApply(true);
    }

    function applyEqToTarget(targetSink, bands) {
        if (eqProc.running) return;
        applyStatus = targetSink === "auto" ? "Applying..." : "Switching output...";
        eqProc.requestedTargetSink = targetSink;
        eqProc.requestedAction = "apply";
        var gains = (bands && bands.length === 10) ? bands : eqBands;
        eqProc.requestedBandsSnapshot = gains.slice();
        startManagedProcess(eqProc, [
            "/bin/bash", eqScriptPath, "apply",
            String(gains[0]), String(gains[1]), String(gains[2]), String(gains[3]), String(gains[4]),
            String(gains[5]), String(gains[6]), String(gains[7]), String(gains[8]), String(gains[9]),
            targetSink
        ]);
    }

    function applyToPipeWire(bands) {
        var targetSink = "auto";
        if (currentSinkName.length > 0 && currentSinkName !== "effect_input.eq") targetSink = currentSinkName;
        applyEqToTarget(targetSink, bands);
    }

    function autoApplyForCurrentSink() {
        if (currentSinkName.length === 0 || currentSinkName === "effect_input.eq") return;
        if (eqProc.running) return;
        applyStatus = "Syncing output...";
        eqProc.requestedTargetSink = currentSinkName;
        eqProc.requestedAction = "switch";
        eqProc.requestedBandsSnapshot = null;
        startManagedProcess(eqProc, ["/bin/bash", eqScriptPath, "switch", currentSinkName]);
    }

    function disablePipeWireEq() {
        if (eqProc.running) return;
        applyStatus = "Disabling...";
        eqProc.requestedAction = "disable";
        eqProc.requestedTargetSink = "";
        eqProc.requestedBandsSnapshot = null;
        startManagedProcess(eqProc, ["/bin/bash", eqScriptPath, "disable"]);
    }

    function refreshAudioInfo() {
        startManagedProcess(audioInfoProc);
        refreshSinkList();
    }

    function refreshSinkList() {
        startManagedProcess(sinkListProc);
    }

    function selectOutputSink(sinkName) {
        if (!sinkName || sinkName.length === 0 || eqProc.running) return;
        applyStatus = "Switching output...";
        eqProc.requestedTargetSink = sinkName;
        eqProc.requestedAction = "switch";
        eqProc.requestedBandsSnapshot = null;
        startManagedProcess(eqProc, ["/bin/bash", eqScriptPath, "switch", sinkName]);
    }

    function applyPendingBands() {
        if (eqProc.running || !hasPendingEqChanges) return;
        queueEqApply(true);
    }

    function loadEqStateFromFile() {
        startManagedProcess(readEqProc);
    }

    function syncSinkControlsFromVolume() {
        sinkVolumePercent = Math.max(0, Math.min(150, Math.round((Volume.sinkVolume || 0) * 100)));
        sinkMuted = Volume.sinkMuted;
    }

    function setSinkVolumePercent(percent) {
        var p = Math.max(0, Math.min(150, Math.round(percent)));
        Volume.setSinkVolume(p / 100.0);
        sinkVolumePercent = p;
        scheduleRefresh(100);
    }

    function setSourceVolumePercent(percent) {
        var p = Math.max(0, Math.min(100, Math.round(percent)));
        var srcArg = (currentSourceName.length > 0 ? currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-volume", srcArg, String(p) + "%"]);
        sourceVolumePercent = p;
        scheduleRefresh(100);
    }

    function toggleSinkMute() {
        Volume.toggleSinkMute();
        scheduleRefresh(100);
    }

    function toggleSourceMute() {
        var srcArg = (currentSourceName.length > 0 ? currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-mute", srcArg, "toggle"]);
        scheduleRefresh(100);
    }

    Connections {
        target: Volume

        function onRefreshSerialChanged() {
            backend.syncSinkControlsFromVolume();
            backend.scheduleRefresh(80);
        }

        function onSinkVolumeChanged() {
            backend.syncSinkControlsFromVolume();
        }

        function onSinkMutedChanged() {
            backend.syncSinkControlsFromVolume();
        }
    }

    Component.onCompleted: {
        syncSinkControlsFromVolume();
        loadEqStateFromFile();
        scheduleRefresh(0);
        startupEqCheckProc.running = true;
    }
}
