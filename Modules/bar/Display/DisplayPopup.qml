import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../Widgets"

PanelWindow {
    id: root

    implicitWidth: 380
    implicitHeight: 500

    anchors { top: true; right: true }
    margins { top: 60; right: 10 }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay



    // --- State ---
    property string currentOutput: ""
    property string currentMode: ""
    property string currentScale: ""
    property var availableModes: []
    property var scaleOptions: ["1", "1.25", "1.5", "1.75", "2"]

    // --- wlr-randr okuma ---
    Process {
        id: randrProc
        command: ["wlr-randr"]
        property string outputBuffer: ""
        stdout: SplitParser {
            onRead: (data) => { randrProc.outputBuffer += data + "\n"; }
        }
        onExited: {
            root.parseRandrOutput(randrProc.outputBuffer);
            randrProc.outputBuffer = "";
        }
    }

    function parseRandrOutput(text) {
        var lines = text.split("\n");
        var outputName = "";
        var modes = [];
        var curMode = "";
        var curScale = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            // Çıkış adı (ilk satır, girintisiz)
            if (line.length > 0 && line[0] !== ' ') {
                var parts = line.split(" ");
                outputName = parts[0];
            }

            // Modes listesi
            var modeMatch = line.match(/^\s+([\d]+x[\d]+)\s+px,\s+([\d.]+)\s+Hz\s*(.*)/);
            if (modeMatch) {
                var mode = modeMatch[1];
                var hz = modeMatch[2];
                var flags = modeMatch[3] || "";
                var entry = mode + "@" + hz + "Hz";

                // Tekrar ekleme
                var exists = false;
                for (var j = 0; j < modes.length; j++) {
                    if (modes[j].mode === mode && modes[j].hz === hz) { exists = true; break; }
                }
                if (!exists) {
                    modes.push({ mode: mode, hz: hz, label: entry, current: flags.indexOf("current") !== -1 });
                }
                if (flags.indexOf("current") !== -1) {
                    curMode = mode + "@" + hz + "Hz";
                }
            }

            // Scale
            var scaleMatch = line.match(/Scale:\s+([\d.]+)/);
            if (scaleMatch) {
                curScale = scaleMatch[1];
            }

            // Transform (skip)
        }

        root.currentOutput = outputName;
        root.currentMode = curMode;
        root.currentScale = curScale;
        root.availableModes = modes;
    }

    // --- wlr-randr uygulama ---
    Process {
        id: applyProc
        command: []
        running: false
    }

    function applySettings(mode, scale) {
        var modeStr = mode.replace("@", " --custom-mode ").replace("Hz", "");
        var parts = mode.split("@");
        var resolution = parts[0];
        var hz = parts.length > 1 ? parts[1].replace("Hz", "") : "";

        applyProc.running = false;
        var cmd = "wlr-randr --output " + root.currentOutput;
        if (resolution && hz) {
            cmd += " --mode " + resolution + "@" + hz + "Hz";
        }
        cmd += " --scale " + scale;
        applyProc.command = ["sh", "-c", cmd];
        applyProc.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            randrProc.outputBuffer = "";
            randrProc.running = false;
            randrProc.running = true;
        }
    }

    // --- State for selections ---
    property string selectedMode: currentMode
    property string selectedScale: currentScale

    onCurrentModeChanged: selectedMode = currentMode
    onCurrentScaleChanged: selectedScale = currentScale

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.radius
        border.width: 1
        border.color: Theme.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // --- Başlık ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰍹"
                    font.pixelSize: 20
                    font.family: "JetBrainsMono Nerd Font"
                    color: Theme.displayColor
                }
                Text {
                    text: "Display Settings"
                    font.bold: true
                    font.pixelSize: 18
                    color: Theme.text
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: closeMA.containsMouse ? Theme.red : Theme.surface
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "✕"; color: Theme.text; font.pixelSize: 12 }
                    MouseArea {
                        id: closeMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            // --- Mevcut Bilgi ---
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: Theme.surface
                radius: Theme.radius

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "󰹑"
                        font.pixelSize: 24
                        font.family: "JetBrainsMono Nerd Font"
                        color: Theme.displayColor
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: root.currentOutput || "Detecting..."
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: 14
                        }
                        Text {
                            text: root.currentMode + " • Scale: " + root.currentScale + "x"
                            color: Theme.subtext
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

            // --- Çözünürlük Seçimi ---
            Text {
                text: "Resolution"
                color: Theme.subtext
                font.pixelSize: 12
                font.bold: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4

                model: root.availableModes

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 40
                    radius: 10
                    color: {
                        if (root.selectedMode === modelData.label) return Qt.rgba(137/255, 180/255, 250/255, 0.2);
                        if (modeMA.containsMouse) return Qt.rgba(49/255, 50/255, 68/255, 0.8);
                        return "transparent";
                    }
                    border.color: root.selectedMode === modelData.label ? Theme.primary : "transparent"
                    border.width: root.selectedMode === modelData.label ? 1 : 0

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14

                        Text {
                            text: modelData.label
                            color: root.selectedMode === modelData.label ? Theme.primary : Theme.text
                            font.pixelSize: 13
                            font.bold: root.selectedMode === modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: modelData.current
                            text: "Current"
                            color: "#a6e3a1"
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Rectangle {
                            visible: root.selectedMode === modelData.label && !modelData.current
                            width: 8; height: 8; radius: 4
                            color: Theme.primary
                        }
                    }

                    MouseArea {
                        id: modeMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedMode = modelData.label
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.surface }

            // --- Scale Seçimi ---
            Text {
                text: "Scale"
                color: Theme.subtext
                font.pixelSize: 12
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.scaleOptions

                    Rectangle {
                        required property string modelData

                        Layout.fillWidth: true
                        height: 38
                        radius: 10
                        color: {
                            if (root.selectedScale === modelData) return Qt.rgba(245/255, 194/255, 231/255, 0.2); // Keep opacity logic or change? Using rgba with Theme.displayColor is hard without helpers. I'll keep default or try to match.
                            // To match theme, ideally I should use `Qt.rgba(Theme.displayColor.r, ...)` but that's complex.
                            // I'll stick to replacing `theme.surface` for default.
                            if (scaleMA.containsMouse) return Qt.rgba(49/255, 50/255, 68/255, 0.8);
                            return Theme.surface;
                        }
                        border.color: root.selectedScale === modelData ? Theme.displayColor : "transparent"
                        border.width: root.selectedScale === modelData ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "x"
                            color: root.selectedScale === modelData ? Theme.displayColor : Theme.text
                            font.pixelSize: 13
                            font.bold: root.selectedScale === modelData
                        }

                        MouseArea {
                            id: scaleMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedScale = modelData
                        }
                    }
                }
            }

            // --- Uygula Butonu ---
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 10
                color: applyMA.containsMouse ? Qt.lighter(Theme.displayColor, 1.15) : Theme.displayColor
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "✓  Apply"
                    color: "#1e1e2e"
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: applyMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.applySettings(root.selectedMode, root.selectedScale);
                        root.visible = false;
                    }
                }
            }
        }
    }
}
