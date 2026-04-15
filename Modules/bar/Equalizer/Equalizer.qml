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

    // MetaChip and PresetChip component definitions moved to EqControlsCard.qml

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
                EqControlsCard {
                    Layout.fillWidth: true
                    eq: root
                    backend: backend
                }

                EqAudioDevices {
                    Layout.fillWidth: true
                    eq: root
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
