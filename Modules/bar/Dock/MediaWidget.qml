import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../../Widgets"

Rectangle {
    id: mediaWidget

    // --- Configuration ---
    required property real dockScale

    // --- State ---
    property var currentPlayer: null
    property bool hasMedia: currentPlayer !== null
    property bool isPlaying: currentPlayer ? currentPlayer.isPlaying : false
    property bool expanded: true
    readonly property string currentTitle: currentPlayer ? (currentPlayer.trackTitle || "Unknown") : ""
    readonly property string currentArtist: currentPlayer ? (currentPlayer.trackArtist || "Unknown") : ""
    readonly property string trackArtSource: currentPlayer ? currentPlayer.trackArtUrl : ""
    readonly property real bgLuma: (mediaWidget.color.r * 0.299) + (mediaWidget.color.g * 0.587) + (mediaWidget.color.b * 0.114)
    readonly property real primaryLuma: (Theme.primary.r * 0.299) + (Theme.primary.g * 0.587) + (Theme.primary.b * 0.114)
    readonly property bool uiIsLight: bgLuma > 0.55
    readonly property color adaptiveText: uiIsLight ? "#0f172a" : "#e2e8f0"
    readonly property color adaptiveSubtext: uiIsLight ? "#475569" : "#94a3b8"
    readonly property color adaptiveOnPrimary: primaryLuma > 0.62 ? "#0b1220" : "#f8fafc"

    component MediaControlButton: Rectangle {
        required property string iconText
        required property var onActivate
        property bool hoverAccent: false
        property bool primaryButton: false
        property bool activeState: false
        property real buttonSize: 28 * dockScale

        Layout.preferredWidth: buttonSize
        Layout.preferredHeight: buttonSize
        radius: buttonSize / 2
        color: primaryButton
            ? Theme.primary
            : hoverAccent
                ? (buttonMouse.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.2) : Qt.rgba(137/255, 180/255, 250/255, 0.08))
                : (buttonMouse.containsMouse ? Qt.rgba(255,255,255,0.1) : "transparent")

        Text {
            anchors.centerIn: parent
            text: iconText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: (primaryButton ? 14 : 12) * dockScale
            color: primaryButton
                ? mediaWidget.adaptiveOnPrimary
                : activeState
                    ? mediaWidget.adaptiveText
                    : mediaWidget.adaptiveSubtext
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (onActivate) onActivate()
        }
    }

    // --- Instantiator: track Mpris players ---
    Instantiator {
        id: playerTracker
        model: Mpris.players

        delegate: QtObject {
            property var player: modelData
            
            property Connections conn: Connections {
                target: player
                function onIsPlayingChanged() { mediaWidget.checkPlayers(); }
            }
        }

        onObjectAdded: mediaWidget.checkPlayers()
        onObjectRemoved: mediaWidget.checkPlayers()
    }

    // --- Player detection logic ---
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

        mediaWidget.currentPlayer = active;
    }

    // --- Layout ---
    visible: true
    implicitWidth: mainRow.implicitWidth + (12 * dockScale)
    implicitHeight: 40 * dockScale
    radius: 12 * dockScale
    color: Qt.rgba(30/255, 30/255, 46/255, 0.65)
    border.color: Qt.rgba(137/255, 180/255, 250/255, 0.15)
    border.width: 1

    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        anchors.margins: 4 * dockScale
        spacing: 6 * dockScale

        // === Separator ===
        Rectangle {
            visible: mediaWidget.hasMedia
            Layout.preferredWidth: 1 * dockScale
            Layout.preferredHeight: 20 * dockScale
            color: Qt.rgba(147/255, 153/255, 178/255, 0.25)
        }

        // --- Idle State (No Music) ---
        RowLayout {
            id: idleLayout
            spacing: 8 * dockScale
            visible: !mediaWidget.hasMedia
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                width: 28 * dockScale
                height: 28 * dockScale
                radius: 14 * dockScale
                color: Qt.rgba(137/255, 180/255, 250/255, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14 * dockScale
                    color: mediaWidget.adaptiveSubtext
                }
            }

            Text {
                text: "No Music"
                color: mediaWidget.adaptiveSubtext
                font.bold: true
                font.pixelSize: 12 * dockScale
                verticalAlignment: Text.AlignVCenter
            }
        }

        // --- Active Content ---
        RowLayout {
            id: contentLayout
            spacing: 8 * dockScale
            visible: mediaWidget.hasMedia
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            // Album Art
            Rectangle {
                visible: mediaWidget.expanded
                Layout.preferredWidth: visible ? (38 * dockScale) : 0
                Layout.preferredHeight: 38 * dockScale
                radius: 10 * dockScale
                color: "transparent"
                clip: true
                opacity: mediaWidget.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Image {
                    anchors.fill: parent
                    source: mediaWidget.trackArtSource
                    fillMode: Image.PreserveAspectCrop
                    visible: source != ""
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(137/255, 180/255, 250/255, 0.2)
                    visible: !parent.children[0].visible

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16 * dockScale
                        color: Theme.primary
                    }
                }
            }

            // Info
            ColumnLayout {
                visible: mediaWidget.expanded
                Layout.fillWidth: true
                Layout.maximumWidth: visible ? (150 * dockScale) : 0
                spacing: 0
                opacity: mediaWidget.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    Layout.fillWidth: true
                    text: mediaWidget.currentTitle
                    color: mediaWidget.adaptiveText
                    font.bold: true
                    font.pixelSize: 12 * dockScale
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: mediaWidget.currentArtist
                    color: mediaWidget.adaptiveSubtext
                    font.pixelSize: 10 * dockScale
                    elide: Text.ElideRight
                }
            }

            // Controls
            RowLayout {
                spacing: 2 * dockScale

                MediaControlButton {
                    iconText: "󰒮"
                    activeState: true
                    onActivate: function() {
                        if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.previous();
                    }
                }

                MediaControlButton {
                    iconText: mediaWidget.isPlaying ? "⏸" : ""
                    primaryButton: true
                    buttonSize: 32 * dockScale
                    onActivate: function() {
                        if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.togglePlaying();
                    }
                }

                MediaControlButton {
                    iconText: "󰒭"
                    activeState: true
                    onActivate: function() {
                        if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.next();
                    }
                }

                MediaControlButton {
                    iconText: mediaWidget.expanded ? "󰅁" : "󰅀"
                    hoverAccent: true
                    activeState: mediaWidget.expanded
                    onActivate: function() {
                        mediaWidget.expanded = !mediaWidget.expanded;
                    }
                }
            }
        }
    }
}
