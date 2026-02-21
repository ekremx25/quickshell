import QtQuick
import QtQuick.Layouts
import QtQml
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
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
                    color: Theme.subtext
                }
            }

            Text {
                text: "No Music"
                color: Theme.overlay2
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
                    source: mediaWidget.currentPlayer ? mediaWidget.currentPlayer.trackArtUrl : ""
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
                    text: mediaWidget.currentPlayer ? (mediaWidget.currentPlayer.trackTitle || "Unknown") : ""
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: 12 * dockScale
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: mediaWidget.currentPlayer ? (mediaWidget.currentPlayer.trackArtist || "Unknown") : ""
                    color: Theme.subtext
                    font.pixelSize: 10 * dockScale
                    elide: Text.ElideRight
                }
            }

            // Controls
            RowLayout {
                spacing: 2 * dockScale

                // Prev
                Rectangle {
                    Layout.preferredWidth: 28 * dockScale
                    Layout.preferredHeight: 28 * dockScale
                    radius: 14 * dockScale
                    color: prevMouse.containsMouse ? Qt.rgba(255,255,255,0.1) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14 * dockScale
                        color: Theme.text
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.previous()
                    }
                }

                // Play/Pause
                Rectangle {
                    Layout.preferredWidth: 32 * dockScale
                    Layout.preferredHeight: 32 * dockScale
                    radius: 16 * dockScale
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: mediaWidget.isPlaying ? "⏸" : "⏵"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14 * dockScale
                        color: Theme.base
                    }

                    MouseArea {
                        id: ppMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.togglePlaying()
                    }
                }

                // Next
                Rectangle {
                    Layout.preferredWidth: 28 * dockScale
                    Layout.preferredHeight: 28 * dockScale
                    radius: 14 * dockScale
                    color: nextMouse.containsMouse ? Qt.rgba(255,255,255,0.1) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14 * dockScale
                        color: Theme.text
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mediaWidget.currentPlayer) mediaWidget.currentPlayer.next()
                    }
                }

                // Toggle (Expand/Collapse)
                Rectangle {
                    Layout.preferredWidth: 28 * dockScale
                    Layout.preferredHeight: 28 * dockScale
                    radius: 14 * dockScale
                    color: toggleMouse.containsMouse
                        ? Qt.rgba(137/255, 180/255, 250/255, 0.2)
                        : Qt.rgba(137/255, 180/255, 250/255, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: mediaWidget.expanded ? "󰅁" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12 * dockScale
                        color: mediaWidget.expanded ? Theme.primary : Theme.subtext
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaWidget.expanded = !mediaWidget.expanded
                    }
                }
            }
        }
    }
}
