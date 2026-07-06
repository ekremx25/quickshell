import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

// Sink (output) and source (input) volume/mute controls row.
// All audio state flows through the `eq` reference (the parent Equalizer root item).
RowLayout {
    required property var eq

    spacing: 10

    // Sink (speaker / output)
    Rectangle {
        Layout.fillWidth: true
        height: 88
        radius: 16
        color: eq.glassCard
        border.width: 1
        border.color: eq.glassStroke

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "󰓃"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: eq.sinkAccent }
                Text {
                    font.family: Theme.fontFamily
                    Layout.fillWidth: true
                    text: eq.sinkDisplayName
                    color: eq.softText
                    font.bold: true
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.fontFamily
                    text: eq.sinkVolumePercent + "%"
                    color: eq.softText
                    font.bold: true
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: eq.sinkMuted ? Qt.rgba(243/255, 139/255, 168/255, 0.18) : Qt.rgba(166/255, 227/255, 161/255, 0.12)
                    border.width: 1
                    border.color: eq.glassStroke
                    Text {
                        anchors.centerIn: parent
                        text: eq.sinkMuted ? "󰝟" : "󰕾"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: eq.sinkMuted ? "#f38ba8" : eq.sinkAccent
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eq.toggleSinkMute() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: eq.trackColor
                    Rectangle {
                        width: parent.width * (Math.max(0, Math.min(eq.sinkVolumePercent, 150)) / 150)
                        height: parent.height; radius: 3
                        color: eq.sinkAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVol(mouse) {
                            if (width <= 0) return;
                            eq.setSinkVolumePercent((mouse.x / width) * 150.0);
                        }
                        onPressed: function(mouse) { setVol(mouse); }
                        onPositionChanged: function(mouse) { if (pressed) setVol(mouse); }
                    }
                }
            }
        }
    }

    // Source (microphone / input)
    Rectangle {
        Layout.fillWidth: true
        height: 88
        radius: 16
        color: eq.glassCard
        border.width: 1
        border.color: eq.glassStroke

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "󰍬"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: eq.sourceAccent }
                Text {
                    font.family: Theme.fontFamily
                    Layout.fillWidth: true
                    text: eq.sourceDisplayName
                    color: eq.softText
                    font.bold: true
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.fontFamily
                    text: eq.sourceVolumePercent + "%"
                    color: eq.softText
                    font.bold: true
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: eq.sourceMuted ? Qt.rgba(243/255, 139/255, 168/255, 0.18) : Qt.rgba(148/255, 226/255, 213/255, 0.12)
                    border.width: 1
                    border.color: eq.glassStroke
                    Text {
                        anchors.centerIn: parent
                        text: eq.sourceMuted ? "󰍭" : "󰍬"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: eq.sourceMuted ? "#f38ba8" : eq.sourceAccent
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eq.toggleSourceMute() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: eq.trackColor
                    Rectangle {
                        width: parent.width * (Math.max(0, Math.min(eq.sourceVolumePercent, 100)) / 100)
                        height: parent.height; radius: 3
                        color: eq.sourceAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setMic(mouse) {
                            if (width <= 0) return;
                            eq.setSourceVolumePercent((mouse.x / width) * 100.0);
                        }
                        onPressed: function(mouse) { setMic(mouse); }
                        onPositionChanged: function(mouse) { if (pressed) setMic(mouse); }
                    }
                }
            }
        }
    }
}
