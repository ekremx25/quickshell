import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../../Widgets"
import "../../../Services"

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 34
    radius: 17
    color: popupWindow.visible ? root.eqChipFillActive : root.eqChipFill
    border.width: root.useNeutralEqChip ? 1 : 0
    border.color: popupWindow.visible ? root.eqChipBorderActive : root.eqChipBorder

    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    property var currentPlayer: null
    property bool hasMedia: currentPlayer !== null
    property bool isPlaying: currentPlayer ? currentPlayer.isPlaying : false

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
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string eqScriptPath: configDir + "/quickshell/scripts/eq_filter_chain.sh"
    readonly property string eqPipewireConfPath: configDir + "/pipewire/pipewire.conf.d/90-quickshell-eq.conf"
    readonly property real bgLuma: (Theme.background.r * 0.299) + (Theme.background.g * 0.587) + (Theme.background.b * 0.114)
    readonly property color eqAccent: Theme.equalizerColor
    readonly property real eqAccentLuma: (eqAccent.r * 0.299) + (eqAccent.g * 0.587) + (eqAccent.b * 0.114)
    readonly property bool useNeutralEqChip: uiIsLight && eqAccentLuma < 0.25
    readonly property color eqChipFill: useNeutralEqChip ? Theme.surface : eqAccent
    readonly property color eqChipFillActive: useNeutralEqChip ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98) : eqAccent
    readonly property color eqChipBorder: useNeutralEqChip ? Qt.rgba(15/255, 23/255, 42/255, 0.24) : "transparent"
    readonly property color eqChipBorderActive: useNeutralEqChip ? Qt.rgba(15/255, 23/255, 42/255, 0.30) : "transparent"
    readonly property real eqChipLuma: (eqChipFill.r * 0.299) + (eqChipFill.g * 0.587) + (eqChipFill.b * 0.114)
    readonly property color chipTextColor: eqChipLuma > 0.62 ? "#0b1220" : "#f8fafc"
    readonly property color eqAccentSoft: useNeutralEqChip ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92) : Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.26)
    readonly property color eqAccentStrong: useNeutralEqChip ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98) : Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.40)
    readonly property color eqAccentBorder: useNeutralEqChip ? Qt.rgba(15/255, 23/255, 42/255, 0.24) : Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.62)
    readonly property color eqAccentDim: useNeutralEqChip ? Qt.rgba(15/255, 23/255, 42/255, 0.08) : Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.28)
    readonly property color eqAccentButton: useNeutralEqChip ? Qt.rgba(15/255, 23/255, 42/255, 0.12) : Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.32)
    readonly property real primaryLuma: (eqAccent.r * 0.299) + (eqAccent.g * 0.587) + (eqAccent.b * 0.114)
    readonly property bool uiIsLight: bgLuma > 0.62
    readonly property color adaptiveText: uiIsLight ? "#0f172a" : Theme.text
    readonly property color adaptiveSubtext: uiIsLight ? "#475569" : Theme.subtext
    readonly property color adaptiveAccentText: uiIsLight ? "#0f172a" : root.eqAccent
    readonly property color adaptiveOnPrimary: primaryLuma > 0.62 ? "#0b1220" : "#f8fafc"
    readonly property color sinkAccent: uiIsLight ? "#0f766e" : "#a6e3a1"
    readonly property color sourceAccent: uiIsLight ? "#0369a1" : "#94e2d5"

    readonly property var presetMap: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [5, 4, 3, 2, 1, 0, -2, -3, -4, -5],
        "Treble":  [-4, -3, -2, -1, 0, 1, 2, 3, 4, 5],
        "Vocal":   [-2, -1, 1, 3, 4, 3, 1, -1, -2, -3],
        "Pop":     [-1, 1, 3, 4, 2, 0, -1, 1, 3, 4],
        "Rock":    [3, 2, 1, 0, -1, 1, 3, 4, 3, 2],
        "Jazz":    [2, 1, 0, 2, 3, 2, 1, 0, 1, 2],
        "Classic": [1, 2, 3, 1, -1, -1, 0, 1, 2, 3]
    })

    PwObjectTracker { objects: [ root.defaultSink, root.defaultSource ] }

    Instantiator {
        id: playerTracker
        model: Mpris.players

        delegate: QtObject {
            property var player: modelData
            property Connections conn: Connections {
                target: player
                function onIsPlayingChanged() { root.checkPlayers(); }
            }
        }

        onObjectAdded: root.checkPlayers()
        onObjectRemoved: root.checkPlayers()
    }

    Process {
        id: eqProc
        command: []
        running: false
        property string out: ""
        property string requestedTargetSink: "auto"
        stdout: SplitParser { onRead: data => { eqProc.out += data + "\n"; } }
        stderr: SplitParser { onRead: data => { eqProc.out += data + "\n"; } }
        onExited: (code) => {
            if (code === 0) {
                root.applyStatus = "Applied";
                if (eqProc.requestedTargetSink.length > 0 && eqProc.requestedTargetSink !== "auto") {
                    root.lastAppliedTargetSink = eqProc.requestedTargetSink;
                }
            } else {
                var errText = eqProc.out.trim();
                if (errText.length > 80) errText = errText.substring(0, 80) + "...";
                root.applyStatus = errText.length > 0 ? ("Error (" + code + "): " + errText) : ("Error (" + code + ")");
            }
            root.refreshAudioInfo();
            delayedRefreshTimer.restart();
            routeRecoveryTimer.restart();
            Volume.pulseOsd();
            eqProc.out = "";
        }
    }

    Process {
        id: recoverProc
        command: ["/bin/bash", root.eqScriptPath, "recover"]
        running: false
    }

    Process {
        id: startupEqCheckProc
        command: ["/usr/bin/test", "-f", root.eqPipewireConfPath]
        running: false
        onExited: (code) => {
            if (code === 0) {
                startupRecoverTimer.restart();
            }
        }
    }

    Process {
        id: audioInfoProc
        command: ["/bin/bash", "-lc", "STATE_FILE=\"" + root.configDir + "/../.local/state/quickshell/eq_filter_chain.state\"; DEFAULT_SINK=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Sink:/{print $2; exit}'); RUNNING_SINK=$(/usr/bin/pactl list short sinks | /usr/bin/awk '$5 == \"RUNNING\" {print $2}' | /usr/bin/grep -v '^effect_input\\.eq$' | /usr/bin/head -n1); STATE_SINK=''; if [ -f \"$STATE_FILE\" ]; then STATE_SINK=$(/usr/bin/awk -F'=' '/^BASE_SINK=/{print $2; exit}' \"$STATE_FILE\"); fi; S=\"$DEFAULT_SINK\"; if [ \"$DEFAULT_SINK\" = \"effect_input.eq\" ]; then if [ -n \"$RUNNING_SINK\" ]; then S=\"$RUNNING_SINK\"; elif [ -n \"$STATE_SINK\" ]; then S=\"$STATE_SINK\"; fi; fi; SR=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Source:/{print $2; exit}'); SV=$(/usr/bin/pactl get-sink-volume \"$S\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SM=$(/usr/bin/pactl get-sink-mute \"$S\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); SRV=$(/usr/bin/pactl get-source-volume \"$SR\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SRM=$(/usr/bin/pactl get-source-mute \"$SR\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); echo \"SINK=$S\"; echo \"SOURCE=$SR\"; echo \"SINKVOL=$SV\"; echo \"SINKMUTE=$SM\"; echo \"SOURCEVOL=$SRV\"; echo \"SOURCEMUTE=$SRM\""]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { audioInfoProc.out += data + "\n"; } }
        onExited: {
            var lines = audioInfoProc.out.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim();
                if (l.length === 0) continue;
                if (l.indexOf("SINK=") === 0) {
                    var s = l.substring(5);
                    if (s.length > 0) {
                        root.currentSinkName = s;
                        root.sinkDisplayName = s.replace(/^alsa_output\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
                        if (root.lastAppliedTargetSink.length === 0) {
                            root.lastAppliedTargetSink = s;
                        }
                    }
                } else if (l.indexOf("SOURCE=") === 0) {
                    var src = l.substring(7);
                    if (src.length > 0) {
                        root.currentSourceName = src;
                        root.sourceDisplayName = src.replace(/^alsa_input\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
                    }
                } else if (l.indexOf("SINKVOL=") === 0) {
                    root.sinkVolumePercent = parseInt(l.substring(8)) || 0;
                } else if (l.indexOf("SINKMUTE=") === 0) {
                    root.sinkMuted = (l.substring(9).trim() === "yes");
                } else if (l.indexOf("SOURCEVOL=") === 0) {
                    root.sourceVolumePercent = parseInt(l.substring(10)) || 0;
                } else if (l.indexOf("SOURCEMUTE=") === 0) {
                    root.sourceMuted = (l.substring(11).trim() === "yes");
                }
            }
            audioInfoProc.out = "";
        }
    }

    function checkPlayers() {
        var count = playerTracker.count;
        var active = null;

        for (var i = 0; i < count; i++) {
            var wrapper = playerTracker.objectAt(i);
            if (!wrapper) continue;
            var p = wrapper.player;
            if (!p) continue;

            if (p.isPlaying) {
                active = p;
                break;
            }
            if (!active) active = p;
        }
        root.currentPlayer = active;
    }

    function applyPreset(name) {
        if (!presetMap[name]) return;
        selectedPreset = name;
        eqBands = presetMap[name].slice();
    }

    function sameBands(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++) {
            if (Math.round(Number(a[i])) !== Math.round(Number(b[i]))) return false;
        }
        return true;
    }

    function detectPresetFromBands(arr) {
        var keys = ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"];
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            var p = presetMap[key];
            if (sameBands(arr, p)) return key;
        }
        return "Custom";
    }

    function setBandFromY(idx, y, h) {
        var r = 1 - Math.min(Math.max(y / h, 0), 1);
        var db = Math.round((r * 24) - 12);
        var arr = eqBands.slice();
        arr[idx] = db;
        eqBands = arr;
        selectedPreset = "Custom";
    }

    function applyToPipeWire() {
        if (eqProc.running) return;
        root.applyStatus = "Applying...";
        var targetSink = "auto";
        if (root.currentSinkName.length > 0 && root.currentSinkName !== "effect_input.eq") {
            targetSink = root.currentSinkName;
        }
        eqProc.requestedTargetSink = targetSink;
        eqProc.command = [
            "/bin/bash", root.eqScriptPath, "apply",
            String(eqBands[0]), String(eqBands[1]), String(eqBands[2]), String(eqBands[3]), String(eqBands[4]),
            String(eqBands[5]), String(eqBands[6]), String(eqBands[7]), String(eqBands[8]), String(eqBands[9]),
            targetSink
        ];
        eqProc.running = true;
    }

    function autoApplyForCurrentSink() {
        if (eqProc.running) return;
        if (root.currentSinkName.length === 0) return;
        if (root.currentSinkName === "effect_input.eq") return;
        eqProc.requestedTargetSink = root.currentSinkName;
        root.applyStatus = "Auto-applying...";
        eqProc.command = [
            "/bin/bash", root.eqScriptPath, "apply",
            String(eqBands[0]), String(eqBands[1]), String(eqBands[2]), String(eqBands[3]), String(eqBands[4]),
            String(eqBands[5]), String(eqBands[6]), String(eqBands[7]), String(eqBands[8]), String(eqBands[9]),
            root.currentSinkName
        ];
        eqProc.running = true;
    }

    onCurrentSinkNameChanged: {
        if (currentSinkName.length === 0) return;
        if (currentSinkName === "effect_input.eq") return;
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
            if (root.pendingAutoTargetSink.length === 0) return;
            if (root.pendingAutoTargetSink !== root.currentSinkName) return;
            root.autoApplyForCurrentSink();
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 1200
        repeat: false
        onTriggered: root.refreshAudioInfo()
    }

    Timer {
        id: routeRecoveryTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (!recoverProc.running) {
                recoverProc.running = true;
            }
            root.refreshAudioInfo();
        }
    }

    Timer {
        id: startupRecoverTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!recoverProc.running) {
                recoverProc.running = true;
            }
            root.refreshAudioInfo();
            Volume.pulseOsd();
        }
    }

    function disablePipeWireEq() {
        if (eqProc.running) return;
        root.applyStatus = "Disabling...";
        eqProc.command = ["/bin/bash", root.eqScriptPath, "disable"];
        eqProc.running = true;
    }

    function refreshAudioInfo() {
        if (audioInfoProc.running) return;
        audioInfoProc.out = "";
        audioInfoProc.running = true;
    }

    Process {
        id: readEqProc
        command: ["/bin/bash", "-lc", "if [ -f \"" + root.configDir + "/quickshell/eq/parametric-eq.txt\" ]; then cat \"" + root.configDir + "/quickshell/eq/parametric-eq.txt\"; fi"]
        running: false
        property string out: ""
        stdout: SplitParser { onRead: data => { readEqProc.out += data + "\n"; } }
        onExited: {
            var lines = readEqProc.out.split("\n");
            var gains = [];
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                var m = line.match(/Gain\s+(-?\d+(?:\.\d+)?)\s+dB/i);
                if (m && m.length > 1) gains.push(parseFloat(m[1]));
            }
            if (gains.length === 10) {
                root.eqBands = gains;
                root.selectedPreset = root.detectPresetFromBands(gains);
            }
            readEqProc.out = "";
        }
    }

    function loadEqStateFromFile() {
        if (readEqProc.running) return;
        readEqProc.out = "";
        readEqProc.running = true;
    }

    function physicalSinkArg() {
        if (root.currentSinkName.length > 0 && root.currentSinkName !== "effect_input.eq") {
            return root.currentSinkName;
        }
        if (root.pendingAutoTargetSink.length > 0 && root.pendingAutoTargetSink !== "effect_input.eq") {
            return root.pendingAutoTargetSink;
        }
        if (root.lastAppliedTargetSink.length > 0 && root.lastAppliedTargetSink !== "effect_input.eq") {
            return root.lastAppliedTargetSink;
        }
        return "@DEFAULT_SINK@";
    }

    function setSinkVolumePercent(percent) {
        var p = Math.max(0, Math.min(150, Math.round(percent)));
        var sinkArg = root.physicalSinkArg();
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", sinkArg, String(p) + "%"]);
        root.sinkVolumePercent = p;
        Qt.callLater(root.refreshAudioInfo);
    }

    function setSourceVolumePercent(percent) {
        var p = Math.max(0, Math.min(100, Math.round(percent)));
        var srcArg = (root.currentSourceName.length > 0 ? root.currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-volume", srcArg, String(p) + "%"]);
        root.sourceVolumePercent = p;
        Qt.callLater(root.refreshAudioInfo);
    }

    function toggleSinkMute() {
        var sinkArg = root.physicalSinkArg();
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", sinkArg, "toggle"]);
        Qt.callLater(root.refreshAudioInfo);
    }

    function toggleSourceMute() {
        var srcArg = (root.currentSourceName.length > 0 ? root.currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-mute", srcArg, "toggle"]);
        Qt.callLater(root.refreshAudioInfo);
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰕾"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: root.chipTextColor
        }

        Text {
            text: "EQ"
            font.bold: true
            font.pixelSize: 12
            color: root.chipTextColor
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (!popupWindow.visible) popupWindow.visible = true
        }
    }

    Window {
        id: popupWindow
        visible: false
        property real overlayAlpha: 0.0
        property real panelTopOffset: 0
        width: Screen.width
        height: Screen.height
        x: 0
        y: 0
        color: Qt.rgba(0, 0, 0, overlayAlpha)
        flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        onVisibleChanged: {
            if (visible) {
                panel.opacity = 0
                panel.scale = 0.985
                contentColumn.opacity = 0
                contentColumn.y = 10
                popupWindow.overlayAlpha = 0.0
                popupWindow.panelTopOffset = -120
                openAnim.stop()
                closeAnim.stop()
                openAnim.start()
                root.refreshAudioInfo()
                root.loadEqStateFromFile()
            }
        }

        Rectangle {
            id: panel
            width: 480
            height: 730
            radius: 16
            opacity: 0
            scale: 1.0
            transformOrigin: Item.TopRight
            transform: Translate { y: popupWindow.panelTopOffset }
            color: Theme.background
            border.width: 1
            border.color: Theme.surface
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 62
            anchors.rightMargin: 14

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                opacity: 0
                y: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Audio Control"; color: root.adaptiveText; font.bold: true; font.pixelSize: 18 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: Qt.rgba(255,255,255,0.08)
                        Text { anchors.centerIn: parent; text: "✕"; color: root.adaptiveText; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!closeAnim.running) {
                                    openAnim.stop()
                                    closeAnim.start()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 145
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.06)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 52
                                height: 52
                                radius: 10
                                color: root.eqAccentSoft
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.currentPlayer ? root.currentPlayer.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !parent.children[0].visible
                                    text: "󰎆"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: root.adaptiveAccentText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: root.currentPlayer ? (root.currentPlayer.trackTitle || "Unknown Track") : "No media playing"
                                    color: root.adaptiveText
                                    font.bold: true
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.currentPlayer ? (root.currentPlayer.trackArtist || "Unknown Artist") : "Open Spotify / Browser / Player"
                                    color: root.adaptiveSubtext
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 14

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: prevMA.containsMouse ? Qt.rgba(255,255,255,0.10) : "transparent"
                                Text { anchors.centerIn: parent; text: "󰒮"; font.family: "JetBrainsMono Nerd Font"; color: root.adaptiveText; font.pixelSize: 13 }
                                MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.previous() }
                            }

                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: root.eqAccent
                                Text { anchors.centerIn: parent; text: root.isPlaying ? "⏸" : "⏵"; color: root.adaptiveOnPrimary; font.pixelSize: 16; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.togglePlaying() }
                            }

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: nextMA.containsMouse ? Qt.rgba(255,255,255,0.10) : "transparent"
                                Text { anchors.centerIn: parent; text: "󰒭"; font.family: "JetBrainsMono Nerd Font"; color: root.adaptiveText; font.pixelSize: 13 }
                                MouseArea { id: nextMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.next() }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 290
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(255,255,255,0.06)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Equalizer"; color: root.adaptiveText; font.bold: true; font.pixelSize: 15 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                radius: 8
                                color: root.eqAccentDim
                                border.color: root.eqAccent
                                border.width: 1
                                implicitWidth: presetLabel.implicitWidth + 14
                                implicitHeight: 28
                                Text {
                                    id: presetLabel
                                    anchors.centerIn: parent
                                    text: root.selectedPreset
                                    color: root.adaptiveAccentText
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            spacing: 8

                            Repeater {
                                model: root.eqFrequencies
                                delegate: ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 22
                                        height: 104

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 6
                                            height: parent.height
                                            radius: 3
                                            color: Qt.rgba(255, 255, 255, 0.09)
                                        }

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: root.sourceAccent
                                            y: {
                                                var db = root.eqBands[index];
                                                var ratio = (db + 12) / 24.0;
                                                return (1 - ratio) * (parent.height - height);
                                            }
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            border.width: 1
                                            border.color: Qt.rgba(255,255,255,0.3)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: (mouse) => root.setBandFromY(index, mouse.y, height)
                                            onPositionChanged: (mouse) => { if (pressed) root.setBandFromY(index, mouse.y, height); }
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData
                                        color: root.adaptiveSubtext
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 8

                            Repeater {
                                model: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 9
                                    color: root.selectedPreset === modelData ? root.eqAccentDim : Qt.rgba(255,255,255,0.05)
                                    border.width: 1
                                    border.color: root.selectedPreset === modelData ? root.eqAccent : Qt.rgba(255,255,255,0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.selectedPreset === modelData ? root.adaptiveAccentText : root.adaptiveText
                                        font.pixelSize: 12
                                        font.bold: root.selectedPreset === modelData
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyPreset(modelData)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 9
                                color: root.eqAccentButton
                                border.width: 1
                                border.color: root.eqAccent
                                Text { anchors.centerIn: parent; text: eqProc.running ? "Applying..." : "Apply EQ"; color: root.adaptiveAccentText; font.bold: true; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; enabled: !eqProc.running; cursorShape: Qt.PointingHandCursor; onClicked: root.applyToPipeWire() }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 9
                                color: Qt.rgba(243/255,139/255,168/255,0.2)
                                border.width: 1
                                border.color: Theme.red
                                Text { anchors.centerIn: parent; text: "Disable"; color: Theme.red; font.bold: true; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; enabled: !eqProc.running; cursorShape: Qt.PointingHandCursor; onClicked: root.disablePipeWireEq() }
                            }
                        }

                        Text {
                            text: "Status: " + root.applyStatus
                            color: root.adaptiveSubtext
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 88
                    radius: 10
                    color: Theme.surface
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "󰓃"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: root.sinkAccent }
                            Text {
                                Layout.fillWidth: true
                                text: root.sinkDisplayName
                                color: root.adaptiveText
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.sinkVolumePercent + "%"
                                color: root.adaptiveAccentText
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: root.sinkMuted ? Qt.rgba(243/255,139/255,168/255,0.2) : Qt.rgba(166/255,227/255,161/255,0.14)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.sinkMuted ? "󰝟" : "󰕾"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: root.sinkMuted ? "#f38ba8" : root.sinkAccent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSinkMute()
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                Rectangle {
                                    width: parent.width * (Math.max(0, Math.min(root.sinkVolumePercent, 150)) / 150)
                                    height: parent.height
                                    radius: 3
                                    color: root.sinkAccent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function setVol(mouse) {
                                        if (width <= 0) return;
                                        var p = (mouse.x / width) * 150.0;
                                        root.setSinkVolumePercent(p);
                                    }
                                    onPressed: (mouse) => setVol(mouse)
                                    onPositionChanged: (mouse) => { if (pressed) setVol(mouse); }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 88
                    radius: 10
                    color: Theme.surface
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "󰍬"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: root.sourceAccent }
                            Text {
                                Layout.fillWidth: true
                                text: root.sourceDisplayName
                                color: root.adaptiveText
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.sourceVolumePercent + "%"
                                color: root.sourceAccent
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: root.sourceMuted ? Qt.rgba(243/255,139/255,168/255,0.2) : Qt.rgba(148/255,226/255,213/255,0.14)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.sourceMuted ? "󰍭" : "󰍬"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: root.sourceMuted ? "#f38ba8" : root.sourceAccent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSourceMute()
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                Rectangle {
                                    width: parent.width * (Math.max(0, Math.min(root.sourceVolumePercent, 100)) / 100)
                                    height: parent.height
                                    radius: 3
                                    color: root.sourceAccent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function setMic(mouse) {
                                        if (width <= 0) return;
                                        var p = (mouse.x / width) * 100.0;
                                        root.setSourceVolumePercent(p);
                                    }
                                    onPressed: (mouse) => setMic(mouse)
                                    onPositionChanged: (mouse) => { if (pressed) setMic(mouse); }
                                }
                            }
                        }
                    }
                }
            }
        }

        ParallelAnimation {
            id: openAnim
            running: false
            NumberAnimation { target: popupWindow; property: "overlayAlpha"; from: 0.0; to: 0.38; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; from: 0.985; to: 1; duration: 220; easing.type: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: popupWindow; property: "panelTopOffset"; from: -120; to: 12; duration: 230; easing.type: Easing.OutCubic }
                NumberAnimation { target: popupWindow; property: "panelTopOffset"; from: 12; to: 0; duration: 110; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                ParallelAnimation {
                    NumberAnimation { target: contentColumn; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: contentColumn; property: "y"; from: 10; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }

        ParallelAnimation {
            id: closeAnim
            running: false
            NumberAnimation { target: popupWindow; property: "overlayAlpha"; from: popupWindow.overlayAlpha; to: 0.0; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "opacity"; from: panel.opacity; to: 0; duration: 130; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "scale"; from: panel.scale; to: 0.985; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: popupWindow; property: "panelTopOffset"; from: popupWindow.panelTopOffset; to: -120; duration: 130; easing.type: Easing.InCubic }
            NumberAnimation { target: contentColumn; property: "opacity"; from: contentColumn.opacity; to: 0; duration: 90; easing.type: Easing.InCubic }
            NumberAnimation { target: contentColumn; property: "y"; from: contentColumn.y; to: 8; duration: 90; easing.type: Easing.InCubic }
            onFinished: popupWindow.visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!closeAnim.running) {
                    openAnim.stop()
                    closeAnim.start()
                }
            }
            z: -1
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAudioInfo()
    }

    Component.onCompleted: {
        root.loadEqStateFromFile();
        root.refreshAudioInfo();
        startupEqCheckProc.running = true;
    }
}
