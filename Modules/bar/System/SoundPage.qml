import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../Widgets"

Item {
    id: soundPage

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

    PwObjectTracker { objects: [ soundPage.defaultSink, soundPage.defaultSource ] }

    PwNodeLinkTracker {
        id: appTracker
        node: soundPage.defaultSink
    }

    Process {
        id: audioInfoProc
        command: ["/bin/bash", "-lc", "S=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Sink:/{print $2; exit}'); SR=$(/usr/bin/pactl info | /usr/bin/awk -F': ' '/^Default Source:/{print $2; exit}'); SV=$(/usr/bin/pactl get-sink-volume \"$S\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SM=$(/usr/bin/pactl get-sink-mute \"$S\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); SRV=$(/usr/bin/pactl get-source-volume \"$SR\" 2>/dev/null | /usr/bin/sed -n 's/.* \\([0-9]\\+\\)%.*/\\1/p' | /usr/bin/head -n1 || echo 0); SRM=$(/usr/bin/pactl get-source-mute \"$SR\" 2>/dev/null | /usr/bin/awk '{print $2}' || echo no); echo \"SINK=$S\"; echo \"SOURCE=$SR\"; echo \"SINKVOL=$SV\"; echo \"SINKMUTE=$SM\"; echo \"SOURCEVOL=$SRV\"; echo \"SOURCEMUTE=$SRM\""]
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
                        soundPage.currentSinkName = s;
                        soundPage.sinkDisplayName = s.replace(/^alsa_output\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
                    }
                } else if (l.indexOf("SOURCE=") === 0) {
                    var src = l.substring(7);
                    if (src.length > 0) {
                        soundPage.currentSourceName = src;
                        soundPage.sourceDisplayName = src.replace(/^alsa_input\./, "").replace(/\.analog-stereo$/, "").replace(/_/g, " ");
                    }
                } else if (l.indexOf("SINKVOL=") === 0) {
                    soundPage.sinkVolumePercent = parseInt(l.substring(8)) || 0;
                } else if (l.indexOf("SINKMUTE=") === 0) {
                    soundPage.sinkMuted = (l.substring(9).trim() === "yes");
                } else if (l.indexOf("SOURCEVOL=") === 0) {
                    soundPage.sourceVolumePercent = parseInt(l.substring(10)) || 0;
                } else if (l.indexOf("SOURCEMUTE=") === 0) {
                    soundPage.sourceMuted = (l.substring(11).trim() === "yes");
                }
            }
            audioInfoProc.out = "";
        }
    }

    function refreshAudioInfo() {
        if (audioInfoProc.running) return;
        audioInfoProc.out = "";
        audioInfoProc.running = true;
    }

    function setSinkVolumePercent(percent) {
        var p = Math.max(0, Math.min(150, Math.round(percent)));
        var sinkArg = (soundPage.currentSinkName.length > 0 ? soundPage.currentSinkName : "@DEFAULT_SINK@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-volume", sinkArg, String(p) + "%"]);
        soundPage.sinkVolumePercent = p;
        Qt.callLater(soundPage.refreshAudioInfo);
    }

    function setSourceVolumePercent(percent) {
        var p = Math.max(0, Math.min(100, Math.round(percent)));
        var srcArg = (soundPage.currentSourceName.length > 0 ? soundPage.currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-volume", srcArg, String(p) + "%"]);
        soundPage.sourceVolumePercent = p;
        Qt.callLater(soundPage.refreshAudioInfo);
    }

    function toggleSinkMute() {
        var sinkArg = (soundPage.currentSinkName.length > 0 ? soundPage.currentSinkName : "@DEFAULT_SINK@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-sink-mute", sinkArg, "toggle"]);
        Qt.callLater(soundPage.refreshAudioInfo);
    }

    function toggleSourceMute() {
        var srcArg = (soundPage.currentSourceName.length > 0 ? soundPage.currentSourceName : "@DEFAULT_SOURCE@");
        Quickshell.execDetached(["/usr/bin/pactl", "set-source-mute", srcArg, "toggle"]);
        Qt.callLater(soundPage.refreshAudioInfo);
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: soundPage.refreshAudioInfo()
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
                        text: soundPage.sinkDisplayName
                        color: Theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: soundPage.sinkVolumePercent + "%"
                        color: Theme.primary; font.bold: true; font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Mute toggle
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: soundPage.sinkMuted ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(166/255, 227/255, 161/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: soundPage.sinkMuted ? "󰝟" : "󰕾"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                            color: soundPage.sinkMuted ? "#f38ba8" : "#a6e3a1"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: soundPage.toggleSinkMute()
                        }
                    }

                    // Volume slider
                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Rectangle {
                            width: parent.width * (Math.max(0, Math.min(soundPage.sinkVolumePercent, 150)) / 150)
                            height: parent.height; radius: 3; color: "#a6e3a1"
                            Behavior on width { NumberAnimation { duration: 50 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function setVol(mouse) {
                                if (width <= 0) return;
                                var p = (mouse.x / width) * 150.0;
                                soundPage.setSinkVolumePercent(p);
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
                        text: soundPage.sourceDisplayName
                        color: Theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: soundPage.sourceVolumePercent + "%"
                        color: "#94e2d5"; font.bold: true; font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: soundPage.sourceMuted ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(148/255, 226/255, 213/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: soundPage.sourceMuted ? "󰍭" : "󰍬"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                            color: soundPage.sourceMuted ? "#f38ba8" : "#94e2d5"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: soundPage.toggleSourceMute()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Rectangle {
                            width: parent.width * (Math.max(0, Math.min(soundPage.sourceVolumePercent, 100)) / 100)
                            height: parent.height; radius: 3; color: "#94e2d5"
                            Behavior on width { NumberAnimation { duration: 50 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function setVol(mouse) {
                                if (width <= 0) return;
                                var p = (mouse.x / width) * 100.0;
                                soundPage.setSourceVolumePercent(p);
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
