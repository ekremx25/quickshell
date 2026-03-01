import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../Widgets"

Item {
    id: soundPage


    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [ soundPage.defaultSink, soundPage.defaultSource ] }

    PwNodeLinkTracker {
        id: appTracker
        node: soundPage.defaultSink
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Başlık
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰕾"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "Sound Settings"; font.bold: true; font.pixelSize: 18; color: Theme.text }
        }

        // --- Çıkış (Hoparlör) ---
        Rectangle {
            Layout.fillWidth: true
            height: 90
            color: Theme.surface
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    spacing: 8
                    Text { text: "󰓃"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#a6e3a1" }
                    Text {
                        text: soundPage.defaultSink ? (soundPage.defaultSink.description || "Speaker") : "No Device"
                        color: Theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: soundPage.defaultSink ? Math.round(soundPage.defaultSink.audio.volume * 100) + "%" : "0%"
                        color: Theme.primary; font.bold: true; font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Mute toggle
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: (soundPage.defaultSink && soundPage.defaultSink.audio.isMuted) ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(166/255, 227/255, 161/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: (soundPage.defaultSink && soundPage.defaultSink.audio.isMuted) ? "󰝟" : "󰕾"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                            color: (soundPage.defaultSink && soundPage.defaultSink.audio.isMuted) ? "#f38ba8" : "#a6e3a1"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (soundPage.defaultSink) soundPage.defaultSink.audio.isMuted = !soundPage.defaultSink.audio.isMuted
                        }
                    }

                    // Volume slider
                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Rectangle {
                            width: parent.width * Math.min((soundPage.defaultSink ? soundPage.defaultSink.audio.volume : 0), 1.0)
                            height: parent.height; radius: 3; color: "#a6e3a1"
                            Behavior on width { NumberAnimation { duration: 50 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function setVol(mouse) {
                                if (!soundPage.defaultSink) return;
                                var v = mouse.x / width;
                                soundPage.defaultSink.audio.volume = Math.min(Math.max(v, 0), 1.5);
                            }
                            onPressed: (mouse) => setVol(mouse)
                            onPositionChanged: (mouse) => { if (pressed) setVol(mouse); }
                        }
                    }
                }
            }
        }

        // --- Giriş (Mikrofon) ---
        Rectangle {
            Layout.fillWidth: true
            height: 90
            color: Theme.surface
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    spacing: 8
                    Text { text: "󰍬"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#94e2d5" }
                    Text {
                        text: soundPage.defaultSource ? (soundPage.defaultSource.description || "Microphone") : "No Microphone"
                        color: Theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: soundPage.defaultSource ? Math.round(soundPage.defaultSource.audio.volume * 100) + "%" : "0%"
                        color: "#94e2d5"; font.bold: true; font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: (soundPage.defaultSource && soundPage.defaultSource.audio.isMuted) ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(148/255, 226/255, 213/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: (soundPage.defaultSource && soundPage.defaultSource.audio.isMuted) ? "󰍭" : "󰍬"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                            color: (soundPage.defaultSource && soundPage.defaultSource.audio.isMuted) ? "#f38ba8" : "#94e2d5"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (soundPage.defaultSource) soundPage.defaultSource.audio.isMuted = !soundPage.defaultSource.audio.isMuted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Rectangle {
                            width: parent.width * Math.min((soundPage.defaultSource ? soundPage.defaultSource.audio.volume : 0), 1.0)
                            height: parent.height; radius: 3; color: "#94e2d5"
                            Behavior on width { NumberAnimation { duration: 50 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function setVol(mouse) {
                                if (!soundPage.defaultSource) return;
                                var v = mouse.x / width;
                                soundPage.defaultSource.audio.volume = Math.min(Math.max(v, 0), 1.0);
                            }
                            onPressed: (mouse) => setVol(mouse)
                            onPositionChanged: (mouse) => { if (pressed) setVol(mouse); }
                        }
                    }
                }
            }
        }

        // --- Uygulamalar ---
        Text { text: "Applications"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6

            model: appTracker.linkGroups

            delegate: Rectangle {
                required property PwLinkGroup modelData
                property var appNode: modelData.source

                PwObjectTracker { objects: [ appNode ] }

                width: ListView.view.width
                height: 50
                color: Theme.surface
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; color: Qt.rgba(137/255, 180/255, 250/255, 0.1); radius: 8
                        Text { anchors.centerIn: parent; text: ""; color: Theme.primary; font.family: "JetBrainsMono Nerd Font" }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: appNode.properties["application.name"] || appNode.name || "Unknown"
                            color: Theme.text; font.bold: true; font.pixelSize: 12; elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 4; radius: 2; color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                            Rectangle {
                                width: parent.width * appNode.audio.volume
                                height: parent.height; radius: 2; color: Theme.primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onPressed: (mouse) => { var v = mouse.x / width; appNode.audio.volume = Math.min(Math.max(v, 0), 1); }
                                onPositionChanged: (mouse) => { if (pressed) { var v = mouse.x / width; appNode.audio.volume = Math.min(Math.max(v, 0), 1); } }
                            }
                        }
                    }

                    Text {
                        text: Math.round(appNode.audio.volume * 100) + "%"
                        color: Theme.subtext; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
