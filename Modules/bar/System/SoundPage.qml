import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: soundPage

    SoundService { id: soundService }

    // Brightness backend
    QtObject {
        id: brightness
        property bool available: false
        property int value: 0
        property int maxValue: 100
        property bool loading: true

        function read() {
            if (!brightnessReadProc.running) {
                brightnessReadProc.out = ""
                brightnessReadProc.running = true
            }
        }
        function set(percent) {
            var p = Math.max(0, Math.min(100, Math.round(percent)))
            Quickshell.execDetached(["/bin/bash", "-lc",
                "brightnessctl s " + p + "% -q"])
            brightness.value = p
        }
    }

    Process {
        id: brightnessReadProc
        command: ["/bin/bash", "-lc",
            "MAX=$(brightnessctl m 2>/dev/null) && CUR=$(brightnessctl g 2>/dev/null) && echo \"MAX=$MAX\" && echo \"CUR=$CUR\" || echo \"UNAVAILABLE\""]
        running: true
        property string out: ""
        stdout: SplitParser { onRead: data => brightnessReadProc.out += data + "\n" }
        onExited: function(code) {
            var text = brightnessReadProc.out.trim()
            if (code !== 0 || text === "UNAVAILABLE" || text.indexOf("UNAVAILABLE") !== -1) {
                brightness.available = false
            } else {
                var maxMatch = text.match(/MAX=(\d+)/)
                var curMatch = text.match(/CUR=(\d+)/)
                if (maxMatch && curMatch) {
                    var max = parseInt(maxMatch[1])
                    var cur = parseInt(curMatch[1])
                    if (max > 0) {
                        brightness.maxValue = max
                        brightness.value = Math.round(cur / max * 100)
                        brightness.available = true
                    } else {
                        brightness.available = false
                    }
                } else {
                    brightness.available = false
                }
            }
            brightness.loading = false
            brightnessReadProc.out = ""
        }
    }

    PwNodeLinkTracker {
        id: appTracker
        node: soundService.defaultSink
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Title
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰕾"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "Sound Settings"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text }
        }

        // --- Brightness ---
        Rectangle {
            Layout.fillWidth: true
            height: 90
            color: SettingsPalette.surface
            radius: 10
            visible: brightness.available

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    spacing: 8
                    Text { text: "󰃞"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#f9e2af" }
                    Text { text: "Brightness"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                    Text { text: brightness.value + "%"; color: "#f9e2af"; font.bold: true; font.pixelSize: 13 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: Qt.rgba(249/255, 226/255, 175/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: brightness.value < 30 ? "󰃞" : brightness.value < 70 ? "󰃟" : "󰃠"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: "#f9e2af"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.8)

                        Rectangle {
                            width: parent.width * (brightness.value / 100)
                            height: parent.height; radius: 3; color: "#f9e2af"
                            Behavior on width { NumberAnimation { duration: 50 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => brightness.set(mouse.x / width * 100)
                            onPositionChanged: mouse => { if (pressed) brightness.set(mouse.x / width * 100) }
                        }
                    }
                }
            }
        }

        // --- Output (Speaker) ---
        SoundDeviceCard {
            iconText: "󰓃"
            accentColor: "#a6e3a1"
            title: soundService.sinkDisplayName
            volumePercent: soundService.sinkVolumePercent
            volumeMax: 150
            muted: soundService.sinkMuted
            mutedIconText: "󰝟"
            unmutedIconText: "󰕾"
            onToggleMute: function() { soundService.toggleSinkMute(); }
            onSetVolume: function(percent) { soundService.setSinkVolumePercent(percent); }
        }

        // --- Input (Microphone) ---
        SoundDeviceCard {
            iconText: "󰍬"
            accentColor: "#94e2d5"
            title: soundService.sourceDisplayName
            volumePercent: soundService.sourceVolumePercent
            volumeMax: 100
            muted: soundService.sourceMuted
            mutedIconText: "󰍭"
            unmutedIconText: "󰍬"
            onToggleMute: function() { soundService.toggleSourceMute(); }
            onSetVolume: function(percent) { soundService.setSourceVolumePercent(percent); }
        }

        // --- Applications ---
        Text { text: "Applications"; color: SettingsPalette.subtext; font.pixelSize: 12; font.bold: true }

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
                color: SettingsPalette.surface
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; color: Qt.rgba(137/255, 180/255, 250/255, 0.1); radius: 8
                        Text { anchors.centerIn: parent; text: ""; color: Theme.primary; font.family: Theme.fontFamily }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: appNode.properties["application.name"] || appNode.name || "Unknown"
                            color: SettingsPalette.text; font.bold: true; font.pixelSize: 12; elide: Text.ElideRight
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
                        color: SettingsPalette.subtext; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
