import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQml
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "."
import "../../../Widgets"

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 34
    radius: 17
    color: popupWindow.visible ? root.eqChipFillActive : root.eqChipFill
    border.width: root.useNeutralEqChip ? 1 : 0
    border.color: popupWindow.visible ? root.eqChipBorderActive : root.eqChipBorder

    property var currentPlayer: null
    property bool hasMedia: currentPlayer !== null
    property bool isPlaying: currentPlayer ? currentPlayer.isPlaying : false

    EqualizerBackend { id: backend }

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    property alias eqFrequencies: backend.eqFrequencies
    property alias eqBands: backend.eqBands
    property alias selectedPreset: backend.selectedPreset
    property alias applyStatus: backend.applyStatus
    property alias sinkDisplayName: backend.sinkDisplayName
    property alias sourceDisplayName: backend.sourceDisplayName
    property alias sinkVolumePercent: backend.sinkVolumePercent
    property alias sourceVolumePercent: backend.sourceVolumePercent
    property alias sinkMuted: backend.sinkMuted
    property alias sourceMuted: backend.sourceMuted
    property alias currentSinkName: backend.currentSinkName
    property alias currentSourceName: backend.currentSourceName
    property alias availableSinks: backend.availableSinks
    property alias hasPendingEqChanges: backend.hasPendingEqChanges
    readonly property alias presetNames: backend.presetNames
    readonly property bool eqIsBypassed: root.applyStatus === "Disabled" || root.applyStatus === "Disabling..."
    readonly property string eqModeLabel: root.eqIsBypassed ? "Bypassed" : (root.selectedPreset === "Custom" ? "Custom curve" : "Preset mode")
    readonly property string eqStateLabel: backend.isBusy ? "Applying" : (root.eqIsBypassed ? "Bypassed" : (root.hasPendingEqChanges ? "Pending" : "Live"))
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
    readonly property color glassPanel: Qt.rgba(28/255, 41/255, 56/255, 0.82)
    readonly property color glassCard: Qt.rgba(164/255, 226/255, 255/255, 0.09)
    readonly property color glassCardStrong: Qt.rgba(184/255, 239/255, 255/255, 0.14)
    readonly property color glassStroke: Qt.rgba(113/255, 229/255, 255/255, 0.24)
    readonly property color softText: "#eef6ff"
    readonly property color dimText: "#c5d8e8"
    readonly property color trackColor: Qt.rgba(210/255, 242/255, 255/255, 0.20)
    readonly property color waveGlowColor: Qt.rgba(153/255, 244/255, 255/255, 0.24)
    readonly property color waveLineColor: Qt.rgba(226/255, 255/255, 255/255, 0.86)
    readonly property color waveFillColor: Qt.rgba(130/255, 236/255, 255/255, 0.08)
    property real wavePhase: 0
    PwObjectTracker { objects: [ root.defaultSink, root.defaultSource ] }
    onDefaultSinkChanged: backend.scheduleRefresh(80)
    onDefaultSourceChanged: backend.scheduleRefresh(80)

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

    function applyPreset(name) { backend.applyPreset(name); }
    function setBandFromY(idx, y, h) { backend.setBandFromY(idx, y, h); }
    function applyToPipeWire() { backend.applyToPipeWire(); }
    function disablePipeWireEq() { backend.disablePipeWireEq(); }
    function applyPendingBands() { backend.applyPendingBands(); }
    function loadEqStateFromFile() { backend.loadEqStateFromFile(); }
    function setSinkVolumePercent(percent) { backend.setSinkVolumePercent(percent); }
    function setSourceVolumePercent(percent) { backend.setSourceVolumePercent(percent); }
    function toggleSinkMute() { backend.toggleSinkMute(); }
    function toggleSourceMute() { backend.toggleSourceMute(); }
    function selectOutputSink(sinkName) { backend.selectOutputSink(sinkName); }

    component MetaChip: Rectangle {
        required property string label
        property color fillColor: Qt.rgba(255,255,255,0.05)
        property color strokeColor: Qt.rgba(255,255,255,0.08)
        property color textColor: root.softText

        radius: 9
        color: fillColor
        border.width: 1
        border.color: strokeColor
        implicitWidth: metaChipText.implicitWidth + 16
        implicitHeight: 26

        Text {
            id: metaChipText
            anchors.centerIn: parent
            text: parent.label
            color: parent.textColor
            font.pixelSize: 10
            font.bold: true
        }
    }

    component PresetChip: Rectangle {
        required property string presetName

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 10
        color: root.selectedPreset === presetName
            ? Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.22)
            : Qt.rgba(255,255,255,0.035)
        border.width: 1
        border.color: root.selectedPreset === presetName
            ? Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.46)
            : Qt.rgba(255,255,255,0.06)

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            width: 5
            height: parent.height - 14
            radius: 2.5
            visible: root.selectedPreset === parent.presetName
            color: root.eqAccent
        }

        Text {
            anchors.centerIn: parent
            text: parent.presetName
            color: root.selectedPreset === parent.presetName ? root.softText : root.dimText
            font.pixelSize: 10
            font.bold: root.selectedPreset === parent.presetName
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPreset(parent.presetName)
        }
    }

    Timer {
        id: waveMotionTimer
        interval: 38
        repeat: true
        running: popupWindow.visible
        onTriggered: root.wavePhase += 0.18
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
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!popupWindow.visible) {
                popupWindow.visible = true
            } else if (!closeAnim.running) {
                openAnim.stop()
                closeAnim.start()
            }
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
                backend.scheduleRefresh(0)
                root.loadEqStateFromFile()
            }
        }

        Rectangle {
            id: panel
            width: 430
            height: Math.min(contentColumn.implicitHeight + 32, Screen.height - 72)
            radius: 24
            opacity: 0
            scale: 1.0
            transformOrigin: Item.TopRight
            transform: Translate { y: popupWindow.panelTopOffset }
            color: root.glassPanel
            border.width: 1
            border.color: Qt.rgba(115/255, 235/255, 255/255, 0.55)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 52
            anchors.rightMargin: 18

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(133/255, 224/255, 255/255, 0.12) }
                    GradientStop { position: 0.35; color: Qt.rgba(82/255, 146/255, 173/255, 0.10) }
                    GradientStop { position: 1.0; color: Qt.rgba(37/255, 61/255, 85/255, 0.08) }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Flickable {
                id: panelFlick
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contentColumn
                    width: panelFlick.width
                    spacing: 12
                    opacity: 0
                    y: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.40)

                            Text {
                                anchors.centerIn: parent
                                text: "EQ"
                                color: root.softText
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            spacing: 1

                            Text { text: "Sound Tuning"; color: root.softText; font.bold: true; font.pixelSize: 17 }
                            Text { text: root.selectedPreset + " profile"; color: root.dimText; font.pixelSize: 11 }
                        }

                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: Qt.rgba(255,255,255,0.08)
                            border.width: 1
                            border.color: root.glassStroke
                            Text { anchors.centerIn: parent; text: "✕"; color: root.softText; font.pixelSize: 12 }
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
                        implicitHeight: eqSectionLayout.implicitHeight + 28
                        radius: 18
                        color: root.glassCard
                        border.width: 1
                        border.color: root.glassStroke

                        ColumnLayout {
                            id: eqSectionLayout
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 62
                                    height: 62
                                    radius: 16
                                    color: root.glassCardStrong
                                    border.width: 1
                                    border.color: root.glassStroke
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
                                        font.pixelSize: 20
                                        color: root.softText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.currentPlayer ? (root.currentPlayer.trackTitle || "Unknown Track") : "No media playing"
                                        color: root.softText
                                        font.bold: true
                                        font.pixelSize: 15
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.currentPlayer ? (root.currentPlayer.trackArtist || "Unknown Artist") : "Open Spotify / Browser / Player"
                                        color: root.dimText
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.sinkDisplayName
                                        color: Qt.rgba(216/255, 225/255, 238/255, 0.72)
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 12

                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: prevMA.containsMouse ? Qt.rgba(255,255,255,0.12) : Qt.rgba(255,255,255,0.05)
                                    border.width: 1
                                    border.color: root.glassStroke
                                    Text { anchors.centerIn: parent; text: "󰒮"; font.family: "JetBrainsMono Nerd Font"; color: root.softText; font.pixelSize: 13 }
                                    MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.previous() }
                                }

                                Rectangle {
                                    width: 52; height: 52; radius: 26
                                    color: root.eqAccent
                                    border.width: 1
                                    border.color: Qt.rgba(255,255,255,0.18)
                                    Text { anchors.centerIn: parent; text: root.isPlaying ? "⏸" : "⏵"; color: root.adaptiveOnPrimary; font.pixelSize: 18; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.togglePlaying() }
                                }

                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: nextMA.containsMouse ? Qt.rgba(255,255,255,0.12) : Qt.rgba(255,255,255,0.05)
                                    border.width: 1
                                    border.color: root.glassStroke
                                    Text { anchors.centerIn: parent; text: "󰒭"; font.family: "JetBrainsMono Nerd Font"; color: root.softText; font.pixelSize: 13 }
                                    MouseArea { id: nextMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.currentPlayer) root.currentPlayer.next() }
                                }

                            }
                        }
                    }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: eqControlsLayout.implicitHeight + 28
                    radius: 18
                    color: root.glassCard
                    border.width: 1
                    border.color: root.glassStroke

                    ColumnLayout {
                        id: eqControlsLayout
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Equalizer"; color: root.softText; font.bold: true; font.pixelSize: 15 }
                            Text { text: "10-band"; color: root.dimText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 132
                            clip: false

                            Canvas {
                                id: eqWaveCanvas
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 8
                                anchors.bottomMargin: 28
                                z: 0

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    if (!root.eqBands || root.eqBands.length === 0) return;

                                    var anchors = [];
                                    for (var i = 0; i < root.eqBands.length; i++) {
                                        var anchorX = (width / Math.max(1, root.eqBands.length - 1)) * i;
                                        var anchorRatio = (root.eqBands[i] + 12) / 24.0;
                                        var anchorY = (1 - anchorRatio) * (height - 12) + 6;
                                        anchors.push({ x: anchorX, y: anchorY });
                                    }

                                    if (anchors.length < 2) return;

                                    var backSamples = [];
                                    var frontSamples = [];
                                    var sampleCount = Math.max(48, Math.floor(width / 6));
                                    for (var s = 0; s <= sampleCount; s++) {
                                        var t = s / sampleCount;
                                        var fx = t * width;
                                        var scaled = t * (anchors.length - 1);
                                        var left = Math.floor(scaled);
                                        var right = Math.min(anchors.length - 1, left + 1);
                                        var blend = scaled - left;
                                        var baseY = anchors[left].y * (1 - blend) + anchors[right].y * blend;
                                        var ampA = 1.15 + (Math.abs(root.eqBands[left]) * 0.22);
                                        var ampB = 1.15 + (Math.abs(root.eqBands[right]) * 0.22);
                                        var amp = ampA * (1 - blend) + ampB * blend;

                                        var backRipple = Math.sin((t * 7.0) + (root.wavePhase * 0.75)) * (amp * 0.95);
                                        backRipple += Math.sin((t * 17.0) - (root.wavePhase * 1.05)) * (amp * 0.18);
                                        backSamples.push({ x: fx, y: baseY + backRipple + 0.8 });

                                        var frontRipple = Math.sin((t * 8.4) + (root.wavePhase * 1.05)) * (amp * 0.88);
                                        frontRipple += Math.sin((t * 22.0) - (root.wavePhase * 1.55)) * (amp * 0.14);
                                        frontSamples.push({ x: fx, y: baseY + frontRipple });
                                    }

                                    var mist = ctx.createLinearGradient(0, height * 0.30, width, height * 0.68);
                                    mist.addColorStop(0.0, "rgba(180, 245, 245, 0.01)");
                                    mist.addColorStop(0.5, "rgba(180, 245, 245, 0.06)");
                                    mist.addColorStop(1.0, "rgba(180, 245, 245, 0.01)");
                                    ctx.fillStyle = mist;
                                    ctx.fillRect(0, height * 0.30, width, height * 0.30);

                                    ctx.beginPath();
                                    ctx.moveTo(backSamples[0].x, backSamples[0].y);
                                    for (var p = 1; p < backSamples.length; p++) {
                                        ctx.lineTo(backSamples[p].x, backSamples[p].y);
                                    }
                                    ctx.lineWidth = 6.5;
                                    ctx.strokeStyle = Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.10);
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.moveTo(frontSamples[0].x, frontSamples[0].y);
                                    for (var j = 1; j < frontSamples.length; j++) {
                                        ctx.lineTo(frontSamples[j].x, frontSamples[j].y);
                                    }
                                    ctx.lineWidth = 4.2;
                                    ctx.strokeStyle = root.waveGlowColor;
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.moveTo(frontSamples[0].x, frontSamples[0].y);
                                    for (var k = 1; k < frontSamples.length; k++) {
                                        ctx.lineTo(frontSamples[k].x, frontSamples[k].y);
                                    }
                                    ctx.lineWidth = 1.35;
                                    ctx.strokeStyle = root.waveLineColor;
                                    ctx.stroke();

                                    for (var a = 0; a < anchors.length; a++) {
                                        var softGrad = ctx.createRadialGradient(anchors[a].x, anchors[a].y, 0, anchors[a].x, anchors[a].y, 18);
                                        softGrad.addColorStop(0.0, "rgba(213, 255, 255, 0.08)");
                                        softGrad.addColorStop(1.0, "rgba(213, 255, 255, 0.00)");
                                        ctx.fillStyle = softGrad;
                                        ctx.beginPath();
                                        ctx.arc(anchors[a].x, anchors[a].y, 18, 0, Math.PI * 2);
                                        ctx.fill();
                                    }
                                }

                                Connections {
                                    target: root
                                    function onEqBandsChanged() { eqWaveCanvas.requestPaint(); }
                                    function onWavePhaseChanged() { eqWaveCanvas.requestPaint(); }
                                }

                                Component.onCompleted: requestPaint()
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 6
                                z: 1

                                Repeater {
                                    model: root.eqFrequencies
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 24
                                            height: 100

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 4
                                                height: parent.height
                                                radius: 2
                                                color: root.trackColor
                                            }

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 16
                                                height: 36
                                                radius: 8
                                                color: Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.92)
                                                y: {
                                                    var db = root.eqBands[index];
                                                    var ratio = (db + 12) / 24.0;
                                                    return (1 - ratio) * (parent.height - height);
                                                }
                                                border.width: 1
                                                border.color: Qt.rgba(255,255,255,0.35)
                                            }

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 20
                                                height: 20
                                                radius: 10
                                                y: {
                                                    var db2 = root.eqBands[index];
                                                    var ratio2 = (db2 + 12) / 24.0;
                                                    return (1 - ratio2) * (parent.height - height);
                                                }
                                                color: "#dff8ff"
                                                border.width: 1
                                                border.color: Qt.rgba(255,255,255,0.35)
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => {
                                                    backend.beginBandDrag()
                                                    root.setBandFromY(index, mouse.y, height)
                                                }
                                                onPositionChanged: (mouse) => { if (pressed) root.setBandFromY(index, mouse.y, height); }
                                                onReleased: backend.commitBandDrag()
                                                onCanceled: backend.commitBandDrag()
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData
                                            color: root.dimText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: 12
                                color: Qt.rgba(255,255,255,0.035)
                                border.width: 1
                                border.color: Qt.rgba(255,255,255,0.06)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    ColumnLayout {
                                        spacing: 1

                                        Text {
                                            text: "Sound Profiles"
                                            color: root.softText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Curated starting points for quick tuning."
                                            color: root.dimText
                                            font.pixelSize: 9
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MetaChip {
                                        label: root.eqModeLabel
                                        fillColor: Qt.rgba(255,255,255,0.045)
                                        strokeColor: Qt.rgba(255,255,255,0.08)
                                        textColor: root.softText
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: Math.min(5, root.presetNames.length)
                                    delegate: PresetChip {
                                        required property int index
                                        presetName: root.presetNames[index]
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: Math.max(0, root.presetNames.length - 5)
                                    delegate: PresetChip {
                                        required property int index
                                        presetName: root.presetNames[index + 5]
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 12
                            color: Qt.rgba(255,255,255,0.03)
                            border.width: 1
                            border.color: Qt.rgba(255,255,255,0.06)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                MetaChip {
                                    label: root.eqModeLabel
                                    fillColor: Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.14)
                                    strokeColor: Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.26)
                                    textColor: root.softText
                                }

                                MetaChip {
                                    label: root.eqStateLabel
                                    fillColor: backend.isBusy
                                        ? Qt.rgba(250/255, 204/255, 21/255, 0.16)
                                        : (root.eqIsBypassed
                                            ? Qt.rgba(243/255, 139/255, 168/255, 0.12)
                                            : Qt.rgba(255,255,255,0.045))
                                    strokeColor: backend.isBusy
                                        ? Qt.rgba(250/255, 204/255, 21/255, 0.26)
                                        : (root.eqIsBypassed
                                            ? Qt.rgba(243/255, 139/255, 168/255, 0.24)
                                            : Qt.rgba(255,255,255,0.08))
                                    textColor: root.softText
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    implicitWidth: disableEqText.implicitWidth + 28
                                    implicitHeight: 28
                                    radius: 9
                                    color: Qt.rgba(243/255,139/255,168/255,0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(243/255,139/255,168/255,0.26)

                                    Text {
                                        id: disableEqText
                                        anchors.centerIn: parent
                                        text: root.eqIsBypassed ? "EQ Bypassed" : "Bypass EQ"
                                        color: "#f7b4c5"
                                        font.bold: true
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !backend.isBusy && !root.eqIsBypassed
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.disablePipeWireEq()
                                    }
                                }
                            }
                        }

                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        height: 88
                        radius: 16
                        color: root.glassCard
                        border.width: 1
                        border.color: root.glassStroke
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "󰓃"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: root.sinkAccent }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.sinkDisplayName
                                    color: root.softText
                                    font.bold: true
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.sinkVolumePercent + "%"
                                    color: root.softText
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: root.sinkMuted ? Qt.rgba(243/255,139/255,168/255,0.18) : Qt.rgba(166/255,227/255,161/255,0.12)
                                    border.width: 1
                                    border.color: root.glassStroke
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.sinkMuted ? "󰝟" : "󰕾"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: root.sinkMuted ? "#f38ba8" : root.sinkAccent
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleSinkMute() }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 6
                                    radius: 3
                                    color: root.trackColor
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
                                        onPressed: function(mouse) { setVol(mouse); }
                                        onPositionChanged: function(mouse) { if (pressed) setVol(mouse); }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 88
                        radius: 16
                        color: root.glassCard
                        border.width: 1
                        border.color: root.glassStroke
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "󰍬"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: root.sourceAccent }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.sourceDisplayName
                                    color: root.softText
                                    font.bold: true
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.sourceVolumePercent + "%"
                                    color: root.softText
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: root.sourceMuted ? Qt.rgba(243/255,139/255,168/255,0.18) : Qt.rgba(148/255,226/255,213/255,0.12)
                                    border.width: 1
                                    border.color: root.glassStroke
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.sourceMuted ? "󰍭" : "󰍬"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: root.sourceMuted ? "#f38ba8" : root.sourceAccent
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleSourceMute() }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 6
                                    radius: 3
                                    color: root.trackColor
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
                                        onPressed: function(mouse) { setMic(mouse); }
                                        onPositionChanged: function(mouse) { if (pressed) setMic(mouse); }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 188
                    radius: 16
                    color: root.glassCard
                    border.width: 1
                    border.color: root.glassStroke

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰓃"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: root.sinkAccent }
                            Text {
                                text: "Output Devices"
                                color: root.softText
                                font.bold: true
                                font.pixelSize: 13
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: backend.isBusy ? "Applying..." : ""
                                color: root.dimText
                                font.pixelSize: 10
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: root.availableSinks

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 42
                                radius: 12
                                color: modelData.selected ? Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.16) : Qt.rgba(255,255,255,0.04)
                                border.width: 1
                                border.color: modelData.selected ? Qt.rgba(root.eqAccent.r, root.eqAccent.g, root.eqAccent.b, 0.38) : Qt.rgba(255,255,255,0.05)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: modelData.selected ? "󰓃" : "󰖁"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: modelData.selected ? root.sinkAccent : root.adaptiveSubtext
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: root.softText
                                            font.pixelSize: 11
                                            font.bold: modelData.selected
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: modelData.state.toLowerCase()
                                            color: root.dimText
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !backend.isBusy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectOutputSink(modelData.name)
                                }
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

}
